package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresRideRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for the flight-tracking columns (flight_gate / flight_terminal / flight_status / flight_time)
 * written by `updateFlightStatus` and read back via `findFlightStatus` against a real PostgreSQL.
 */
object PostgresFlightStatusSpec extends ZIOSpecDefault:

  private val pgCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val pgClientId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  private val pgDriverId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for
      _ <-
        sql"""INSERT INTO companies (id, name, email)
              VALUES (${pgCompanyId.value}, 'Test GmbH', 'test@example.com')
              ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
              VALUES (${pgClientId.value}, 'Test Client', 'client@test.com',
                      'client'::person_role, ${pgCompanyId.value}, 'x')
              ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
              VALUES (${pgDriverId.value}, 'Test Driver', 'driver@test.com',
                      'driver'::person_role, ${pgCompanyId.value}, 'x')
              ON CONFLICT DO NOTHING""".update.run
    yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM rides".update.run.transact(xa).unit

  private def makeRide(id: RideId): Ride = Ride(
    id = id,
    clientId = pgClientId,
    creatorId = pgClientId,
    companyId = pgCompanyId,
    driverId = Some(pgDriverId),
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    dropoffLocation = Location("MUC Airport", Some(48.3537), Some(11.7860)),
    pickupDateTime = Instant.now().plusSeconds(3600),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH123"), isArrival = true))
  )

  def spec =
    suite("PostgresRideRepository flight status (real DB)")(
      test("freshly created ride has empty flight status") {
        for
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanRides(xa)
          repo = PostgresRideRepository(xa)
          id   = RideId(UUID.randomUUID())
          _   <- repo.create(makeRide(id))
          row <- repo.findFlightStatus(id)
        yield assertTrue(row.exists(!_.nonEmpty))
      },
      test("updateFlightStatus persists and round-trips all four columns") {
        val t = Instant.parse("2026-06-26T08:20:00Z")
        for
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanRides(xa)
          repo = PostgresRideRepository(xa)
          id   = RideId(UUID.randomUUID())
          _   <- repo.create(makeRide(id))
          ok  <- repo.updateFlightStatus(id, Some("A12"), Some("T2"), Some("delayed"), Some(t), None)
          row <- repo.findFlightStatus(id)
        yield assertTrue(
          ok,
          row.contains(FlightStatusRow(Some("A12"), Some("T2"), Some("delayed"), Some(t)))
        )
      },
      test("updateFlightStatus on a missing ride updates no row") {
        for
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanRides(xa)
          repo = PostgresRideRepository(xa)
          ok  <- repo.updateFlightStatus(RideId(UUID.randomUUID()), None, Some("T1"), Some("landed"), None, None)
        yield assertTrue(!ok)
      },
      test("findFlightStatus is None for an unknown ride") {
        for
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanRides(xa)
          repo = PostgresRideRepository(xa)
          row <- repo.findFlightStatus(RideId(UUID.randomUUID()))
        yield assertTrue(row.isEmpty)
      },
      test("findFlightStatusFor bulk-reads only rides that have flight data") {
        val t = Instant.parse("2026-06-26T09:00:00Z")
        for
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanRides(xa)
          repo    = PostgresRideRepository(xa)
          withFs  = RideId(UUID.randomUUID())
          without = RideId(UUID.randomUUID())
          unknown = RideId(UUID.randomUUID())
          _      <- repo.create(makeRide(withFs))
          _      <- repo.create(makeRide(without))
          _      <- repo.updateFlightStatus(withFs, Some("G35"), Some("T2"), Some("landed"), Some(t), None)
          map    <- repo.findFlightStatusFor(List(withFs, without, unknown))
        yield assertTrue(
          // the ride with persisted flight data is present with the exact row,
          map.get(withFs).contains(FlightStatusRow(Some("G35"), Some("T2"), Some("landed"), Some(t))),
          // the ride that never got flight data carries only empty columns,
          map.get(without).forall(!_.nonEmpty),
          // and the unknown id is absent entirely.
          !map.contains(unknown)
        )
      },
      test("findFlightStatusFor of an empty list returns an empty map") {
        for
          xa  <- ZIO.service[Transactor[Task]]
          repo = PostgresRideRepository(xa)
          map <- repo.findFlightStatusFor(Nil)
        yield assertTrue(map.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.tag("integration")
