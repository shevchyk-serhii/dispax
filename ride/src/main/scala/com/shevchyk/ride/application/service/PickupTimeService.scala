package com.shevchyk.ride.application.service

import com.shevchyk.core.config.AirportPickupConfig
import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId, CompanySettings}
import com.shevchyk.core.repository.{ClientCompanyRepository, CompanySettingsRepository}
import com.shevchyk.ride.application.TravelTimeService
import zio.*

import java.time.Instant

/**
 * Result of a successful pickup-time computation for an airport departure ride.
 *
 * @param pickupDateTime
 *   The computed pickup instant (flightDeparture − checkInClose − travel − buffer).
 * @param travelMinutes
 *   Driving time in minutes used in the computation.
 * @param bufferMinutes
 *   Buffer minutes resolved from the hierarchy (client ?? company ?? global).
 * @param checkInClose
 *   Check-in-close minutes resolved from the hierarchy.
 * @param travelTimeFallback
 *   True when HERE was unavailable and Haversine was used instead.
 */
final case class PickupTimeResult(
    pickupDateTime: Instant,
    travelMinutes: Int,
    bufferMinutes: Int,
    checkInClose: Int,
    travelTimeFallback: Boolean
)

/**
 * Computes the automatic pickup time for airport departure rides.
 *
 * Formula: pickupDateTime = flightDeparture − checkInCloseMinutes − travelTimeMinutes − bufferMinutes
 *
 * The timing parameters resolve on a 3-level hierarchy: client (ClientCompany) ?? company (CompanySettings) ?? global
 * (AirportPickupConfig)
 *
 * Travel time is obtained from [[TravelTimeService]] (HERE-backed at the DI layer). When HERE returns [[None]] the
 * service falls back to Haversine so ride creation is never blocked.
 *
 * Tenant isolation: settings are loaded by `taxiCompanyId` (from the JWT claims). The `clientCompanyId`, when present,
 * is validated against the same `taxiCompanyId` before its timing overrides are applied — a client company from a
 * different tenant cannot influence the computation.
 */
trait PickupTimeService:

  def computePickupTime(
      taxiCompanyId: CompanyId,
      clientCompanyId: Option[ClientCompanyId],
      flightDeparture: Instant,
      fromLat: Double,
      fromLng: Double,
      toLat: Double,
      toLng: Double
  ): IO[PickupTimeService.Error, PickupTimeResult]

object PickupTimeService:

  enum Error:
    case SettingsLoadFailed(cause: Throwable)
    case MissingCoordinates

  /**
   * Pure resolution function: picks the buffer minutes from the hierarchy. Extracted to the companion object so unit
   * tests can invoke it directly.
   */
  def resolveBuffer(
      client: Option[ClientCompany],
      company: Option[CompanySettings],
      global: AirportPickupConfig
  ): Int = client
    .flatMap(_.airportBufferMinutes)
    .orElse(company.flatMap(_.airportBufferMinutes))
    .getOrElse(global.defaultBufferMinutes)

  /**
   * Pure resolution function: picks the check-in-close minutes from the hierarchy. Extracted to the companion object so
   * unit tests can invoke it directly.
   */
  def resolveCheckIn(
      client: Option[ClientCompany],
      company: Option[CompanySettings],
      global: AirportPickupConfig
  ): Int = client
    .flatMap(_.airportCheckInCloseMinutes)
    .orElse(company.flatMap(_.airportCheckInCloseMinutes))
    .getOrElse(global.defaultCheckInCloseMinutes)

  /**
   * Pure arithmetic: computes the pickup instant from the resolved parameters. Extracted to the companion object so
   * unit tests can assert the formula directly.
   */
  def computePickup(
      flightDeparture: Instant,
      checkInClose: Int,
      travelMin: Int,
      buffer: Int
  ): Instant = flightDeparture.minusSeconds((checkInClose.toLong + travelMin.toLong + buffer.toLong) * 60L)

  /**
   * Haversine-based fallback travel-time estimate: assumes 50 km/h average speed, result ceiled to a minimum of 1
   * minute.
   */
  def haversineTravelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Int =
    val km = RideEstimateService.haversineKm(fromLat, fromLng, toLat, toLng)
    Math.ceil(km / 50.0 * 60.0).toInt.max(1)

  final class Live(
      companySettingsRepo: CompanySettingsRepository,
      clientCompanyRepo: ClientCompanyRepository,
      travelTimeService: TravelTimeService,
      config: AirportPickupConfig
  ) extends PickupTimeService:

    def computePickupTime(
        taxiCompanyId: CompanyId,
        clientCompanyId: Option[ClientCompanyId],
        flightDeparture: Instant,
        fromLat: Double,
        fromLng: Double,
        toLat: Double,
        toLng: Double
    ): IO[Error, PickupTimeResult] =
      for {
        companySettings      <- companySettingsRepo
                                  .findByCompanyId(taxiCompanyId)
                                  .mapError(Error.SettingsLoadFailed.apply)
        // Tenant isolation: only apply client-company timing when the client company belongs
        // to the same taxi company as the JWT. Foreign client companies are silently ignored.
        clientCompany        <-
          clientCompanyId match
            case None     => ZIO.succeed(None)
            case Some(id) =>
              clientCompanyRepo
                .findById(id)
                .map(_.filter(_.taxiCompanyId == taxiCompanyId))
                .mapError(Error.SettingsLoadFailed.apply)
        buffer                = resolveBuffer(clientCompany, companySettings, config)
        checkIn               = resolveCheckIn(clientCompany, companySettings, config)
        hereResult           <- travelTimeService
                                  .travelMinutes(fromLat, fromLng, toLat, toLng)
                                  .mapError(Error.SettingsLoadFailed.apply)
        (travelMin, fallback) =
          hereResult match
            case Some(m) => (m, false)
            case None    => (haversineTravelMinutes(fromLat, fromLng, toLat, toLng), true)
        pickup                = computePickup(flightDeparture, checkIn, travelMin, buffer)
      } yield PickupTimeResult(
        pickupDateTime = pickup,
        travelMinutes = travelMin,
        bufferMinutes = buffer,
        checkInClose = checkIn,
        travelTimeFallback = fallback
      )

  val layer: ZLayer[
    CompanySettingsRepository & ClientCompanyRepository & TravelTimeService & AirportPickupConfig,
    Nothing,
    PickupTimeService
  ] = ZLayer.fromFunction(Live.apply)

  /**
   * No-op implementation for use in tests that do not exercise the pickup-time logic. Always returns a pickup time
   * equal to the flight departure minus 75 minutes (global defaults: 60+15).
   */
  val noopLayer: ZLayer[Any, Nothing, PickupTimeService] = ZLayer.succeed(
    new PickupTimeService:
      def computePickupTime(
          taxiCompanyId: CompanyId,
          clientCompanyId: Option[ClientCompanyId],
          flightDeparture: Instant,
          fromLat: Double,
          fromLng: Double,
          toLat: Double,
          toLng: Double
      ): IO[Error, PickupTimeResult] = ZIO.succeed(
        PickupTimeResult(
          pickupDateTime = flightDeparture.minusSeconds(75 * 60L),
          travelMinutes = 0,
          bufferMinutes = 15,
          checkInClose = 60,
          travelTimeFallback = false
        )
      )
  )
