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
 * Integration tests for PostgresBlacklistRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresBlacklistRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("0e000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("0e000001-0000-0000-0000-000000000002"))
  val clientId       = PersonId(UUID.fromString("0e000002-0000-0000-0000-000000000001"))
  val client2Id      = PersonId(UUID.fromString("0e000002-0000-0000-0000-000000000002"))
  val driverId       = PersonId(UUID.fromString("0e000002-0000-0000-0000-000000000003"))
  val driver2Id      = PersonId(UUID.fromString("0e000002-0000-0000-0000-000000000004"))
  val createdById    = PersonId(UUID.fromString("0e000002-0000-0000-0000-000000000005"))

  private def insertPerson(id: PersonId, email: String, role: String, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
          VALUES (${id.value}, 'Test Person', $email, $role::person_role, ${company.value}, 'placeholder')
          ON CONFLICT DO NOTHING""".update.run

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'bl-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'bl-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- insertPerson(clientId, "bl-client@test.com", "client", testCompanyId)
      _ <- insertPerson(client2Id, "bl-client2@test.com", "client", testCompanyId)
      _ <- insertPerson(driverId, "bl-driver@test.com", "driver", testCompanyId)
      _ <- insertPerson(driver2Id, "bl-driver2@test.com", "driver", testCompanyId)
      _ <- insertPerson(createdById, "bl-creator@test.com", "dispatcher", testCompanyId)
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM blacklist_entries".update.run.transact(xa).unit

  private def makeEntry(
      id: BlacklistEntryId = BlacklistEntryId(UUID.randomUUID()),
      company: CompanyId = testCompanyId,
      client: PersonId = clientId,
      driver: PersonId = driverId,
      active: Boolean = true
  ): BlacklistEntry = BlacklistEntry(
    id = id,
    companyId = company,
    clientId = client,
    driverId = driver,
    reason = Some("conflict"),
    createdBy = createdById,
    createdAt = Instant.now(),
    isActive = active
  )

  def spec =
    suite("PostgresBlacklistRepository")(
      test("create and findByCompanyId round-trip") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresBlacklistRepository(xa)
          entry    = makeEntry()
          _       <- repo.create(entry)
          entries <- repo.findByCompanyId(testCompanyId)
        } yield assertTrue(
          entries.length == 1,
          entries.head.id == entry.id,
          entries.head.clientId == clientId,
          entries.head.driverId == driverId,
          entries.head.reason.contains("conflict"),
          entries.head.createdBy == createdById,
          entries.head.isActive
        )
      },
      test("findByCompanyId isolates by company and excludes inactive") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresBlacklistRepository(xa)
          _      <- repo.create(makeEntry(client = clientId, driver = driverId))
          _      <- repo.create(makeEntry(client = client2Id, driver = driverId, active = false))
          _      <- repo.create(makeEntry(company = otherCompanyId, client = client2Id, driver = driver2Id))
          mine   <- repo.findByCompanyId(testCompanyId)
          others <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.length == 1,
          mine.forall(_.isActive),
          mine.forall(_.companyId == testCompanyId),
          others.length == 1
        )
      },
      test("findByClientId returns active entries for client") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresBlacklistRepository(xa)
          _       <- repo.create(makeEntry(client = clientId, driver = driverId))
          _       <- repo.create(makeEntry(client = clientId, driver = driver2Id))
          _       <- repo.create(makeEntry(client = client2Id, driver = driverId))
          entries <- repo.findByClientId(clientId)
        } yield assertTrue(entries.length == 2, entries.forall(_.clientId == clientId))
      },
      test("findByDriverId returns active entries for driver") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresBlacklistRepository(xa)
          _       <- repo.create(makeEntry(client = clientId, driver = driverId))
          _       <- repo.create(makeEntry(client = client2Id, driver = driverId))
          _       <- repo.create(makeEntry(client = clientId, driver = driver2Id))
          entries <- repo.findByDriverId(driverId)
        } yield assertTrue(entries.length == 2, entries.forall(_.driverId == driverId))
      },
      test("isBlacklisted returns true for active pair, false otherwise") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seed(xa)
          _        <- clean(xa)
          repo      = PostgresBlacklistRepository(xa)
          _        <- repo.create(makeEntry(client = clientId, driver = driverId))
          isBlack  <- repo.isBlacklisted(clientId, driverId)
          notBlack <- repo.isBlacklisted(clientId, driver2Id)
        } yield assertTrue(isBlack, !notBlack)
      },
      test("deactivate makes pair no longer blacklisted") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresBlacklistRepository(xa)
          entry    = makeEntry(client = clientId, driver = driverId)
          _       <- repo.create(entry)
          ok      <- repo.deactivate(entry.id)
          missing <- repo.deactivate(BlacklistEntryId(UUID.randomUUID()))
          active  <- repo.isBlacklisted(clientId, driverId)
          listed  <- repo.findByCompanyId(testCompanyId)
        } yield assertTrue(ok, !missing, !active, listed.isEmpty)
      },
      test("delete removes entry entirely") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresBlacklistRepository(xa)
          entry    = makeEntry(client = clientId, driver = driverId)
          _       <- repo.create(entry)
          ok      <- repo.delete(entry.id)
          missing <- repo.delete(BlacklistEntryId(UUID.randomUUID()))
          active  <- repo.isBlacklisted(clientId, driverId)
        } yield assertTrue(ok, !missing, !active)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")
}
