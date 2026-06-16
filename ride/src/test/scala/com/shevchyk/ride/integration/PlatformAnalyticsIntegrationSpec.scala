package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{PostgresCompanyRepository, PostgresPersonRepository}
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
 * Integration test: cross-tenant (SuperAdmin) platform analytics.
 *
 * Seeds rides for TWO separate companies using the PostgresRideRepository and
 * CompanyRepository, then asserts that the platform-level aggregates
 * (`countAllRidesByStatus`, `sumAllRevenue`, `countRidesByCompany`,
 * `sumRevenueByCompanyPlatform`) see data across both tenants.
 *
 * Also verifies that `CompanyRepository.findAll` returns all seeded companies,
 * which is the data source for the SuperAdmin companies list.
 *
 * Rules:
 * - Real PostgreSQL via Testcontainers — the DB is never mocked (dev-flow.md invariant #4).
 * - No company_id filter in the platform-level repository calls (by design).
 * - Tests are sequential to avoid concurrency issues on shared test data.
 */
object PlatformAnalyticsIntegrationSpec extends ZIOSpecDefault:

  private val company1Id = CompanyId(UUID.fromString("a1a1a1a1-0000-0000-0000-000000000001"))
  private val company2Id = CompanyId(UUID.fromString("a2a2a2a2-0000-0000-0000-000000000002"))
  private val client1    = PersonId(UUID.fromString("c1c1c1c1-0000-0000-0000-000000000001"))
  private val client2    = PersonId(UUID.fromString("c2c2c2c2-0000-0000-0000-000000000002"))

  private def seedBaseData(xa: Transactor[Task]): Task[Unit] =
    (for {
      // Two isolated tenant companies — provide non-null phone/address because
      // Company.phone and Company.address are non-Option String and Doobie
      // throws NonNullableColumnRead on NULL columns mapped to String.
      _ <- sql"""INSERT INTO companies (id, name, email, phone, address)
                   VALUES (${company1Id.value}, 'Platform Test GmbH 1', 'pt1@platform-test.de',
                           '+49 89 111111', 'Teststraße 1, 80000 München')
                   ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO companies (id, name, email, phone, address)
                   VALUES (${company2Id.value}, 'Platform Test GmbH 2', 'pt2@platform-test.de',
                           '+49 89 222222', 'Teststraße 2, 80000 München')
                   ON CONFLICT DO NOTHING""".update.run
      // One client per company
      _ <- sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                   VALUES (${client1.value}, 'Test Client 1', 'c1@platform-test.de',
                           'client'::person_role, ${company1Id.value}, 'placeholder')
                   ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                   VALUES (${client2.value}, 'Test Client 2', 'c2@platform-test.de',
                           'client'::person_role, ${company2Id.value}, 'placeholder')
                   ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM rides WHERE company_id IN (${company1Id.value}, ${company2Id.value})"
      .update.run.transact(xa).unit

  private val now  = Instant.now()
  private val from = now.minusSeconds(3600L * 24 * 30)  // 30 days ago
  private val to   = now.plusSeconds(3600L)

  private def ride(
      companyId: CompanyId,
      clientId: PersonId,
      status: RideStatus,
      finalPrice: Option[BigDecimal] = None,
      endTime: Option[Instant] = None
  ): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    status = status,
    pickupLocation = Location("Hauptbahnhof"),
    dropoffLocation = Location("Flughafen"),
    pickupDateTime = now.minusSeconds(3600),
    requestTime = now.minusSeconds(7200),
    finalPrice = finalPrice,
    endTime = endTime
  )

  def spec =
    suite("PlatformAnalytics — cross-tenant integration (Testcontainers)")(

      test("CompanyRepository.findAll returns both seeded companies") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedBaseData(xa)
          repo    = PostgresCompanyRepository(xa)
          all    <- repo.findAll()
          ids     = all.map(_.id)
        } yield assertTrue(
          ids.contains(company1Id),
          ids.contains(company2Id),
          all.size >= 2
        )
      },

      test("countAllRidesByStatus aggregates across both companies") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedBaseData(xa)
          _        <- cleanRides(xa)
          repo      = PostgresRideRepository(xa)
          // Company 1: 2 Completed + 1 Requested
          _        <- repo.create(ride(company1Id, client1, RideStatus.Completed))
          _        <- repo.create(ride(company1Id, client1, RideStatus.Completed))
          _        <- repo.create(ride(company1Id, client1, RideStatus.Requested))
          // Company 2: 1 Completed + 1 Cancelled
          _        <- repo.create(ride(company2Id, client2, RideStatus.Completed))
          _        <- repo.create(ride(company2Id, client2, RideStatus.Cancelled))
          counts   <- repo.countAllRidesByStatus()
        } yield assertTrue(
          // 3 completed across both companies
          counts.getOrElse("Completed", 0) >= 3,
          // 1 requested
          counts.getOrElse("Requested", 0) >= 1,
          // 1 cancelled
          counts.getOrElse("Cancelled", 0) >= 1
        )
      },

      test("sumAllRevenue sums completed rides across both companies") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedBaseData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          endTime  = now.minusSeconds(600)
          // Company 1: completed ride with price 100
          _       <- repo.create(ride(company1Id, client1, RideStatus.Completed, Some(BigDecimal("100.00")), Some(endTime)))
          // Company 2: completed ride with price 200
          _       <- repo.create(ride(company2Id, client2, RideStatus.Completed, Some(BigDecimal("200.00")), Some(endTime)))
          // Cancelled ride must NOT count
          _       <- repo.create(ride(company1Id, client1, RideStatus.Cancelled, Some(BigDecimal("50.00")), Some(endTime)))
          revenue <- repo.sumAllRevenue(from, to)
        } yield assertTrue(
          revenue >= BigDecimal("300.00")
        )
      },

      test("countRidesByCompany groups ride counts by tenant") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedBaseData(xa)
          _        <- cleanRides(xa)
          repo      = PostgresRideRepository(xa)
          reqTime   = now.minusSeconds(3600)
          _        <- repo.create(ride(company1Id, client1, RideStatus.Requested).copy(requestTime = reqTime))
          _        <- repo.create(ride(company1Id, client1, RideStatus.Completed).copy(requestTime = reqTime))
          _        <- repo.create(ride(company2Id, client2, RideStatus.Requested).copy(requestTime = reqTime))
          counts   <- repo.countRidesByCompany(from, to)
        } yield assertTrue(
          counts.getOrElse(company1Id.value, 0) >= 2,
          counts.getOrElse(company2Id.value, 0) >= 1
        )
      },

      test("sumRevenueByCompanyPlatform splits revenue per tenant") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedBaseData(xa)
          _       <- cleanRides(xa)
          repo     = PostgresRideRepository(xa)
          endTime  = now.minusSeconds(600)
          _       <- repo.create(ride(company1Id, client1, RideStatus.Completed, Some(BigDecimal("150.00")), Some(endTime)))
          _       <- repo.create(ride(company2Id, client2, RideStatus.Completed, Some(BigDecimal("250.00")), Some(endTime)))
          revenue <- repo.sumRevenueByCompanyPlatform(from, to)
        } yield assertTrue(
          revenue.getOrElse(company1Id.value, BigDecimal("0")) >= BigDecimal("150.00"),
          revenue.getOrElse(company2Id.value, BigDecimal("0")) >= BigDecimal("250.00")
        )
      }

    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")
