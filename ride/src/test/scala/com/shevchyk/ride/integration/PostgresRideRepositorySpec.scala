package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PostgresPersonRepository
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

/** Integration tests for PostgresRideRepository against a real PostgreSQL database via Testcontainers. */
object PostgresRideRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  val driverId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val creatorId     = clientId

  /** Insert prerequisite company + persons directly via SQL (needed for FK constraints). */
  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Test Client', 'client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Test Driver', 'driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM rides".update.run.transact(xa).unit

  private def makeRide(
      id: RideId = RideId(UUID.randomUUID()),
      status: RideStatus = RideStatus.Requested,
      driver: Option[PersonId] = None,
      scheduledTime: Option[Instant] = None,
      notes: Option[String] = None,
      specifics: Option[RideSpecifics] = None
  ): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = creatorId,
    companyId = testCompanyId,
    driverId = driver,
    status = status,
    pickupLocation = Location("Munich Airport", Some(48.3537), Some(11.7750)),
    dropoffLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    pickupDateTime = Instant.now().plusSeconds(3600),
    scheduledTime = scheduledTime,
    requestTime = Instant.now(),
    notes = notes,
    specifics = specifics
  )

  def spec = suite("PostgresRideRepository")(
    test("create and findById round-trip") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        ride  = makeRide(notes = Some("Integration test ride"))
        _    <- repo.create(ride)
        found <- repo.findById(ride.id)
      } yield assertTrue(
        found.isDefined,
        found.get.id == ride.id,
        found.get.clientId == clientId,
        found.get.companyId == testCompanyId,
        found.get.notes.contains("Integration test ride"),
        found.get.pickupLocation.address == "Munich Airport",
        found.get.dropoffLocation.address == "Marienplatz",
        found.get.status == RideStatus.Requested
      )
    },

    test("create with AirportTransfer specifics") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        ride  = makeRide(specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH1234")))
        _    <- repo.create(ride)
        found <- repo.findById(ride.id)
      } yield assertTrue(
        found.get.specifics.isDefined,
        found.get.specifics.get == RideSpecifics.AirportTransfer("MUC", "LH1234")
      )
    },

    test("update changes status and driver") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        _      <- seedTestData(xa)
        _      <- cleanRides(xa)
        repo    = PostgresRideRepository(xa)
        ride    = makeRide()
        _      <- repo.create(ride)
        updated = ride.copy(status = RideStatus.Assigned, driverId = Some(driverId))
        _      <- repo.update(updated)
        found  <- repo.findById(ride.id)
      } yield assertTrue(
        found.get.status == RideStatus.Assigned,
        found.get.driverId.contains(driverId)
      )
    },

    test("findByCompanyId returns only matching company rides") {
      for {
        xa    <- ZIO.service[Transactor[Task]]
        _     <- seedTestData(xa)
        _     <- cleanRides(xa)
        repo   = PostgresRideRepository(xa)
        ride1  = makeRide()
        ride2  = makeRide()
        _     <- repo.create(ride1)
        _     <- repo.create(ride2)
        rides <- repo.findByCompanyId(testCompanyId)
        empty <- repo.findByCompanyId(CompanyId(UUID.randomUUID()))
      } yield assertTrue(
        rides.length == 2,
        rides.forall(_.companyId == testCompanyId),
        empty.isEmpty
      )
    },

    test("findByDriverId returns assigned rides") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        r1    = makeRide(driver = Some(driverId))
        r2    = makeRide(driver = None)
        _    <- repo.create(r1)
        _    <- repo.create(r2)
        rides <- repo.findByDriverId(driverId)
      } yield assertTrue(
        rides.length == 1,
        rides.head.id == r1.id
      )
    },

    test("findByStatus filters correctly") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        r1    = makeRide(status = RideStatus.Requested)
        r2    = makeRide(status = RideStatus.Completed)
        _    <- repo.create(r1)
        _    <- repo.create(r2)
        requested <- repo.findByStatus(RideStatus.Requested)
        completed <- repo.findByStatus(RideStatus.Completed)
      } yield assertTrue(
        requested.length == 1,
        requested.head.id == r1.id,
        completed.length == 1,
        completed.head.id == r2.id
      )
    },

    test("delete removes ride") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        ride  = makeRide()
        _    <- repo.create(ride)
        _    <- repo.delete(ride.id)
        found <- repo.findById(ride.id)
      } yield assertTrue(found.isEmpty)
    },

    test("countByCompanyGroupedByStatus aggregates correctly") {
      for {
        xa    <- ZIO.service[Transactor[Task]]
        _     <- seedTestData(xa)
        _     <- cleanRides(xa)
        repo   = PostgresRideRepository(xa)
        _     <- repo.create(makeRide(status = RideStatus.Requested))
        _     <- repo.create(makeRide(status = RideStatus.Requested))
        _     <- repo.create(makeRide(status = RideStatus.Completed))
        stats <- repo.countByCompanyGroupedByStatus(testCompanyId)
      } yield assertTrue(
        stats("Requested") == 2,
        stats("Completed") == 1
      )
    },

    test("sumRevenueByCompany sums completed rides") {
      for {
        xa  <- ZIO.service[Transactor[Task]]
        _   <- seedTestData(xa)
        _   <- cleanRides(xa)
        repo = PostgresRideRepository(xa)
        r1   = makeRide(status = RideStatus.Completed).copy(estimatedPrice = Some(BigDecimal(50)))
        r2   = makeRide(status = RideStatus.Completed).copy(finalPrice = Some(BigDecimal(75)))
        r3   = makeRide(status = RideStatus.Requested).copy(estimatedPrice = Some(BigDecimal(100))) // not completed
        _   <- repo.create(r1)
        _   <- repo.create(r2)
        _   <- repo.create(r3)
        rev <- repo.sumRevenueByCompany(testCompanyId)
      } yield assertTrue(rev == BigDecimal(125)) // 50 (est) + 75 (final)
    },

    test("payment fields round-trip") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        now   = Instant.now()
        ride  = makeRide().copy(
                  paymentStatus = PaymentStatus.Paid,
                  paymentMethod = Some(PaymentMethod.Cash),
                  paidAt = Some(now)
                )
        _    <- repo.create(ride)
        found <- repo.findById(ride.id)
      } yield assertTrue(
        found.get.paymentStatus == PaymentStatus.Paid,
        found.get.paymentMethod.contains(PaymentMethod.Cash),
        found.get.paidAt.isDefined
      )
    },

    test("cancellation fields round-trip") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        ride  = makeRide(status = RideStatus.Cancelled).copy(
                  cancellationReason = Some("client_no_show"),
                  cancellationFee = Some(BigDecimal(10)),
                  cancelledBy = Some(clientId)
                )
        _    <- repo.create(ride)
        found <- repo.findById(ride.id)
      } yield assertTrue(
        found.get.cancellationReason.contains("client_no_show"),
        found.get.cancellationFee.contains(BigDecimal(10)),
        found.get.cancelledBy.contains(clientId)
      )
    },

    test("VIP fields round-trip") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanRides(xa)
        repo  = PostgresRideRepository(xa)
        ride  = makeRide().copy(isVipRide = true, preferredDriverUsed = true)
        _    <- repo.create(ride)
        found <- repo.findById(ride.id)
      } yield assertTrue(
        found.get.isVipRide,
        found.get.preferredDriverUsed
      )
    }

  ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
