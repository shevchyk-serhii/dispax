package com.shevchyk.schedule.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.{CalendarShareGrant, CalendarShareInvite}
import com.shevchyk.schedule.repository.{PostgresCalendarShareGrantRepository, PostgresCalendarShareInviteRepository}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Integration tests for the calendar-share repositories against a real PostgreSQL via Testcontainers, including the
 * partial unique index that guarantees at most one ACTIVE grant per (grantor, grantee) pair.
 */
object PostgresCalendarShareRepositorySpec extends ZIOSpecDefault {

  val companyAId = CompanyId(UUID.fromString("00000030-0000-0000-0000-000000000001"))
  val companyBId = CompanyId(UUID.fromString("00000030-0000-0000-0000-000000000002"))
  val grantorId  = PersonId(UUID.fromString("00000040-0000-0000-0000-000000000001"))
  val granteeId  = PersonId(UUID.fromString("00000040-0000-0000-0000-000000000002"))

  private def now(): Instant = Instant.now().truncatedTo(ChronoUnit.MILLIS)

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyAId.value}, 'Share A GmbH', 'share-a@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyBId.value}, 'Share B GmbH', 'share-b@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${grantorId.value}, 'Share Grantor', 'share-grantor@test.com', 'driver'::person_role, ${companyAId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${granteeId.value}, 'Share Grantee', 'share-grantee@test.com', 'dispatcher'::person_role, ${companyBId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM calendar_share_grants".update.run
      _ <- sql"DELETE FROM calendar_share_invites".update.run
    } yield ()).transact(xa)

  private def makeInvite(expiresAt: Instant): CalendarShareInvite = CalendarShareInvite(
    id = CalendarShareInviteId.generate(),
    token = CalendarShareInvite.generateTokenValue(),
    grantorPersonId = grantorId,
    grantorCompanyId = companyAId,
    createdAt = now(),
    expiresAt = expiresAt,
    revokedAt = None
  )

  private def makeGrant(inviteId: Option[CalendarShareInviteId] = None): CalendarShareGrant = CalendarShareGrant(
    id = CalendarShareGrantId.generate(),
    inviteId = inviteId,
    grantorPersonId = grantorId,
    grantorCompanyId = companyAId,
    granteePersonId = granteeId,
    granteeCompanyId = companyBId,
    createdAt = now(),
    expiresAt = None,
    revokedAt = None
  )

  def spec =
    suite("PostgresCalendarShareRepositories")(
      test("invite create / findByToken round-trip and grantor-scoped revoke") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedTestData(xa)
          _        <- clean(xa)
          repo      = PostgresCalendarShareInviteRepository(xa)
          invite    = makeInvite(expiresAt = now().plusSeconds(3600))
          _        <- repo.create(invite)
          found    <- repo.findByToken(invite.token)
          active   <- repo.findActiveByGrantor(grantorId, now())
          // Foreign revoke must be a no-op...
          foreign  <- repo.revoke(invite.id, granteeId, now())
          // ...own revoke succeeds exactly once.
          own      <- repo.revoke(invite.id, grantorId, now())
          again    <- repo.revoke(invite.id, grantorId, now())
          afterRev <- repo.findActiveByGrantor(grantorId, now())
        } yield assertTrue(
          found.exists(_.id == invite.id),
          found.exists(_.grantorCompanyId == companyAId),
          active.map(_.id) == List(invite.id),
          !foreign,
          own,
          !again,
          afterRev.isEmpty
        )
      },
      test("expired invites are excluded from findActiveByGrantor") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- clean(xa)
          repo    = PostgresCalendarShareInviteRepository(xa)
          _      <- repo.create(makeInvite(expiresAt = now().minusSeconds(60)))
          active <- repo.findActiveByGrantor(grantorId, now())
        } yield assertTrue(active.isEmpty)
      },
      test("grant round-trip, pair lookup and party-scoped revoke from both sides") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- clean(xa)
          repo       = PostgresCalendarShareGrantRepository(xa)
          grant      = makeGrant()
          _         <- repo.create(grant)
          byId      <- repo.findById(grant.id)
          pair      <- repo.findActivePair(grantorId, granteeId)
          byGrantor <- repo.findActiveByGrantor(grantorId)
          byGrantee <- repo.findActiveByGrantee(granteeId)
          count     <- repo.countActiveByGrantor(grantorId)
          stranger  <- repo.revoke(grant.id, PersonId(UUID.randomUUID()), now())
          grantee   <- repo.revoke(grant.id, granteeId, now())
          after     <- repo.findActivePair(grantorId, granteeId)
        } yield assertTrue(
          byId.exists(_.granteeCompanyId == companyBId),
          pair.exists(_.id == grant.id),
          byGrantor.map(_.id) == List(grant.id),
          byGrantee.map(_.id) == List(grant.id),
          count == 1,
          !stranger,
          grantee,
          after.isEmpty
        )
      },
      test(
        "partial unique index: a second ACTIVE grant for the same pair is rejected, but re-grant after revoke works"
      ) {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- clean(xa)
          repo     = PostgresCalendarShareGrantRepository(xa)
          first    = makeGrant()
          _       <- repo.create(first)
          dup     <- repo.create(makeGrant()).exit
          _       <- repo.revoke(first.id, grantorId, now())
          regrant <- repo.create(makeGrant()).exit
        } yield assertTrue(dup.isFailure, regrant.isSuccess)
      },
      test("self-share CHECK constraint rejects grantor == grantee at the database level") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- clean(xa)
          repo    = PostgresCalendarShareGrantRepository(xa)
          result <- repo.create(makeGrant().copy(granteePersonId = grantorId, granteeCompanyId = companyAId)).exit
        } yield assertTrue(result.isFailure)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
