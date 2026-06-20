package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.{CompanyId, Location}
import com.shevchyk.ride.domain.{CompanyTariff, VehicleClass}
import com.shevchyk.ride.repository.TariffRepository
import zio.*

import java.time.{Instant, LocalTime, ZoneId}

/**
 * Result of a fare estimate: straight-line distance, an estimated duration, the computed price and its currency.
 */
final case class RideEstimate(
    distanceKm: BigDecimal,
    durationMinutes: Int,
    estimatedPrice: BigDecimal,
    currency: String
)

/**
 * Application-layer fare estimation. Kept out of the route handler so the distance/duration/tariff logic is unit
 * testable and reusable.
 *
 * Distance is the Haversine great-circle distance (the `ride` module cannot depend on the HERE routing service, which
 * lives in the sibling `driver` module); duration assumes a 50 km/h average urban speed.
 */
trait RideEstimateService:

  def estimate(
      companyId: CompanyId,
      from: Location,
      to: Location,
      vehicleClass: VehicleClass,
      isAirportTransfer: Boolean,
      pickupTime: Option[Instant]
  ): IO[RideEstimateService.EstimateError, RideEstimate]

object RideEstimateService:

  /**
   * Average urban speed used to derive a duration from the straight-line distance.
   */
  val AvgSpeedKmh: Double = 50.0

  /**
   * Munich (Europe/Berlin) night window for the night surcharge: 22:00 (inclusive) – 06:00 (exclusive).
   */
  private val Zone: ZoneId          = ZoneId.of("Europe/Berlin")
  private val NightStart: LocalTime = LocalTime.of(22, 0)
  private val NightEnd: LocalTime   = LocalTime.of(6, 0)

  enum EstimateError:
    case MissingCoordinates(field: String)
    case TariffLoadFailed(cause: Throwable)

  /**
   * True when `instant` falls in the night window in the Europe/Berlin zone.
   */
  def isNight(instant: Instant): Boolean =
    val t = instant.atZone(Zone).toLocalTime
    !t.isBefore(NightStart) || t.isBefore(NightEnd)

  /**
   * Haversine great-circle distance in kilometres between two WGS-84 coordinates.
   */
  def haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double =
    val r    = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    r * c

  final class Live(tariffRepository: TariffRepository) extends RideEstimateService:

    def estimate(
        companyId: CompanyId,
        from: Location,
        to: Location,
        vehicleClass: VehicleClass,
        isAirportTransfer: Boolean,
        pickupTime: Option[Instant]
    ): IO[EstimateError, RideEstimate] =
      for
        fromLat   <- ZIO.fromOption(from.latitude).orElseFail(EstimateError.MissingCoordinates("from.latitude"))
        fromLng   <- ZIO.fromOption(from.longitude).orElseFail(EstimateError.MissingCoordinates("from.longitude"))
        toLat     <- ZIO.fromOption(to.latitude).orElseFail(EstimateError.MissingCoordinates("to.latitude"))
        toLng     <- ZIO.fromOption(to.longitude).orElseFail(EstimateError.MissingCoordinates("to.longitude"))
        distanceKm = haversineKm(fromLat, fromLng, toLat, toLng)
        duration   = Math.ceil(distanceKm / AvgSpeedKmh * 60.0).toInt.max(1)
        tariff    <- tariffRepository
                       .findByCompanyId(companyId)
                       .map(_.getOrElse(CompanyTariff.default(companyId)))
                       .mapError(EstimateError.TariffLoadFailed.apply)
        night      = pickupTime.exists(isNight)
        price      = tariff.estimate(distanceKm, isAirportTransfer, vehicleClass, night)
      yield RideEstimate(
        distanceKm = BigDecimal(distanceKm).setScale(2, BigDecimal.RoundingMode.HALF_UP),
        durationMinutes = duration,
        estimatedPrice = price,
        currency = tariff.currency
      )

  val live: ZLayer[TariffRepository, Nothing, RideEstimateService] = ZLayer.fromFunction(Live(_))
