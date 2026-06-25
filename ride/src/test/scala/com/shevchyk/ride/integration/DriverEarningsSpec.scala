package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{PostgresExpenseRepository, PostgresRideRepository, TimeBucket}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.{Instant, LocalDate, ZoneOffset}
import java.util.UUID

/**
 * Integration tests for driver earnings aggregation against a real PostgreSQL via Testcontainers. Focus: company/driver
 * isolation and period boundaries.
 */
object DriverEarningsSpec extends ZIOSpecDefault {

  private val companyA = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000a1"))
  private val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000b1"))

  private val clientId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  private val driverA   = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000a2"))
  private val driverB   = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000b2")) // same company A
  private val driverC   = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000c2")) // company B
  private val clientIdB = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000b9"))

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
                 VALUES (${clientId.value}, 'Client A', 'clientA@test.com', 'client'::person_role, ${companyA.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientIdB.value}, 'Client B', 'clientB@test.com', 'client'::person_role, ${companyB.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverA.value}, 'Driver A', 'driverA@test.com', 'driver'::person_role, ${companyA.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverB.value}, 'Driver B', 'driverB@test.com', 'driver'::person_role, ${companyA.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverC.value}, 'Driver C', 'driverC@test.com', 'driver'::person_role, ${companyB.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM expenses".update.run
      _ <- sql"DELETE FROM rides".update.run
    } yield ()).transact(xa)

  /**
   * A completed ride for the given driver/company priced at `price`, ended at `endAt`.
   */
  private def completedRide(
      driver: PersonId,
      company: CompanyId,
      client: PersonId,
      price: BigDecimal,
      endAt: Instant
  ): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = company,
    driverId = Some(driver),
    status = RideStatus.Completed,
    pickupLocation = Location("From", Some(48.1), Some(11.5)),
    dropoffLocation = Location("To", Some(48.2), Some(11.6)),
    pickupDateTime = endAt.minusSeconds(1800),
    requestTime = endAt.minusSeconds(3600),
    endTime = Some(endAt),
    finalPrice = Some(price)
  )

  private def makeExpense(driver: PersonId, company: CompanyId, amount: BigDecimal, at: Instant): Expense = Expense(
    id = ExpenseId(UUID.randomUUID()),
    driverId = driver,
    companyId = company,
    category = ExpenseCategory.Fuel,
    amount = amount,
    createdAt = at,
    updatedAt = at
  )

  // Anchor: a fixed week (Mon 2026-06-01 .. Sun 2026-06-07)
  private val weekFrom = LocalDate.of(2026, 6, 1).atStartOfDay(ZoneOffset.UTC).toInstant
  private val weekTo   = LocalDate.of(2026, 6, 8).atStartOfDay(ZoneOffset.UTC).toInstant
  private val midWeek  = LocalDate.of(2026, 6, 3).atTime(12, 0).toInstant(ZoneOffset.UTC)

  def spec =
    suite("DriverEarnings")(
      test("earningsByDriver isolates by driver AND company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          repo    = PostgresRideRepository(xa)
          // driver A, company A: two completed = 50 + 75
          _      <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(50), midWeek))
          _      <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(75), midWeek))
          // driver B same company — must NOT count for driver A
          _      <- repo.create(completedRide(driverB, companyA, clientId, BigDecimal(999), midWeek))
          // driver C other company — must NOT count for driver A
          _      <- repo.create(completedRide(driverC, companyB, clientIdB, BigDecimal(999), midWeek))
          earn   <- repo.earningsByDriver(driverA, companyA, weekFrom, weekTo)
          // same driver id but wrong company must yield zero (cross-tenant guard)
          earnXt <- repo.earningsByDriver(driverA, companyB, weekFrom, weekTo)
        } yield assertTrue(
          earn.grossRevenue == BigDecimal(125),
          earn.completedRides == 2,
          earnXt.grossRevenue == BigDecimal(0),
          earnXt.completedRides == 0
        )
      },
      test("earningsByDriver counts cancelled separately and excludes them from revenue") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedTestData(xa)
          _        <- cleanData(xa)
          repo      = PostgresRideRepository(xa)
          _        <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(60), midWeek))
          cancelled = completedRide(driverA, companyA, clientId, BigDecimal(40), midWeek)
                        .copy(status = RideStatus.Cancelled)
          _        <- repo.create(cancelled)
          earn     <- repo.earningsByDriver(driverA, companyA, weekFrom, weekTo)
        } yield assertTrue(
          earn.grossRevenue == BigDecimal(60),
          earn.completedRides == 1,
          earn.cancelledRides == 1
        )
      },
      test("period boundary: ride before window is excluded, on lower bound is included") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- cleanData(xa)
          repo       = PostgresRideRepository(xa)
          justBefore = weekFrom.minusSeconds(1)
          onBound    = weekFrom // [from, to) — inclusive lower
          _         <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(10), justBefore))
          _         <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(20), onBound))
          earn      <- repo.earningsByDriver(driverA, companyA, weekFrom, weekTo)
        } yield assertTrue(
          earn.grossRevenue == BigDecimal(20),
          earn.completedRides == 1
        )
      },
      test("sumByDriver isolates expenses by driver and company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          expRepo = PostgresExpenseRepository(xa)
          _      <- expRepo.create(makeExpense(driverA, companyA, BigDecimal(30), midWeek))
          _      <- expRepo.create(makeExpense(driverA, companyA, BigDecimal(20), midWeek))
          _      <- expRepo.create(makeExpense(driverB, companyA, BigDecimal(999), midWeek))                // other driver
          _      <- expRepo.create(makeExpense(driverA, companyA, BigDecimal(5), weekFrom.minusSeconds(1))) // before window
          sum    <- expRepo.sumByDriver(driverA, companyA, weekFrom, weekTo)
        } yield assertTrue(sum == BigDecimal(50))
      },
      test("earningsBucketsByDriver groups completed rides by day") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanData(xa)
          repo     = PostgresRideRepository(xa)
          day1     = LocalDate.of(2026, 6, 2).atTime(10, 0).toInstant(ZoneOffset.UTC)
          day2     = LocalDate.of(2026, 6, 4).atTime(15, 0).toInstant(ZoneOffset.UTC)
          _       <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(10), day1))
          _       <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(15), day1))
          _       <- repo.create(completedRide(driverA, companyA, clientId, BigDecimal(20), day2))
          buckets <- repo.earningsBucketsByDriver(driverA, companyA, weekFrom, weekTo, TimeBucket.Day)
        } yield assertTrue(
          buckets.length == 2,
          buckets.map(_._2).sum == BigDecimal(45)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
