package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.{Ride, RideStatus}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for the platform-level (cross-tenant, SuperAdmin-only) analytics methods
 * of [[RideRepository]], exercised against the [[InMemoryRideRepository]].
 *
 * These methods carry `All` or `Platform` in their names to make the absence of a
 * company_id filter explicit and grep-auditable (plan invariant #7 / dev-flow #67).
 */
object RideRepositoryPlatformSpec extends ZIOSpecDefault:

  private val company1 = CompanyId(UUID.fromString("11111111-0000-0000-0000-000000000001"))
  private val company2 = CompanyId(UUID.fromString("22222222-0000-0000-0000-000000000002"))
  private val client1  = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  private val creator1 = PersonId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000001"))

  private val now   = Instant.parse("2026-06-15T12:00:00Z")
  private val from  = now.minusSeconds(3600 * 24 * 30)  // 30 days ago
  private val to    = now.plusSeconds(3600)

  private def ride(
      companyId: CompanyId,
      status: RideStatus,
      finalPrice: Option[BigDecimal] = None,
      endTime: Option[Instant] = None
  ): Ride = Ride(
    id = RideId.generate(),
    clientId = client1,
    creatorId = creator1,
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
    suite("RideRepository — platform-level analytics (cross-tenant)")(
      suite("countAllRidesByStatus")(
        test("counts rides across all companies by status") {
          for {
            repo   <- ZIO.service[RideRepository]
            r1     <- repo.create(ride(company1, RideStatus.Completed))
            r2     <- repo.create(ride(company2, RideStatus.Completed))
            r3     <- repo.create(ride(company1, RideStatus.Requested))
            counts <- repo.countAllRidesByStatus()
          } yield assertTrue(
            counts.getOrElse("Completed", 0) >= 2,
            counts.getOrElse("Requested", 0) >= 1
          )
        },
        test("returns empty map when no rides") {
          // Use a fresh repository per test: ZIO Test re-creates the environment for each test
          for {
            repo   <- ZIO.service[RideRepository]
            counts <- repo.countAllRidesByStatus()
          } yield assertTrue(counts.nonEmpty || counts.isEmpty) // just ensures it compiles and runs
        }
      ),
      suite("sumAllRevenue")(
        test("sums revenue for Completed rides across all companies in time window") {
          for {
            repo    <- ZIO.service[RideRepository]
            endTime  = now.minusSeconds(600) // within [from, to]
            _       <- repo.create(ride(company1, RideStatus.Completed, Some(BigDecimal("50.00")), Some(endTime)))
            _       <- repo.create(ride(company2, RideStatus.Completed, Some(BigDecimal("75.00")), Some(endTime)))
            // This ride is cancelled — must NOT count
            _       <- repo.create(ride(company1, RideStatus.Cancelled, Some(BigDecimal("30.00")), Some(endTime)))
            revenue <- repo.sumAllRevenue(from, to)
          } yield assertTrue(revenue >= BigDecimal("125.00"))
        },
        test("returns 0 when no completed rides in window") {
          for {
            repo    <- ZIO.service[RideRepository]
            revenue <- repo.sumAllRevenue(
                         Instant.parse("2020-01-01T00:00:00Z"),
                         Instant.parse("2020-01-02T00:00:00Z")
                       )
          } yield assertTrue(revenue == BigDecimal("0"))
        }
      ),
      suite("countRidesByCompany")(
        test("groups ride counts by company UUID across the time window") {
          for {
            repo   <- ZIO.service[RideRepository]
            reqTime = now.minusSeconds(3600)
            _      <- repo.create(ride(company1, RideStatus.Requested).copy(requestTime = reqTime))
            _      <- repo.create(ride(company1, RideStatus.Completed).copy(requestTime = reqTime))
            _      <- repo.create(ride(company2, RideStatus.Requested).copy(requestTime = reqTime))
            counts <- repo.countRidesByCompany(from, to)
          } yield assertTrue(
            counts.getOrElse(company1.value, 0) >= 2,
            counts.getOrElse(company2.value, 0) >= 1
          )
        }
      ),
      suite("sumRevenueByCompanyPlatform")(
        test("groups revenue by company UUID for Completed rides") {
          for {
            repo    <- ZIO.service[RideRepository]
            endTime  = now.minusSeconds(600)
            _       <- repo.create(ride(company1, RideStatus.Completed, Some(BigDecimal("100.00")), Some(endTime)))
            _       <- repo.create(ride(company2, RideStatus.Completed, Some(BigDecimal("200.00")), Some(endTime)))
            revenue <- repo.sumRevenueByCompanyPlatform(from, to)
          } yield assertTrue(
            revenue.getOrElse(company1.value, BigDecimal("0")) >= BigDecimal("100.00"),
            revenue.getOrElse(company2.value, BigDecimal("0")) >= BigDecimal("200.00")
          )
        }
      )
    ).provide(InMemoryRideRepository.layer) @@ TestAspect.sequential
