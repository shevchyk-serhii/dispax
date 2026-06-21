package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*
import zio.test.*

import java.time.{Duration, Instant, LocalDate, ZoneOffset}
import java.util.UUID

/**
 * Unit coverage for the dashboard/earnings metrics implemented by RideRepository. These aggregation methods
 * (today-revenue, average assignment time, daily stats, unpaid-completed filtering) carried no test before — the
 * in-memory double reproduces the production SQL semantics, so exercising it here pins down the contract that
 * RideService relies on.
 *
 * Each test provides a fresh `InMemoryRideRepository.layer` (a new instance per `provide`), so seeded state never leaks
 * between cases.
 */
object RideRepositoryMetricsSpec extends ZIOSpecDefault {

  private val companyA = CompanyId(UUID.fromString("000000a0-0000-0000-0000-000000000001"))
  private val companyB = CompanyId(UUID.fromString("000000b0-0000-0000-0000-000000000002"))
  private val driver1  = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val client   = PersonId(UUID.fromString("00000003-0000-0000-0000-000000000003"))

  private val todayStart = LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant

  private def ride(
      company: CompanyId = companyA,
      status: RideStatus = RideStatus.Completed,
      driver: Option[PersonId] = Some(driver1),
      requestTime: Instant = Instant.now(),
      startTime: Option[Instant] = None,
      endTime: Option[Instant] = None,
      finalPrice: Option[BigDecimal] = None,
      estimatedPrice: Option[BigDecimal] = None,
      payment: PaymentStatus = PaymentStatus.Unpaid
  ): Ride = Ride(
    id = RideId.generate(),
    clientId = client,
    creatorId = client,
    companyId = company,
    driverId = driver,
    status = status,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B"),
    pickupDateTime = requestTime,
    requestTime = requestTime,
    startTime = startTime,
    endTime = endTime,
    finalPrice = finalPrice,
    estimatedPrice = estimatedPrice,
    paymentStatus = payment
  )

  private def seed(rs: Ride*): ZIO[RideRepository, Throwable, Unit] = ZIO.serviceWithZIO[RideRepository](repo =>
    ZIO.foreachDiscard(rs)(repo.create)
  )

  private val freshRepo = InMemoryRideRepository.layer

  def spec =
    suite("RideRepository metrics")(
      suite("sumTodayRevenueByCompany")(
        test("sums final/estimated price of today's Completed rides only") {
          (for {
            _   <- seed(
                     ride(endTime = Some(todayStart.plusSeconds(3600)), finalPrice = Some(BigDecimal("100.00"))),
                     ride(endTime = Some(todayStart.plusSeconds(7200)), estimatedPrice = Some(BigDecimal("50.00"))),
                     // ended yesterday → excluded
                     ride(endTime = Some(todayStart.minusSeconds(3600)), finalPrice = Some(BigDecimal("999.00"))),
                     // not completed → excluded
                     ride(
                       status = RideStatus.InProgress,
                       endTime = Some(todayStart),
                       finalPrice = Some(BigDecimal("7.00"))
                     )
                   )
            sum <- ZIO.serviceWithZIO[RideRepository](_.sumTodayRevenueByCompany(companyA))
          } yield assertTrue(sum == BigDecimal("150.00"))).provide(freshRepo)
        },
        test("prefers finalPrice over estimatedPrice and isolates by company") {
          (for {
            _   <- seed(
                     ride(
                       endTime = Some(todayStart),
                       finalPrice = Some(BigDecimal("80.00")),
                       estimatedPrice = Some(BigDecimal("999.00"))
                     ),
                     ride(company = companyB, endTime = Some(todayStart), finalPrice = Some(BigDecimal("500.00")))
                   )
            sum <- ZIO.serviceWithZIO[RideRepository](_.sumTodayRevenueByCompany(companyA))
          } yield assertTrue(sum == BigDecimal("80.00"))).provide(freshRepo)
        }
      ),
      suite("avgAssignmentMinutesByCompany")(
        test("averages requestTime→startTime over assigned rides") {
          val base = Instant.parse("2026-01-01T00:00:00Z")
          (for {
            _   <- seed(
                     ride(requestTime = base, startTime = Some(base.plus(Duration.ofMinutes(10)))),
                     ride(requestTime = base, startTime = Some(base.plus(Duration.ofMinutes(20)))),
                     // no driver/startTime → ignored
                     ride(driver = None, startTime = None)
                   )
            avg <- ZIO.serviceWithZIO[RideRepository](_.avgAssignmentMinutesByCompany(companyA))
          } yield assertTrue(avg == 15.0)).provide(freshRepo)
        },
        test("returns 0.0 when no assigned rides exist") {
          (for {
            _   <- seed(ride(driver = None, startTime = None))
            avg <- ZIO.serviceWithZIO[RideRepository](_.avgAssignmentMinutesByCompany(companyA))
          } yield assertTrue(avg == 0.0)).provide(freshRepo)
        }
      ),
      suite("countDailyStatsByCompany")(
        test("buckets rides per day with total/completed/cancelled counts") {
          val day = Instant.now().minusSeconds(86400) // 1 day ago, within a 7-day window
          // Distinct counts (2 completed, 1 cancelled, 1 requested) so that swapping the
          // completed/cancelled tallies would change the result — guards against a metric
          // that conflates the two statuses.
          (for {
            stats <-
              seed(
                ride(status = RideStatus.Completed, requestTime = day),
                ride(status = RideStatus.Completed, requestTime = day),
                ride(status = RideStatus.Cancelled, requestTime = day),
                ride(status = RideStatus.Requested, requestTime = day)
              ) *> ZIO.serviceWithZIO[RideRepository](_.countDailyStatsByCompany(companyA, 7))
          } yield {
            val (_, total, completed, cancelled) = stats.head
            assertTrue(stats.size == 1, total == 4, completed == 2, cancelled == 1)
          }).provide(freshRepo)
        },
        test("excludes rides older than the requested window") {
          val old = Instant.now().minusSeconds(86400L * 30)
          (for {
            stats <-
              seed(ride(requestTime = old)) *>
                ZIO.serviceWithZIO[RideRepository](_.countDailyStatsByCompany(companyA, 7))
          } yield assertTrue(stats.isEmpty)).provide(freshRepo)
        }
      )
    )
}
