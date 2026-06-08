package com.shevchyk.ride.domain

import java.time.Instant

/**
 * Aggregation period for driver earnings.
 */
enum EarningsPeriod:
  case Day, Week, Month

object EarningsPeriod:

  def fromString(s: String): Option[EarningsPeriod] =
    s.toLowerCase match
      case "day"   => Some(EarningsPeriod.Day)
      case "week"  => Some(EarningsPeriod.Week)
      case "month" => Some(EarningsPeriod.Month)
      case _       => None

/**
 * Raw driver ride aggregates for a period (excluding expenses).
 */
final case class DriverEarnings(
    grossRevenue: BigDecimal,
    completedRides: Int,
    cancelledRides: Int
)

/**
 * Chart point: bucket start (hour/day) and the revenue accumulated in it.
 */
final case class EarningsBucket(
    bucketStart: Instant,
    amount: BigDecimal
)

/**
 * Full driver earnings report for a period, ready to be mapped into a DTO.
 */
final case class DriverEarningsReport(
    period: EarningsPeriod,
    from: Instant,
    to: Instant,
    grossRevenue: BigDecimal,
    totalExpenses: BigDecimal,
    completedRides: Int,
    cancelledRides: Int,
    buckets: List[EarningsBucket]
):
  def netRevenue: BigDecimal = grossRevenue - totalExpenses
  def avgFare: BigDecimal    = if completedRides > 0 then grossRevenue / completedRides else BigDecimal(0)
