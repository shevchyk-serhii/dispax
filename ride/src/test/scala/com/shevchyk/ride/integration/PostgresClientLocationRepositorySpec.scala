package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.repository.PostgresClientLocationRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for PostgresClientLocationRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresClientLocationRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000050-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000051-0000-0000-0000-000000000001"))
  val rideId1       = RideId(UUID.fromString("00000052-0000-0000-0000-000000000001"))
  val rideId2       = RideId(UUID.fromString("00000052-0000-0000-0000-000000000002"))

  private def seedRide(xa: Transactor[Task], rid: RideId): Task[Unit] =
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, status,
            from_address, to_address, pickup_datetime, request_time)
            VALUES (${rid.value}, ${clientId.value}, ${clientId.value}, ${testCompanyId.value}, 'Requested',
            'A', 'B', NOW(), NOW())
            ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Loc GmbH', 'loc-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Loc Client', 'loc-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa) *> seedRide(xa, rideId1) *> seedRide(xa, rideId2)

  private def cleanLocations(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM client_locations".update.run.transact(xa).unit

  def spec =
    suite("PostgresClientLocationRepository")(
      test("updateLocation inserts then getLocation round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanLocations(xa)
          repo   = PostgresClientLocationRepository(xa)
          _     <- repo.updateLocation(rideId1, clientId, 48.1374, 11.5755)
          found <- repo.getLocation(rideId1)
        } yield assertTrue(
          found.isDefined,
          found.get.rideId == rideId1,
          found.get.clientId == clientId,
          found.get.latitude == 48.1374,
          found.get.longitude == 11.5755
        )
      },
      test("updateLocation upserts on conflict (ride_id PK)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanLocations(xa)
          repo    = PostgresClientLocationRepository(xa)
          _      <- repo.updateLocation(rideId1, clientId, 48.0, 11.0)
          _      <- repo.updateLocation(rideId1, clientId, 49.5, 12.5)
          found  <- repo.getLocation(rideId1)
          all    <- sql"SELECT COUNT(*) FROM client_locations WHERE ride_id = ${rideId1.value}".query[Int].unique.transact(xa)
        } yield assertTrue(
          all == 1,
          found.get.latitude == 49.5,
          found.get.longitude == 12.5
        )
      },
      test("getLocation returns None for unknown ride and isolates by ride") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanLocations(xa)
          repo   = PostgresClientLocationRepository(xa)
          _     <- repo.updateLocation(rideId1, clientId, 1.0, 2.0)
          ride1 <- repo.getLocation(rideId1)
          ride2 <- repo.getLocation(rideId2)
        } yield assertTrue(
          ride1.isDefined,
          ride2.isEmpty
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
