package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresExpenseRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Integration tests for PostgresExpenseRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresExpenseRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000010-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000010-0000-0000-0000-000000000002"))
  val driverId       = PersonId(UUID.fromString("00000011-0000-0000-0000-000000000001"))
  val otherDriverId  = PersonId(UUID.fromString("00000011-0000-0000-0000-000000000002"))
  val clientId       = PersonId(UUID.fromString("00000011-0000-0000-0000-000000000003"))
  val rideId         = RideId(UUID.fromString("00000012-0000-0000-0000-000000000001"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'exp-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'exp-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Exp Driver', 'exp-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherDriverId.value}, 'Other Driver', 'exp-driver2@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Exp Client', 'exp-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO rides (id, client_id, creator_id, company_id, status,
                 from_address, to_address, pickup_datetime, request_time)
                 VALUES (${rideId.value}, ${clientId.value}, ${clientId.value}, ${testCompanyId.value}, 'Requested',
                 'A', 'B', NOW(), NOW())
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanExpenses(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM expenses".update.run.transact(xa).unit

  private def makeExpense(
      id: ExpenseId = ExpenseId.generate(),
      driver: PersonId = driverId,
      company: CompanyId = testCompanyId,
      ride: Option[RideId] = Some(rideId),
      category: ExpenseCategory = ExpenseCategory.Fuel,
      amount: BigDecimal = BigDecimal("12.50"),
      createdAt: Instant = Instant.now().truncatedTo(ChronoUnit.MICROS)
  ): Expense = Expense(
    id = id,
    rideId = ride,
    driverId = driver,
    companyId = company,
    category = category,
    amount = amount,
    currency = "EUR",
    description = Some("test expense"),
    receiptUrl = Some("https://example.com/r.png"),
    createdAt = createdAt,
    updatedAt = createdAt
  )

  def spec =
    suite("PostgresExpenseRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanExpenses(xa)
          repo   = PostgresExpenseRepository(xa)
          exp    = makeExpense()
          _     <- repo.create(exp)
          found <- repo.findById(exp.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == exp.id,
          found.get.driverId == driverId,
          found.get.companyId == testCompanyId,
          found.get.rideId.contains(rideId),
          found.get.category == ExpenseCategory.Fuel,
          found.get.amount == BigDecimal("12.50"),
          found.get.currency == "EUR",
          found.get.description.contains("test expense"),
          found.get.receiptUrl.contains("https://example.com/r.png")
        )
      },
      test("create with no ride (rideId = None)") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanExpenses(xa)
          repo   = PostgresExpenseRepository(xa)
          exp    = makeExpense(ride = None, category = ExpenseCategory.Parking)
          _     <- repo.create(exp)
          found <- repo.findById(exp.id)
        } yield assertTrue(
          found.isDefined,
          found.get.rideId.isEmpty,
          found.get.category == ExpenseCategory.Parking
        )
      },
      test("findByDriverId filters by driver") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanExpenses(xa)
          repo   = PostgresExpenseRepository(xa)
          _     <- repo.create(makeExpense(driver = driverId))
          _     <- repo.create(makeExpense(driver = driverId))
          _     <- repo.create(makeExpense(driver = otherDriverId))
          mine  <- repo.findByDriverId(driverId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.driverId == driverId)
        )
      },
      test("findByRideId filters by ride") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanExpenses(xa)
          repo   = PostgresExpenseRepository(xa)
          _     <- repo.create(makeExpense(ride = Some(rideId)))
          _     <- repo.create(makeExpense(ride = None))
          byRide <- repo.findByRideId(rideId)
        } yield assertTrue(
          byRide.length == 1,
          byRide.head.rideId.contains(rideId)
        )
      },
      test("findByCompanyId isolates by company") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanExpenses(xa)
          repo   = PostgresExpenseRepository(xa)
          _     <- repo.create(makeExpense(company = testCompanyId, ride = None))
          _     <- repo.create(makeExpense(company = otherCompanyId, ride = None))
          mine  <- repo.findByCompanyId(testCompanyId)
          other <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.length == 1,
          mine.forall(_.companyId == testCompanyId),
          other.length == 1
        )
      },
      test("delete removes expense") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanExpenses(xa)
          repo     = PostgresExpenseRepository(xa)
          exp      = makeExpense(ride = None)
          _       <- repo.create(exp)
          deleted <- repo.delete(exp.id)
          missing <- repo.delete(ExpenseId.generate())
          found   <- repo.findById(exp.id)
        } yield assertTrue(deleted, !missing, found.isEmpty)
      },
      test("sumByDriver sums amounts within date range and isolates driver/company") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanExpenses(xa)
          repo  = PostgresExpenseRepository(xa)
          base  = Instant.parse("2026-03-15T12:00:00Z")
          // in-range for driver+company
          _    <- repo.create(makeExpense(ride = None, amount = BigDecimal("10.00"), createdAt = base))
          _    <- repo.create(makeExpense(ride = None, amount = BigDecimal("5.50"), createdAt = base.plusSeconds(3600)))
          // out of range (before)
          _    <- repo.create(makeExpense(ride = None, amount = BigDecimal("99.00"), createdAt = base.minus(40, ChronoUnit.DAYS)))
          // different driver, same company, in range -> excluded
          _    <- repo.create(makeExpense(ride = None, driver = otherDriverId, amount = BigDecimal("77.00"), createdAt = base))
          // same driver, different company, in range -> excluded
          _    <- repo.create(makeExpense(ride = None, company = otherCompanyId, amount = BigDecimal("33.00"), createdAt = base))
          from  = Instant.parse("2026-03-01T00:00:00Z")
          to    = Instant.parse("2026-04-01T00:00:00Z")
          sum  <- repo.sumByDriver(driverId, testCompanyId, from, to)
          empty <- repo.sumByDriver(driverId, testCompanyId, Instant.parse("2030-01-01T00:00:00Z"), Instant.parse("2030-02-01T00:00:00Z"))
        } yield assertTrue(
          sum == BigDecimal("15.50"),
          empty == BigDecimal(0)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
