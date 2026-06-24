package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{PostgresRideRepository, RideRepository}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for the driver-ride-confirmation feature against a real PostgreSQL database (Testcontainers).
 *
 * Covers:
 *   - confirmed_at / rejection_* column round-trip via create + findById
 *   - confirmed_at / rejection_* column round-trip via updateIfStatus (the CAS path)
 *   - Reading/writing the 'Confirmed' enum value — validates V10/V11 migrations applied cleanly
 *   - findRidesNeedingConfirmation window query
 *
 * Note: PostgresSentConfirmationRequestRepository integration tests are in
 * notification/src/test/…/PostgresSentConfirmationRequestRepositorySpec (notification module can depend on core where
 * the trait lives, without a circular reference).
 */
object PostgresRideConfirmationIntegrationSpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  val driverId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val creatorId     = clientId

  // Seed prerequisite company + persons (FK constraints).
  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Test Client', 'client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Test Driver', 'driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM rides".update.run.transact(xa).unit

  private def baseRide(
      id: RideId = RideId(UUID.randomUUID()),
      status: RideStatus = RideStatus.Requested,
      driver: Option[PersonId] = None,
      pickupAt: Instant = Instant.now().plusSeconds(3600)
  ): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = creatorId,
    companyId = testCompanyId,
    driverId = driver,
    status = status,
    pickupLocation = Location("Munich Airport", Some(48.3537), Some(11.7750)),
    dropoffLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    pickupDateTime = pickupAt,
    requestTime = Instant.now()
  )

  def spec =
    suite("PostgresRideConfirmation Integration")(
      // ── V10 / V11 migration smoke-test: write and read the 'Confirmed' enum value ──
      test("write and read the Confirmed enum value (V10 migration validation)") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = baseRide(status = RideStatus.Confirmed, driver = Some(driverId))
                     .copy(confirmedAt = Some(Instant.now()))
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.isDefined,
          found.get.status == RideStatus.Confirmed
        )
      },

      // ── confirmed_at column round-trip via create ─────────────────────────────
      test("confirmed_at persists and reads back correctly (V11 column)") {
        val confirmedAt = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = baseRide(status = RideStatus.Confirmed, driver = Some(driverId))
                     .copy(confirmedAt = Some(confirmedAt))
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.isDefined,
          found.get.confirmedAt.isDefined,
          found.get.confirmedAt.get.truncatedTo(java.time.temporal.ChronoUnit.MILLIS) == confirmedAt
        )
      },

      // ── rejection_* columns round-trip via create ─────────────────────────────
      test("rejection columns (rejection_reason, rejected_by, rejected_at) persist correctly (V11 columns)") {
        val rejectedAt = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = baseRide(status = RideStatus.Requested)
                     .copy(
                       rejectionReason = Some("car breakdown"),
                       rejectedBy = Some(driverId),
                       rejectedAt = Some(rejectedAt)
                     )
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.isDefined,
          found.get.rejectionReason.contains("car breakdown"),
          found.get.rejectedBy.contains(driverId),
          found.get.rejectedAt.isDefined,
          found.get.rejectedAt.get.truncatedTo(java.time.temporal.ChronoUnit.MILLIS) == rejectedAt
        )
      },

      // ── confirmed_at persists via updateIfStatus (the atomic CAS path) ──────
      test("confirmed_at and rejection_* are written through the updateIfStatus path") {
        val confirmedAt = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          // Create in Assigned state
          ride     = baseRide(status = RideStatus.Assigned, driver = Some(driverId))
          _       <- repo.create(ride)
          // Apply Assigned → Confirmed via updateIfStatus
          updated  = ride.copy(
                       status = RideStatus.Confirmed,
                       confirmedAt = Some(confirmedAt)
                     )
          applied <- repo.updateIfStatus(updated, Set(RideStatus.Assigned))
          found   <- repo.findById(ride.id)
        } yield assertTrue(
          applied,
          found.isDefined,
          found.get.status == RideStatus.Confirmed,
          found.get.confirmedAt.isDefined,
          found.get.confirmedAt.get.truncatedTo(java.time.temporal.ChronoUnit.MILLIS) == confirmedAt
        )
      },
      test("rejection fields are written through the updateIfStatus path (Assigned → Requested)") {
        val rejectedAt = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          ride     = baseRide(status = RideStatus.Assigned, driver = Some(driverId))
          _       <- repo.create(ride)
          updated  = ride.copy(
                       status = RideStatus.Requested,
                       driverId = None,
                       rejectionReason = Some("personal reason"),
                       rejectedBy = Some(driverId),
                       rejectedAt = Some(rejectedAt)
                     )
          applied <- repo.updateIfStatus(updated, Set(RideStatus.Assigned))
          found   <- repo.findById(ride.id)
        } yield assertTrue(
          applied,
          found.isDefined,
          found.get.status == RideStatus.Requested,
          found.get.driverId.isEmpty,
          found.get.rejectionReason.contains("personal reason"),
          found.get.rejectedBy.contains(driverId)
        )
      },
      test("updateIfStatus returns false when current status is NOT in expectedStatuses (CAS guard)") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          ride     = baseRide(status = RideStatus.Requested)
          _       <- repo.create(ride)
          // Try CAS expecting Assigned, but actual is Requested → must fail
          updated  = ride.copy(status = RideStatus.Confirmed, driverId = Some(driverId))
          applied <- repo.updateIfStatus(updated, Set(RideStatus.Assigned))
          found   <- repo.findById(ride.id)
        } yield assertTrue(
          !applied,
          found.get.status == RideStatus.Requested // unchanged
        )
      },

      // ── findRidesNeedingConfirmation ──────────────────────────────────────────
      test("findRidesNeedingConfirmation returns Assigned rides with driver in the window") {
        val now      = Instant.now()
        val dayStart = now.minusSeconds(3600)
        val dayEnd   = now.plusSeconds(86400)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          // Should be found: Assigned + driver + pickup in window
          r1     = baseRide(status = RideStatus.Assigned, driver = Some(driverId), pickupAt = now.plusSeconds(1800))
          // Should NOT be found: Requested (not Assigned)
          r2     = baseRide(status = RideStatus.Requested, driver = Some(driverId), pickupAt = now.plusSeconds(1800))
          // Should NOT be found: Assigned but no driver
          r3     = baseRide(status = RideStatus.Assigned, driver = None, pickupAt = now.plusSeconds(1800))
          // Should NOT be found: pickup outside the window (yesterday)
          r4     = baseRide(status = RideStatus.Assigned, driver = Some(driverId), pickupAt = now.minusSeconds(7200))
          // Should NOT be found: already Confirmed
          r5     = baseRide(status = RideStatus.Confirmed, driver = Some(driverId), pickupAt = now.plusSeconds(1800))
          _     <- ZIO.foreachDiscard(List(r1, r2, r3, r4, r5))(repo.create)
          found <- repo.findRidesNeedingConfirmation(dayStart, dayEnd)
        } yield assertTrue(
          found.size == 1,
          found.head.id == r1.id,
          found.head.status == RideStatus.Assigned,
          found.head.driverId.contains(driverId)
        )
      },
      test("findRidesNeedingConfirmation returns empty list when no rides match") {
        val now = Instant.now()
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          found <- repo.findRidesNeedingConfirmation(now.plusSeconds(3600), now.plusSeconds(7200))
        } yield assertTrue(found.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@
      TestAspect.sequential @@
      TestAspect.withLiveClock @@
      TestAspect.tag("integration")
}
