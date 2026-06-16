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
 * Integration tests for PostgresSessionRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresSessionRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  val userId        = PersonId(UUID.fromString("0000000A-0000-0000-0000-000000000002"))
  val otherUserId   = PersonId(UUID.fromString("0000000A-0000-0000-0000-000000000003"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Session Test GmbH', 'session@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${userId.value}, 'Session User', 'session-user@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherUserId.value}, 'Other User', 'session-other@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanSessions(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM sessions".update.run.transact(xa).unit

  private def isActive(xa: Transactor[Task], id: SessionId): Task[Option[Boolean]] =
    sql"SELECT is_active FROM sessions WHERE id = ${id.value}".query[Boolean].option.transact(xa)

  private def makeSession(
      user: PersonId = userId,
      token: String = UUID.randomUUID().toString,
      isActive: Boolean = true
  ): Session = {
    val now = Instant.now()
    Session(
      id = SessionId.generate(),
      userId = user,
      token = token,
      deviceInfo = Some("Test Device"),
      ipAddress = Some("127.0.0.1"),
      createdAt = now,
      lastActiveAt = now,
      isActive = isActive
    )
  }

  def spec =
    suite("PostgresSessionRepository")(
      test("create and findByToken round-trip") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          session = makeSession(token = "tok-roundtrip")
          _      <- repo.create(session)
          found  <- repo.findByToken("tok-roundtrip")
        } yield assertTrue(
          found.isDefined,
          found.get.id == session.id,
          found.get.userId == userId,
          found.get.token == "tok-roundtrip",
          found.get.deviceInfo.contains("Test Device"),
          found.get.ipAddress.contains("127.0.0.1"),
          found.get.isActive
        )
      },
      test("findByToken returns None for inactive session") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          session = makeSession(token = "tok-inactive", isActive = false)
          _      <- repo.create(session)
          found  <- repo.findByToken("tok-inactive")
        } yield assertTrue(found.isEmpty)
      },
      test("findByUserId returns only active sessions for that user") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanSessions(xa)
          repo   = PostgresSessionRepository(xa)
          s1     = makeSession(user = userId)
          s2     = makeSession(user = userId)
          s3     = makeSession(user = userId, isActive = false)
          sOther = makeSession(user = otherUserId)
          _     <- repo.create(s1)
          _     <- repo.create(s2)
          _     <- repo.create(s3)
          _     <- repo.create(sOther)
          found <- repo.findByUserId(userId)
        } yield assertTrue(
          found.length == 2,
          found.forall(_.userId == userId),
          found.forall(_.isActive),
          found.map(_.id).toSet == Set(s1.id, s2.id)
        )
      },
      test("updateLastActive bumps last_active_at") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          old     = Instant.now().minusSeconds(3600)
          session = makeSession().copy(lastActiveAt = old)
          _      <- repo.create(session)
          _      <- repo.updateLastActive(session.id)
          found  <- repo.findByToken(session.token)
        } yield assertTrue(
          found.isDefined,
          found.get.lastActiveAt.isAfter(old)
        )
      },
      test("deactivate flips is_active and returns true once") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          session = makeSession()
          _      <- repo.create(session)
          first  <- repo.deactivate(session.id)
          second <- repo.deactivate(session.id)
          active <- isActive(xa, session.id)
        } yield assertTrue(
          first,
          !second,
          active.contains(false)
        )
      },
      test("deactivateAllForUser deactivates all active sessions of the user only") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          s1      = makeSession(user = userId)
          s2      = makeSession(user = userId)
          sOther  = makeSession(user = otherUserId)
          _      <- repo.create(s1)
          _      <- repo.create(s2)
          _      <- repo.create(sOther)
          count  <- repo.deactivateAllForUser(userId)
          mine   <- repo.findByUserId(userId)
          others <- repo.findByUserId(otherUserId)
        } yield assertTrue(
          count == 2,
          mine.isEmpty,
          others.length == 1
        )
      },
      test("deactivateAllExcept keeps current session active") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSessions(xa)
          repo    = PostgresSessionRepository(xa)
          current = makeSession(user = userId)
          other1  = makeSession(user = userId)
          other2  = makeSession(user = userId)
          _      <- repo.create(current)
          _      <- repo.create(other1)
          _      <- repo.create(other2)
          count  <- repo.deactivateAllExcept(userId, current.id)
          active <- repo.findByUserId(userId)
        } yield assertTrue(
          count == 2,
          active.length == 1,
          active.head.id == current.id
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")
}
