package com.shevchyk.ride.domain

import zio.test.*
import java.time.Instant

/**
 * Pure-domain unit tests for earnings derived values and period parsing — no DB.
 */
object DriverEarningsReportSpec extends ZIOSpecDefault {

  private def report(
      gross: BigDecimal,
      expenses: BigDecimal,
      completed: Int,
      cancelled: Int = 0
  ): DriverEarningsReport = DriverEarningsReport(
    period = EarningsPeriod.Week,
    from = Instant.EPOCH,
    to = Instant.EPOCH,
    grossRevenue = gross,
    totalExpenses = expenses,
    completedRides = completed,
    cancelledRides = cancelled,
    buckets = Nil
  )

  def spec =
    suite("DriverEarningsReport")(
      suite("netRevenue")(
        test("subtracts expenses from gross") {
          assertTrue(report(BigDecimal(100), BigDecimal(30), 2).netRevenue == BigDecimal(70))
        },
        test("can be negative when expenses exceed gross") {
          assertTrue(report(BigDecimal(20), BigDecimal(50), 1).netRevenue == BigDecimal(-30))
        },
        test("equals gross when there are no expenses") {
          assertTrue(report(BigDecimal(80), BigDecimal(0), 1).netRevenue == BigDecimal(80))
        }
      ),
      suite("avgFare")(
        test("is gross divided by completed rides") {
          assertTrue(report(BigDecimal(100), BigDecimal(0), 4).avgFare == BigDecimal(25))
        },
        test("returns 0 when there are no completed rides (no division by zero)") {
          assertTrue(report(BigDecimal(0), BigDecimal(0), 0).avgFare == BigDecimal(0))
        },
        test("returns 0 even if gross is non-zero but completed is 0") {
          // Defensive: gross without completed rides must not divide by zero.
          assertTrue(report(BigDecimal(50), BigDecimal(0), 0).avgFare == BigDecimal(0))
        }
      ),
      suite("EarningsPeriod.fromString")(
        test("parses canonical lowercase values") {
          assertTrue(
            EarningsPeriod.fromString("day").contains(EarningsPeriod.Day),
            EarningsPeriod.fromString("week").contains(EarningsPeriod.Week),
            EarningsPeriod.fromString("month").contains(EarningsPeriod.Month)
          )
        },
        test("is case-insensitive") {
          assertTrue(
            EarningsPeriod.fromString("DAY").contains(EarningsPeriod.Day),
            EarningsPeriod.fromString("Week").contains(EarningsPeriod.Week),
            EarningsPeriod.fromString("MONTH").contains(EarningsPeriod.Month)
          )
        },
        test("returns None for unknown or empty input") {
          assertTrue(
            EarningsPeriod.fromString("year").isEmpty,
            EarningsPeriod.fromString("").isEmpty,
            EarningsPeriod.fromString("d ay").isEmpty
          )
        }
      )
    )
}
