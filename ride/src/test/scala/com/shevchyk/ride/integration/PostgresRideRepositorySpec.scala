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

/**
 * Integration tests for PostgresRideRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresRideRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  val driverId      = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val creatorId     = clientId

  /**
   * Insert prerequisite company + persons directly via SQL (needed for FK constraints).
   */
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

  def spec =
    suite("PostgresRideRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = makeRide(notes = Some("Integration test ride"))
          _     <- repo.create(ride)
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
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = makeRide(specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH1234")))
          _     <- repo.create(ride)
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
      test("findByCompanyIdPaginated orders by request_time desc and applies limit/offset in SQL") {
        val base = Instant.parse("2026-01-01T00:00:00Z")
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          // Five rides with strictly increasing request times → newest is r5.
          rides  = (0 until 5).map(i => makeRide().copy(requestTime = base.plusSeconds(i.toLong * 60))).toList
          _     <- ZIO.foreachDiscard(rides)(repo.create)
          page1 <- repo.findByCompanyIdPaginated(testCompanyId, offset = 0, limit = 2)
          page2 <- repo.findByCompanyIdPaginated(testCompanyId, offset = 2, limit = 2)
          page3 <- repo.findByCompanyIdPaginated(testCompanyId, offset = 4, limit = 2)
        } yield assertTrue(
          page1.map(_.id) == List(rides(4).id, rides(3).id),
          page2.map(_.id) == List(rides(2).id, rides(1).id),
          page3.map(_.id) == List(rides(0).id)
        )
      },
      test("findByDriverIdPaginated returns only the driver's rides, newest first") {
        val base = Instant.parse("2026-02-01T00:00:00Z")
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanRides(xa)
          repo  = PostgresRideRepository(xa)
          d1    = makeRide(driver = Some(driverId)).copy(requestTime = base)
          d2    = makeRide(driver = Some(driverId)).copy(requestTime = base.plusSeconds(60))
          other = makeRide(driver = None).copy(requestTime = base.plusSeconds(120))
          _    <- ZIO.foreachDiscard(List(d1, d2, other))(repo.create)
          page <- repo.findByDriverIdPaginated(driverId, offset = 0, limit = 10)
        } yield assertTrue(
          page.map(_.id) == List(d2.id, d1.id),
          page.forall(_.driverId.contains(driverId))
        )
      },
      test("findByDriverId returns assigned rides") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          r1     = makeRide(driver = Some(driverId))
          r2     = makeRide(driver = None)
          _     <- repo.create(r1)
          _     <- repo.create(r2)
          rides <- repo.findByDriverId(driverId)
        } yield assertTrue(
          rides.length == 1,
          rides.head.id == r1.id
        )
      },
      test("findByStatus filters correctly") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- cleanRides(xa)
          repo       = PostgresRideRepository(xa)
          r1         = makeRide(status = RideStatus.Requested)
          r2         = makeRide(status = RideStatus.Completed)
          _         <- repo.create(r1)
          _         <- repo.create(r2)
          requested <- repo.findByStatus(RideStatus.Requested)
          completed <- repo.findByStatus(RideStatus.Completed)
        } yield assertTrue(
          requested.length == 1,
          requested.head.id == r1.id,
          completed.length == 1,
          completed.head.id == r2.id
        )
      },
      test("findByStatusAndCompany does not leak rides across tenants") {
        // Regression: getPendingRidesServer used the unscoped findByStatus, so a
        // dispatcher saw Requested rides of every company. The scoped variant must
        // only return rides of the given company.
        val company2Id = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        val client2Id  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000003"))
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <-
            (for {
              _ <-
                sql"""INSERT INTO companies (id, name, email)
                               VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                               ON CONFLICT DO NOTHING""".update.run
              _ <-
                sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                               VALUES (${client2Id.value}, 'Client 2', 'client2@test.com',
                                       'client'::person_role, ${company2Id.value}, 'placeholder')
                               ON CONFLICT DO NOTHING""".update.run
            } yield ()).transact(xa)
          _   <- cleanRides(xa)
          repo = PostgresRideRepository(xa)
          r1   = makeRide(status = RideStatus.Requested) // company 1
          r2   = makeRide(status = RideStatus.Requested).copy(companyId = company2Id, clientId = client2Id)
          _   <- repo.create(r1)
          _   <- repo.create(r2)
          c1  <- repo.findByStatusAndCompany(RideStatus.Requested, testCompanyId)
          c2  <- repo.findByStatusAndCompany(RideStatus.Requested, company2Id)
        } yield assertTrue(
          c1.length == 1,
          c1.head.id == r1.id,
          c2.length == 1,
          c2.head.id == r2.id
        )
      },
      test("delete removes ride") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = makeRide()
          _     <- repo.create(ride)
          _     <- repo.delete(ride.id, CompanyId(UUID.randomUUID())) // cross-tenant: no-op
          still <- repo.findById(ride.id)
          _     <- repo.delete(ride.id, testCompanyId)
          found <- repo.findById(ride.id)
        } yield assertTrue(still.isDefined, found.isEmpty)
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
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          now    = Instant.now()
          ride   = makeRide().copy(
                     paymentStatus = PaymentStatus.Paid,
                     paymentMethod = Some(PaymentMethod.Cash),
                     paidAt = Some(now)
                   )
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.get.paymentStatus == PaymentStatus.Paid,
          found.get.paymentMethod.contains(PaymentMethod.Cash),
          found.get.paidAt.isDefined
        )
      },
      test("markPaidIfCompleted is an atomic field-level CAS: only one of two concurrent calls wins") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          ride     = makeRide(status = RideStatus.Completed)
          _       <- repo.create(ride)
          // Two concurrent markPaid calls on the same Completed ride: exactly one writes the payment
          // columns, the other is a no-op (payment_status <> 'Paid' guard fails for the loser).
          results <- repo
                       .markPaidIfCompleted(ride.id, Some(PaymentMethod.Cash))
                       .zipPar(repo.markPaidIfCompleted(ride.id, Some(PaymentMethod.Card)))
          found   <- repo.findById(ride.id).map(_.get)
        } yield assertTrue(
          // Exactly one winner across the race.
          List(results._1, results._2).count(identity) == 1,
          found.paymentStatus == PaymentStatus.Paid,
          // The persisted method is the winner's, never None and never torn.
          found.paymentMethod.contains(PaymentMethod.Cash) || found.paymentMethod.contains(PaymentMethod.Card),
          found.paidAt.isDefined
        )
      },
      test("markPaidIfCompleted rejects a non-Completed ride and is idempotent on an already-Paid ride") {
        for {
          xa            <- ZIO.service[Transactor[Task]]
          _             <- seedTestData(xa)
          _             <- cleanRides(xa)
          repo           = PostgresRideRepository(xa)
          // Not Completed -> CAS does not apply.
          inProgress     = makeRide(status = RideStatus.InProgress)
          _             <- repo.create(inProgress)
          notApplied    <- repo.markPaidIfCompleted(inProgress.id, Some(PaymentMethod.Cash))
          afterIp       <- repo.findById(inProgress.id).map(_.get)
          // Completed -> first pay applies, second is a no-op (does not overwrite paid_at/method).
          completed      = makeRide(status = RideStatus.Completed)
          _             <- repo.create(completed)
          firstApplied  <- repo.markPaidIfCompleted(completed.id, Some(PaymentMethod.Cash))
          afterFirst    <- repo.findById(completed.id).map(_.get)
          secondApplied <- repo.markPaidIfCompleted(completed.id, Some(PaymentMethod.Card))
          afterSecond   <- repo.findById(completed.id).map(_.get)
        } yield assertTrue(
          !notApplied,
          afterIp.paymentStatus != PaymentStatus.Paid,
          firstApplied,
          afterFirst.paymentMethod.contains(PaymentMethod.Cash),
          afterFirst.paidAt.isDefined,
          !secondApplied,
          // Idempotent: original method and timestamp untouched by the second call.
          afterSecond.paymentMethod.contains(PaymentMethod.Cash),
          afterSecond.paidAt == afterFirst.paidAt
        )
      },
      test("cancellation fields round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = makeRide(status = RideStatus.Cancelled).copy(
                     cancellationReason = Some("client_no_show"),
                     cancellationFee = Some(BigDecimal(10)),
                     cancelledBy = Some(clientId)
                   )
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.get.cancellationReason.contains("client_no_show"),
          found.get.cancellationFee.contains(BigDecimal(10)),
          found.get.cancelledBy.contains(clientId)
        )
      },
      test("VIP fields round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          ride   = makeRide().copy(isVipRide = true, preferredDriverUsed = true)
          _     <- repo.create(ride)
          found <- repo.findById(ride.id)
        } yield assertTrue(
          found.get.isVipRide,
          found.get.preferredDriverUsed
        )
      },
      test("all Ride fields survive create→findById round-trip") {
        for {
          xa             <- ZIO.service[Transactor[Task]]
          _              <- seedTestData(xa)
          _              <- cleanRides(xa)
          repo            = PostgresRideRepository(xa)
          now             = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
          poolId          = RidePoolId(UUID.randomUUID())
          scheduleDayId   = UUID.randomUUID()
          clientCompanyId = UUID.randomUUID()
          invoiceId       = UUID.randomUUID()
          _              <-
            sql"""INSERT INTO ride_pools (id, company_id, created_by, max_passengers, current_passengers)
                        VALUES (${poolId.value}, ${testCompanyId.value}, ${clientId.value}, 4, 0)""".update.run
              .transact(xa)
          _              <-
            sql"""INSERT INTO schedule_days (id, driver_id, company_id, date, start_time, end_time, status)
                        VALUES ($scheduleDayId, ${driverId.value}, ${testCompanyId.value}, CURRENT_DATE, '08:00', '16:00', 'Scheduled')""".update.run
              .transact(xa)
          _              <-
            sql"""INSERT INTO client_companies (id, name, taxi_company_id)
                        VALUES ($clientCompanyId, 'Test Client Co', ${testCompanyId.value})""".update.run.transact(xa)
          _              <-
            sql"""INSERT INTO invoices (id, number, client_company_id, taxi_company_id, period_from, period_to)
                        VALUES ($invoiceId, 'INV-001', $clientCompanyId, ${testCompanyId.value}, CURRENT_DATE, CURRENT_DATE)""".update.run
              .transact(xa)
          ride            = Ride(
                              id = RideId(UUID.randomUUID()),
                              clientId = clientId,
                              creatorId = creatorId,
                              companyId = testCompanyId,
                              driverId = Some(driverId),
                              status = RideStatus.Assigned,
                              pickupLocation = Location("From Street 1", Some(48.1), Some(11.5)),
                              dropoffLocation = Location("To Street 2", Some(48.2), Some(11.6)),
                              pickupDateTime = now.plusSeconds(7200),
                              scheduledTime = Some(now.plusSeconds(3600)),
                              requestTime = now,
                              startTime = Some(now.plusSeconds(100)),
                              endTime = Some(now.plusSeconds(200)),
                              tariffId = None,
                              estimatedPrice = Some(BigDecimal("42.50")),
                              finalPrice = Some(BigDecimal("45.00")),
                              notes = Some("Please ring bell"),
                              specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH100")),
                              specialRequirements = Some("Wheelchair access"),
                              paymentStatus = PaymentStatus.Paid,
                              paymentMethod = Some(PaymentMethod.Card),
                              paidAt = Some(now),
                              cancellationReason = None,
                              cancellationFee = None,
                              cancelledBy = None,
                              isVipRide = true,
                              preferredDriverUsed = true,
                              poolId = Some(poolId),
                              scheduleDayId = Some(scheduleDayId),
                              invoiceId = Some(invoiceId)
                            )
          _              <- repo.create(ride)
          found          <- repo.findById(ride.id).map(_.get)
        } yield assertTrue(
          found.id == ride.id,
          found.clientId == ride.clientId,
          found.creatorId == ride.creatorId,
          found.companyId == ride.companyId,
          found.driverId == ride.driverId,
          found.status == ride.status,
          found.pickupLocation == ride.pickupLocation,
          found.dropoffLocation == ride.dropoffLocation,
          found.pickupDateTime == ride.pickupDateTime,
          found.scheduledTime == ride.scheduledTime,
          found.startTime == ride.startTime,
          found.endTime == ride.endTime,
          found.estimatedPrice == ride.estimatedPrice,
          found.finalPrice == ride.finalPrice,
          found.notes == ride.notes,
          found.specifics == ride.specifics,
          found.specialRequirements == ride.specialRequirements,
          found.paymentStatus == ride.paymentStatus,
          found.paymentMethod == ride.paymentMethod,
          found.paidAt.isDefined,
          found.isVipRide == ride.isVipRide,
          found.preferredDriverUsed == ride.preferredDriverUsed,
          found.poolId == ride.poolId,
          found.scheduleDayId == ride.scheduleDayId,
          found.invoiceId == ride.invoiceId
        )
      },
      test("vehicle_class persists and reads back correctly for all variants") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- cleanRides(xa)
          repo       = PostgresRideRepository(xa)
          business   = makeRide().copy(vehicleClass = VehicleClass.Business)
          van        = makeRide().copy(vehicleClass = VehicleClass.Van)
          _         <- repo.create(business)
          _         <- repo.create(van)
          fBusiness <- repo.findById(business.id)
          fVan      <- repo.findById(van.id)
        } yield assertTrue(
          fBusiness.isDefined,
          fBusiness.get.vehicleClass == VehicleClass.Business,
          fVan.isDefined,
          fVan.get.vehicleClass == VehicleClass.Van
        )
      },
      // -------------------------------------------------------------------------
      // Platform-level (cross-tenant) analytics — Testcontainers integration
      // These tests insert rides for TWO different companies and verify that the
      // platform methods aggregate across company boundaries (no company_id filter)
      // and that per-company breakdowns split correctly.
      // -------------------------------------------------------------------------
      suite("Platform-level cross-tenant analytics (Testcontainers)")(
        test("countAllRidesByStatus spans both companies") {
          val company2Id = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
          for {
            xa     <- ZIO.service[Transactor[Task]]
            _      <- seedTestData(xa)
            _      <-
              (for {
                _ <-
                  sql"""INSERT INTO companies (id, name, email)
                                 VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
                _ <-
                  sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                                 VALUES (${UUID.fromString("00000002-0000-0000-0000-000000000003")},
                                         'Client 2', 'client2@test.com', 'client'::person_role,
                                         ${company2Id.value}, 'placeholder')
                                 ON CONFLICT DO NOTHING""".update.run
              } yield ()).transact(xa)
            _      <- cleanRides(xa)
            repo    = PostgresRideRepository(xa)
            // Company 1: 2 Completed rides
            _      <- repo.create(makeRide(status = RideStatus.Completed))
            _      <- repo.create(makeRide(status = RideStatus.Completed))
            // Company 2: 1 Requested ride (different company)
            _      <- repo.create(
                        makeRide(status = RideStatus.Requested).copy(
                          companyId = company2Id,
                          clientId = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000003"))
                        )
                      )
            counts <- repo.countAllRidesByStatus()
          } yield assertTrue(
            // Both companies' rides appear in the aggregate — no company filter applied
            counts.getOrElse("Completed", 0) == 2,
            counts.getOrElse("Requested", 0) == 1
          )
        },
        test("sumAllRevenue aggregates Completed rides across both companies") {
          val company2Id = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
          for {
            xa      <- ZIO.service[Transactor[Task]]
            _       <- seedTestData(xa)
            _       <-
              (for {
                _ <-
                  sql"""INSERT INTO companies (id, name, email)
                                    VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                    ON CONFLICT DO NOTHING""".update.run
                _ <-
                  sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                                    VALUES (${UUID.fromString("00000002-0000-0000-0000-000000000003")},
                                            'Client 2', 'client2@test.com', 'client'::person_role,
                                            ${company2Id.value}, 'placeholder')
                                    ON CONFLICT DO NOTHING""".update.run
              } yield ()).transact(xa)
            _       <- cleanRides(xa)
            repo     = PostgresRideRepository(xa)
            now      = Instant.now()
            endTime  = now.minusSeconds(60)
            from     = now.minusSeconds(3600 * 24 * 7)
            to       = now.plusSeconds(3600)
            // Company 1: Completed ride worth 50
            _       <- repo.create(
                         makeRide(status = RideStatus.Completed).copy(
                           finalPrice = Some(BigDecimal("50.00")),
                           endTime = Some(endTime)
                         )
                       )
            // Company 2: Completed ride worth 75
            _       <- repo.create(
                         makeRide(status = RideStatus.Completed).copy(
                           companyId = company2Id,
                           clientId = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000003")),
                           finalPrice = Some(BigDecimal("75.00")),
                           endTime = Some(endTime)
                         )
                       )
            // Cancelled ride: must NOT count towards revenue
            _       <- repo.create(
                         makeRide(status = RideStatus.Cancelled).copy(
                           finalPrice = Some(BigDecimal("999.00")),
                           endTime = Some(endTime)
                         )
                       )
            revenue <- repo.sumAllRevenue(from, to)
          } yield assertTrue(
            // Revenue from both companies: 50 + 75 = 125; cancelled ride excluded
            revenue == BigDecimal("125.00")
          )
        },
        test("countRidesByCompany splits counts by company correctly") {
          val company2Id = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
          for {
            xa     <- ZIO.service[Transactor[Task]]
            _      <- seedTestData(xa)
            _      <-
              (for {
                _ <-
                  sql"""INSERT INTO companies (id, name, email)
                                 VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
                _ <-
                  sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                                 VALUES (${UUID.fromString("00000002-0000-0000-0000-000000000003")},
                                         'Client 2', 'client2@test.com', 'client'::person_role,
                                         ${company2Id.value}, 'placeholder')
                                 ON CONFLICT DO NOTHING""".update.run
              } yield ()).transact(xa)
            _      <- cleanRides(xa)
            repo    = PostgresRideRepository(xa)
            now     = Instant.now()
            from    = now.minusSeconds(3600 * 24 * 7)
            to      = now.plusSeconds(3600)
            reqTime = now.minusSeconds(3600)
            // Company 1: 2 rides
            _      <- repo.create(makeRide(status = RideStatus.Requested).copy(requestTime = reqTime))
            _      <- repo.create(makeRide(status = RideStatus.Completed).copy(requestTime = reqTime))
            // Company 2: 1 ride
            _      <- repo.create(
                        makeRide(status = RideStatus.Requested).copy(
                          companyId = company2Id,
                          clientId = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000003")),
                          requestTime = reqTime
                        )
                      )
            counts <- repo.countRidesByCompany(from, to)
          } yield assertTrue(
            // Company 1 has 2 rides; company 2 has 1 — both appear in the map
            counts.getOrElse(testCompanyId.value, 0) == 2,
            counts.getOrElse(company2Id.value, 0) == 1
          )
        },
        test("sumRevenueByCompanyPlatform splits revenue by company") {
          val company2Id = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
          for {
            xa      <- ZIO.service[Transactor[Task]]
            _       <- seedTestData(xa)
            _       <-
              (for {
                _ <-
                  sql"""INSERT INTO companies (id, name, email)
                                    VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                    ON CONFLICT DO NOTHING""".update.run
                _ <-
                  sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                                    VALUES (${UUID.fromString("00000002-0000-0000-0000-000000000003")},
                                            'Client 2', 'client2@test.com', 'client'::person_role,
                                            ${company2Id.value}, 'placeholder')
                                    ON CONFLICT DO NOTHING""".update.run
              } yield ()).transact(xa)
            _       <- cleanRides(xa)
            repo     = PostgresRideRepository(xa)
            now      = Instant.now()
            endTime  = now.minusSeconds(60)
            from     = now.minusSeconds(3600 * 24 * 7)
            to       = now.plusSeconds(3600)
            // Company 1: 100 EUR
            _       <- repo.create(
                         makeRide(status = RideStatus.Completed).copy(
                           finalPrice = Some(BigDecimal("100.00")),
                           endTime = Some(endTime)
                         )
                       )
            // Company 2: 200 EUR
            _       <- repo.create(
                         makeRide(status = RideStatus.Completed).copy(
                           companyId = company2Id,
                           clientId = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000003")),
                           finalPrice = Some(BigDecimal("200.00")),
                           endTime = Some(endTime)
                         )
                       )
            revenue <- repo.sumRevenueByCompanyPlatform(from, to)
          } yield assertTrue(
            // Each company's revenue appears separately in the map
            revenue.getOrElse(testCompanyId.value, BigDecimal("0")) == BigDecimal("100.00"),
            revenue.getOrElse(company2Id.value, BigDecimal("0")) == BigDecimal("200.00")
          )
        }
      )
      // ── HandedOff status and new directory-FK columns ─────────────────────────
      // V11 schema: ride_status enum extended with 'HandedOff'; rides table gains
      // external_driver_id and partner_company_id columns.
      // These tests assert that the PostgresRideRepository reads/writes the new fields correctly.
      ,
      test("HandedOff status round-trips through create and updateIfStatus") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          ride     = makeRide(status = RideStatus.Requested)
          _       <- repo.create(ride)
          found1  <- repo.findById(ride.id)
          // Atomically transition to HandedOff
          updated  = ride.copy(status = RideStatus.HandedOff)
          applied <- repo.updateIfStatus(updated, Set(RideStatus.Requested))
          found2  <- repo.findById(ride.id)
        } yield assertTrue(
          found1.isDefined,
          found1.get.status == RideStatus.Requested,
          applied,
          found2.isDefined,
          found2.get.status == RideStatus.HandedOff
        )
      },
      test("externalDriverId and partnerCompanyId round-trip through create and updateIfStatus") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanRides(xa)
          // Seed the required partner_companies and external_drivers rows (FK constraint).
          pcId     = PartnerCompanyId(UUID.fromString("00000090-0000-0000-0000-000000000001"))
          edId     = ExternalDriverId(UUID.fromString("00000091-0000-0000-0000-000000000001"))
          _       <-
            sql"""INSERT INTO partner_companies (id, name, taxi_company_id)
                   VALUES (${pcId.value}, 'Handoff Partner', ${testCompanyId.value})
                   ON CONFLICT DO NOTHING""".update.run.transact(xa)
          _       <-
            sql"""INSERT INTO external_drivers (id, name, taxi_company_id)
                   VALUES (${edId.value}, 'Handoff Driver', ${testCompanyId.value})
                   ON CONFLICT DO NOTHING""".update.run.transact(xa)
          repo     = PostgresRideRepository(xa)
          ride     = makeRide(status = RideStatus.Requested)
          _       <- repo.create(ride)
          // Transition to HandedOff and populate the new FK columns
          updated  = ride.copy(
                       status = RideStatus.HandedOff,
                       externalDriverId = Some(edId),
                       partnerCompanyId = Some(pcId)
                     )
          applied <- repo.updateIfStatus(updated, Set(RideStatus.Requested))
          found   <- repo.findById(ride.id)
        } yield assertTrue(
          applied,
          found.isDefined,
          found.get.status == RideStatus.HandedOff,
          found.get.externalDriverId.contains(edId),
          found.get.partnerCompanyId.contains(pcId)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
