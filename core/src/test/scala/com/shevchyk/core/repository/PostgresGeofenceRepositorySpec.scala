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
 * Integration tests for PostgresGeofenceRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresGeofenceRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("0b000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("0b000001-0000-0000-0000-000000000002"))
  val driverId       = PersonId(UUID.fromString("0b000002-0000-0000-0000-000000000001"))
  val otherDriverId  = PersonId(UUID.fromString("0b000002-0000-0000-0000-000000000002"))

  private def insertPerson(id: PersonId, email: String, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
          VALUES (${id.value}, 'Test Driver', $email, 'driver'::person_role, ${company.value}, 'placeholder')
          ON CONFLICT DO NOTHING""".update.run

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'geo-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'geo-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- insertPerson(driverId, "geo-driver@test.com", testCompanyId)
      _ <- insertPerson(otherDriverId, "geo-driver2@test.com", testCompanyId)
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM geofence_alerts".update.run
      _ <- sql"DELETE FROM geofences".update.run
    } yield ()).transact(xa).unit

  private def makeGeofence(
      id: GeofenceId = GeofenceId(UUID.randomUUID()),
      company: CompanyId = testCompanyId,
      gType: GeofenceType = GeofenceType.Airport,
      active: Boolean = true
  ): Geofence = Geofence(
    id = id,
    companyId = company,
    name = "Munich Airport Zone",
    geofenceType = gType,
    centerLatitude = 48.3537,
    centerLongitude = 11.7750,
    radiusMeters = 2000,
    isActive = active,
    notifyOnEntry = true,
    notifyOnExit = false,
    createdAt = Instant.now()
  )

  private def makeAlert(
      geofenceId: GeofenceId,
      driver: PersonId = driverId,
      company: CompanyId = testCompanyId,
      timestamp: Instant
  ): GeofenceAlert = GeofenceAlert(
    id = UUID.randomUUID(),
    geofenceId = geofenceId,
    driverId = driver,
    companyId = company,
    alertType = "entry",
    geofenceName = "Munich Airport Zone",
    latitude = 48.3537,
    longitude = 11.7750,
    timestamp = timestamp
  )

  def spec =
    suite("PostgresGeofenceRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresGeofenceRepository(xa)
          fence  = makeGeofence(gType = GeofenceType.ServiceArea)
          _     <- repo.create(fence)
          found <- repo.findById(fence.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == fence.id,
          found.get.companyId == testCompanyId,
          found.get.name == "Munich Airport Zone",
          found.get.geofenceType == GeofenceType.ServiceArea,
          found.get.radiusMeters == 2000,
          found.get.isActive,
          found.get.notifyOnEntry,
          !found.get.notifyOnExit
        )
      },
      test("findByCompanyId isolates by company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGeofenceRepository(xa)
          _      <- repo.create(makeGeofence())
          _      <- repo.create(makeGeofence())
          _      <- repo.create(makeGeofence(company = otherCompanyId))
          mine   <- repo.findByCompanyId(testCompanyId)
          others <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(mine.length == 2, mine.forall(_.companyId == testCompanyId), others.length == 1)
      },
      test("findActiveByCompanyId returns only active geofences") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGeofenceRepository(xa)
          active  = makeGeofence(active = true)
          _      <- repo.create(active)
          _      <- repo.create(makeGeofence(active = false))
          result <- repo.findActiveByCompanyId(testCompanyId)
        } yield assertTrue(result.length == 1, result.head.id == active.id, result.forall(_.isActive))
      },
      test("update changes mutable fields") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGeofenceRepository(xa)
          fence   = makeGeofence()
          _      <- repo.create(fence)
          updated = fence.copy(name = "Updated", radiusMeters = 500, isActive = false, notifyOnExit = true)
          _      <- repo.update(updated)
          found  <- repo.findById(fence.id)
        } yield assertTrue(
          found.get.name == "Updated",
          found.get.radiusMeters == 500,
          !found.get.isActive,
          found.get.notifyOnExit
        )
      },
      test("delete removes geofence") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresGeofenceRepository(xa)
          fence    = makeGeofence()
          _       <- repo.create(fence)
          cross   <- repo.delete(fence.id, otherCompanyId)
          still   <- repo.findById(fence.id)
          deleted <- repo.delete(fence.id, testCompanyId)
          missing <- repo.delete(GeofenceId(UUID.randomUUID()), testCompanyId)
          found   <- repo.findById(fence.id)
        } yield assertTrue(!cross, still.isDefined, deleted, !missing, found.isEmpty)
      },
      test("saveAlert and findAlertsByCompany with limit and ordering") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGeofenceRepository(xa)
          fence   = makeGeofence()
          _      <- repo.create(fence)
          now     = Instant.now()
          older  <- repo.saveAlert(makeAlert(fence.id, timestamp = now.minusSeconds(100)))
          newer  <- repo.saveAlert(makeAlert(fence.id, timestamp = now))
          _      <- repo.saveAlert(makeAlert(fence.id, company = otherCompanyId, timestamp = now.minusSeconds(50)))
          all    <- repo.findAlertsByCompany(testCompanyId, 10)
          capped <- repo.findAlertsByCompany(testCompanyId, 1)
        } yield assertTrue(
          all.length == 2,
          all.forall(_.companyId == testCompanyId),
          all.head.id == newer.id,
          all(1).id == older.id,
          capped.length == 1,
          capped.head.id == newer.id
        )
      },
      test("findAlertsByDriver isolates by driver with limit") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresGeofenceRepository(xa)
          fence   = makeGeofence()
          _      <- repo.create(fence)
          now     = Instant.now()
          _      <- repo.saveAlert(makeAlert(fence.id, driver = driverId, timestamp = now.minusSeconds(10)))
          _      <- repo.saveAlert(makeAlert(fence.id, driver = driverId, timestamp = now))
          _      <- repo.saveAlert(makeAlert(fence.id, driver = otherDriverId, timestamp = now))
          mine   <- repo.findAlertsByDriver(driverId, 10)
          capped <- repo.findAlertsByDriver(driverId, 1)
        } yield assertTrue(mine.length == 2, mine.forall(_.driverId == driverId), capped.length == 1)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
