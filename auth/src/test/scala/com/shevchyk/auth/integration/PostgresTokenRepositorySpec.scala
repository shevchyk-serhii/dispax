package com.shevchyk.auth.integration

import com.shevchyk.auth.repository.PostgresTokenRepository
import com.shevchyk.core.database.PostgresTestContainer
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for PostgresTokenRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresTokenRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = UUID.fromString("00000030-0000-0000-0000-000000000001")
  val userId        = UUID.fromString("00000040-0000-0000-0000-000000000001")
  val otherUserId   = UUID.fromString("00000040-0000-0000-0000-000000000002")

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES ($testCompanyId, 'Token Test GmbH', 'token-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES ($userId, 'Token User', 'token-user@test.com', 'client'::person_role, $testCompanyId, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES ($otherUserId, 'Other User', 'token-other@test.com', 'client'::person_role, $testCompanyId, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanTokens(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM tokens".update.run.transact(xa).unit

  def spec =
    suite("PostgresTokenRepository")(
      test("create and findUserIdByToken round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTokens(xa)
          repo   = PostgresTokenRepository(xa)
          token  = "token-abc-123"
          _     <- repo.create(token, userId)
          found <- repo.findUserIdByToken(token)
        } yield assertTrue(found.contains(userId))
      },
      test("findUserIdByToken returns None for unknown token") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTokens(xa)
          repo   = PostgresTokenRepository(xa)
          found <- repo.findUserIdByToken("does-not-exist")
        } yield assertTrue(found.isEmpty)
      },
      test("create upserts user_id on conflicting token") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTokens(xa)
          repo   = PostgresTokenRepository(xa)
          token  = "token-shared"
          _     <- repo.create(token, userId)
          _     <- repo.create(token, otherUserId)
          found <- repo.findUserIdByToken(token)
        } yield assertTrue(found.contains(otherUserId))
      },
      test("deleteByToken removes only the targeted token") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanTokens(xa)
          repo  = PostgresTokenRepository(xa)
          _    <- repo.create("token-1", userId)
          _    <- repo.create("token-2", userId)
          _    <- repo.deleteByToken("token-1")
          gone <- repo.findUserIdByToken("token-1")
          kept <- repo.findUserIdByToken("token-2")
        } yield assertTrue(
          gone.isEmpty,
          kept.contains(userId)
        )
      },
      test("deleteByUserId removes only that user's tokens") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanTokens(xa)
          repo    = PostgresTokenRepository(xa)
          _      <- repo.create("token-user-a", userId)
          _      <- repo.create("token-user-a2", userId)
          _      <- repo.create("token-user-b", otherUserId)
          _      <- repo.deleteByUserId(userId)
          aGone1 <- repo.findUserIdByToken("token-user-a")
          aGone2 <- repo.findUserIdByToken("token-user-a2")
          bKept  <- repo.findUserIdByToken("token-user-b")
        } yield assertTrue(
          aGone1.isEmpty,
          aGone2.isEmpty,
          bKept.contains(otherUserId)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
