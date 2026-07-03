package com.shevchyk.driver.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.driver.repository.PostgresDriverLocationRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for PostgresDriverLocationRepository against a real PostgreSQL via Testcontainers. Focus: company
 * isolation of available-driver lookup (the SQL-level guard that the in-memory mock cannot model).
 */
object PostgresDriverLocationRepositorySpec extends ZIOSpecDefault {

  private val companyA = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000a1"))
  private val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000b1"))

  private val driverA1 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000a1")) // company A, Available
  private val driverA2 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000a2")) // company A, Offline
  private val driverB1 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000b1")) // company B, Available

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyA.value}, 'Company A', 'a@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyB.value}, 'Company B', 'b@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverA1.value}, 'Driver A1', 'a1@test.com', 'driver'::person_role, ${companyA.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverA2.value}, 'Driver A2', 'a2@test.com', 'driver'::person_role, ${companyA.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverB1.value}, 'Driver B1', 'b1@test.com', 'driver'::person_role, ${companyB.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanDrivers(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM drivers".update.run.transact(xa).unit

  /**
   * Insert a driver row with the given status (and optional coordinates).
   */
  private def seedDriver(
      xa: Transactor[Task],
      driver: PersonId,
      company: CompanyId,
      status: String,
      lat: Option[Double] = None,
      lng: Option[Double] = None
  ): Task[Unit] =
    sql"""
      INSERT INTO drivers (id, company_id, status, current_location_lat, current_location_lng)
      VALUES (${driver.value}, ${company.value}, ${status}::driver_status, $lat, $lng)
    """.update.run.transact(xa).unit

  def spec =
    suite("PostgresDriverLocationRepository")(
      test("findAvailableByCompanyId isolates by company") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanDrivers(xa)
          repo = PostgresDriverLocationRepository(xa)
          _   <- seedDriver(xa, driverA1, companyA, "Available", Some(48.1), Some(11.5))
          _   <- seedDriver(xa, driverB1, companyB, "Available", Some(52.5), Some(13.4))
          a   <- repo.findAvailableByCompanyId(companyA)
          b   <- repo.findAvailableByCompanyId(companyB)
        } yield assertTrue(
          a.length == 1,
          a.head._1 == driverA1,
          b.length == 1,
          b.head._1 == driverB1,
          // cross-tenant guard: company A never sees company B's driver
          !a.exists(_._1 == driverB1)
        )
      },
      test("findAvailableByCompanyId excludes non-Available drivers") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanDrivers(xa)
          repo = PostgresDriverLocationRepository(xa)
          _   <- seedDriver(xa, driverA1, companyA, "Available")
          _   <- seedDriver(xa, driverA2, companyA, "Offline")
          a   <- repo.findAvailableByCompanyId(companyA)
        } yield assertTrue(
          a.length == 1,
          a.head._1 == driverA1,
          !a.exists(_._1 == driverA2)
        )
      },
      test("findAvailableByCompanyId returns empty for a company with no available drivers") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanDrivers(xa)
          repo   = PostgresDriverLocationRepository(xa)
          _     <- seedDriver(xa, driverA2, companyA, "Offline")
          empty <- repo.findAvailableByCompanyId(companyA)
        } yield assertTrue(empty.isEmpty)
      },
      test("findAvailableByCompanyId returns coordinates when present and None when absent") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanDrivers(xa)
          repo = PostgresDriverLocationRepository(xa)
          _   <- seedDriver(xa, driverA1, companyA, "Available", Some(48.1), Some(11.5))
          _   <- seedDriver(xa, driverA2, companyA, "Available") // no coords
          a   <- repo.findAvailableByCompanyId(companyA)
        } yield assertTrue(
          a.length == 2,
          a.find(_._1 == driverA1).exists(d => d._3.contains(48.1) && d._4.contains(11.5)),
          a.find(_._1 == driverA2).exists(d => d._3.isEmpty && d._4.isEmpty)
        )
      },
      // -----------------------------------------------------------------------
      // NEW: updateLocation INSERT and UPDATE branches
      // -----------------------------------------------------------------------
      test("updateLocation INSERT branch: new driver gets first location set") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanDrivers(xa)
          repo = PostgresDriverLocationRepository(xa)
          // driverA1 has a persons row but NO drivers row yet
          _   <- repo.updateLocation(driverA1, 48.1, 11.5)
          loc <- repo.getLocation(driverA1)
        } yield assertTrue(
          loc.isDefined,
          loc.get.driverId == driverA1,
          loc.get.latitude == 48.1,
          loc.get.longitude == 11.5
        )
      } @@ TestAspect.tag("integration"),
      test("updateLocation UPDATE branch: existing driver's location is replaced") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanDrivers(xa)
          repo = PostgresDriverLocationRepository(xa)
          // Seed an existing drivers row with old coordinates
          _   <- seedDriver(xa, driverA1, companyA, "Available", Some(0.0), Some(0.0))
          _   <- repo.updateLocation(driverA1, 48.1, 11.5)
          loc <- repo.getLocation(driverA1)
        } yield assertTrue(
          loc.isDefined,
          loc.get.latitude == 48.1,
          loc.get.longitude == 11.5
        )
      } @@ TestAspect.tag("integration"),
      test("updateLocation: concurrent FIRST updates for the same driver all succeed (atomic upsert)") {
        // Regression for the two-transaction UPDATE-then-INSERT window: several concurrent
        // first updates all saw zero updated rows and raced their INSERTs — every loser
        // failed on the drivers.id primary-key conflict and its update was lost (error to
        // the caller). The single INSERT ... ON CONFLICT (id) DO UPDATE upsert has no such
        // window: all callers must succeed and a location must be recorded.
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanDrivers(xa)
          repo   = PostgresDriverLocationRepository(xa)
          // driverA1 has a persons row but NO drivers row yet — every caller races the insert.
          exits <- ZIO.collectAllPar(
                     (1 to 8).toList.map(i => repo.updateLocation(driverA1, 48.0 + i * 0.01, 11.5).exit)
                   )
          loc   <- repo.getLocation(driverA1)
        } yield assertTrue(
          exits.forall(_.isSuccess),
          loc.isDefined
        )
      } @@ TestAspect.tag("integration"),
      test("updateLocation when person row missing: silent no-op, getLocation returns None") {
        val unknownId = PersonId(UUID.fromString("ffffffff-ffff-ffff-ffff-ffffffffffff"))
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanDrivers(xa)
          repo    = PostgresDriverLocationRepository(xa)
          result <- repo.updateLocation(unknownId, 1.0, 1.0).exit
          loc    <- repo.getLocation(unknownId)
        } yield assertTrue(
          result.isSuccess,
          loc.isEmpty
        )
      } @@ TestAspect.tag("integration")
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
