package com.shevchyk.notification.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.FcmToken
import com.shevchyk.notification.repository.PostgresFcmTokenRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for PostgresFcmTokenRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresFcmTokenRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = UUID.fromString("00000050-0000-0000-0000-000000000001")
  val personId      = PersonId(UUID.fromString("00000060-0000-0000-0000-000000000001"))
  val otherPersonId = PersonId(UUID.fromString("00000060-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES ($testCompanyId, 'Fcm Test GmbH', 'fcm-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${personId.value}, 'Fcm Person', 'fcm-person@test.com', 'driver'::person_role, $testCompanyId, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherPersonId.value}, 'Fcm Other', 'fcm-other@test.com', 'driver'::person_role, $testCompanyId, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanFcmTokens(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM fcm_tokens".update.run.transact(xa).unit

  private def makeToken(
      person: PersonId = personId,
      token: String = "fcm-token-1",
      platform: String = "android"
  ): FcmToken = FcmToken(
    personId = person,
    token = token,
    platform = platform,
    createdAt = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
  )

  def spec =
    suite("PostgresFcmTokenRepository")(
      test("save and findByPersonId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanFcmTokens(xa)
          repo   = PostgresFcmTokenRepository(xa)
          tok    = makeToken(token = "fcm-roundtrip", platform = "ios")
          _     <- repo.save(tok)
          found <- repo.findByPersonId(personId)
        } yield assertTrue(
          found.length == 1,
          found.head.token == "fcm-roundtrip",
          found.head.personId == personId,
          found.head.platform == "ios"
        )
      },
      test("save upserts person_id and platform on conflicting token") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanFcmTokens(xa)
          repo   = PostgresFcmTokenRepository(xa)
          _     <- repo.save(makeToken(person = personId, token = "fcm-shared", platform = "android"))
          _     <- repo.save(makeToken(person = otherPersonId, token = "fcm-shared", platform = "ios"))
          old   <- repo.findByPersonId(personId)
          moved <- repo.findByPersonId(otherPersonId)
        } yield assertTrue(
          old.isEmpty,
          moved.length == 1,
          moved.head.token == "fcm-shared",
          moved.head.platform == "ios"
        )
      },
      test("findByPersonId excludes other persons' tokens") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanFcmTokens(xa)
          repo  = PostgresFcmTokenRepository(xa)
          _    <- repo.save(makeToken(person = personId, token = "fcm-a"))
          _    <- repo.save(makeToken(person = personId, token = "fcm-b"))
          _    <- repo.save(makeToken(person = otherPersonId, token = "fcm-c"))
          mine <- repo.findByPersonId(personId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.personId == personId),
          mine.map(_.token).toSet == Set("fcm-a", "fcm-b")
        )
      },
      test("deleteByToken removes only the targeted token") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanFcmTokens(xa)
          repo    = PostgresFcmTokenRepository(xa)
          _      <- repo.save(makeToken(person = personId, token = "fcm-keep"))
          _      <- repo.save(makeToken(person = personId, token = "fcm-drop"))
          _      <- repo.deleteByToken("fcm-drop")
          remain <- repo.findByPersonId(personId)
        } yield assertTrue(
          remain.length == 1,
          remain.head.token == "fcm-keep"
        )
      },
      test("deleteByPersonId removes only that person's tokens") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanFcmTokens(xa)
          repo  = PostgresFcmTokenRepository(xa)
          _    <- repo.save(makeToken(person = personId, token = "fcm-p1-a"))
          _    <- repo.save(makeToken(person = personId, token = "fcm-p1-b"))
          _    <- repo.save(makeToken(person = otherPersonId, token = "fcm-p2"))
          _    <- repo.deleteByPersonId(personId)
          gone <- repo.findByPersonId(personId)
          kept <- repo.findByPersonId(otherPersonId)
        } yield assertTrue(
          gone.isEmpty,
          kept.length == 1,
          kept.head.token == "fcm-p2"
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
