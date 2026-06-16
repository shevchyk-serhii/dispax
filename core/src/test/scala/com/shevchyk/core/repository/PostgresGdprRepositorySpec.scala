package com.shevchyk.core.repository

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for PostgresGdprRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresGdprRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("0c000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("0c000001-0000-0000-0000-000000000002"))
  val userId         = PersonId(UUID.fromString("0c000002-0000-0000-0000-000000000001"))
  val otherUserId    = PersonId(UUID.fromString("0c000002-0000-0000-0000-000000000002"))

  private def insertPerson(id: PersonId, email: String, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
          VALUES (${id.value}, 'Test Person', $email, 'client'::person_role, ${company.value}, 'placeholder')
          ON CONFLICT DO NOTHING""".update.run

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'gdpr-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'gdpr-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- insertPerson(userId, "gdpr-user@test.com", testCompanyId)
      _ <- insertPerson(otherUserId, "gdpr-user2@test.com", otherCompanyId)
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM gdpr_consents".update.run
      _ <- sql"DELETE FROM gdpr_requests".update.run
    } yield ()).transact(xa).unit

  private def makeConsent(
      user: PersonId = userId,
      consentType: ConsentType = ConsentType.DataProcessing
  ): GdprConsent = GdprConsent(
    id = GdprConsentId(UUID.randomUUID()),
    userId = user,
    consentType = consentType,
    grantedAt = Instant.now(),
    revokedAt = None,
    ipAddress = Some("127.0.0.1")
  )

  private def makeRequest(
      user: PersonId = userId,
      reqType: GdprRequestType = GdprRequestType.EXPORT,
      status: GdprRequestStatus = GdprRequestStatus.PENDING
  ): GdprRequest = GdprRequest(
    id = GdprRequestId(UUID.randomUUID()),
    userId = user,
    requestType = reqType,
    status = status,
    requestedAt = Instant.now(),
    completedAt = None,
    notes = Some("test request")
  )

  def spec =
    suite("PostgresGdprRepository")(
      test("createConsent and findConsentsByUserId round-trip") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresGdprRepository(xa)
          consent   = makeConsent()
          _        <- repo.createConsent(consent)
          consents <- repo.findConsentsByUserId(userId)
        } yield assertTrue(
          consents.length == 1,
          consents.head.consentType == ConsentType.DataProcessing,
          consents.head.ipAddress.contains("127.0.0.1"),
          consents.head.revokedAt.isEmpty
        )
      },
      test("createConsent upserts on (user_id, consent_type) and clears revoked_at") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresGdprRepository(xa)
          _        <- repo.createConsent(makeConsent(consentType = ConsentType.Marketing))
          _        <- repo.revokeConsent(userId, ConsentType.Marketing)
          _        <- repo.createConsent(makeConsent(consentType = ConsentType.Marketing))
          consents <- repo.findConsentsByUserId(userId)
        } yield assertTrue(consents.length == 1, consents.head.revokedAt.isEmpty)
      },
      test("revokeConsent sets revoked_at; second revoke is no-op") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresGdprRepository(xa)
          _        <- repo.createConsent(makeConsent(consentType = ConsentType.Analytics))
          first    <- repo.revokeConsent(userId, ConsentType.Analytics)
          second   <- repo.revokeConsent(userId, ConsentType.Analytics)
          consents <- repo.findConsentsByUserId(userId)
        } yield assertTrue(first, !second, consents.head.revokedAt.isDefined)
      },
      test("createRequest and findRequestsByUserId round-trip") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresGdprRepository(xa)
          request   = makeRequest(reqType = GdprRequestType.DELETION)
          _        <- repo.createRequest(request)
          requests <- repo.findRequestsByUserId(userId)
        } yield assertTrue(
          requests.length == 1,
          requests.head.id == request.id,
          requests.head.requestType == GdprRequestType.DELETION,
          requests.head.status == GdprRequestStatus.PENDING,
          requests.head.notes.contains("test request")
        )
      },
      test("findAllRequests scopes to company via persons join") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGdprRepository(xa)
          _      <- repo.createRequest(makeRequest(user = userId))
          _      <- repo.createRequest(makeRequest(user = otherUserId))
          mine   <- repo.findAllRequests(testCompanyId)
          others <- repo.findAllRequests(otherCompanyId)
        } yield assertTrue(
          mine.length == 1,
          mine.head.userId == userId,
          others.length == 1,
          others.head.userId == otherUserId
        )
      },
      test("updateRequestStatus to COMPLETED sets completed_at") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresGdprRepository(xa)
          request   = makeRequest()
          _        <- repo.createRequest(request)
          updated  <- repo.updateRequestStatus(request.id, GdprRequestStatus.COMPLETED)
          missing  <- repo.updateRequestStatus(GdprRequestId(UUID.randomUUID()), GdprRequestStatus.COMPLETED)
          requests <- repo.findRequestsByUserId(userId)
        } yield assertTrue(
          updated,
          !missing,
          requests.head.status == GdprRequestStatus.COMPLETED,
          requests.head.completedAt.isDefined
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
