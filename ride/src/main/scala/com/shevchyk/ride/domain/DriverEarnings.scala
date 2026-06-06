package com.shevchyk.ride.domain

import java.time.Instant

/**
 * Период агрегации заработка водителя.
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
 * Сырые агрегаты поездок водителя за период (без расходов).
 */
final case class DriverEarnings(
    grossRevenue: BigDecimal,
    completedRides: Int,
    cancelledRides: Int
)

/**
 * Точка графика: начало бакета (час/день) и сумма дохода в нём.
 */
final case class EarningsBucket(
    bucketStart: Instant,
    amount: BigDecimal
)

/**
 * Полный отчёт о заработке водителя за период, готовый к отдаче в DTO.
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
