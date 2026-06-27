package com.shevchyk.ride.application.service

import com.shevchyk.core.config.{AirportArrivalTimingConfig, AirportPickupConfig}
import com.shevchyk.core.domain.{CompanyId, DriverLocationProvider, RideId}
import com.shevchyk.ride.application.TravelTimeService
import com.shevchyk.ride.domain.{FlightStatusRow, Ride, RideError, RideSpecifics}
import zio.*

import java.time.temporal.ChronoUnit
import java.time.Instant

/**
 * Result of a successful terminal-entry timing computation for an airport arrival ride.
 *
 * @param optimalEntryTime
 *   The recommended instant to enter the terminal parking: `(arrival + walkBuffer) − freeWindow`. Entering at this
 *   moment keeps the driver within the free-parking window while the passenger is on the way out.
 * @param latestEntryTime
 *   The latest instant to enter without making the passenger wait: `arrival + walkBuffer` (passenger at curbside).
 * @param travelMinutes
 *   Driving time in minutes from the driver's current position to the terminal.
 * @param walkBufferMinutes
 *   Resolved walk-out buffer (normal vs satellite terminal).
 * @param flightStatus
 *   Human-readable flight status (today always "On time"; the flight-status integration will supply the real value).
 * @param actualArrivalTime
 *   The arrival instant used in the computation, surfaced for the UI.
 * @param timeToDepartMinutes
 *   Signed minutes until the driver should leave for the terminal (`optimalEntry − travel − now`). `≤ 0` ⇒ depart now.
 * @param travelTimeFallback
 *   True when routing was unavailable and the Haversine estimate was used instead.
 */
final case class AirportTimingResult(
    optimalEntryTime: Instant,
    latestEntryTime: Instant,
    travelMinutes: Int,
    walkBufferMinutes: Int,
    optimalParkingCost: Double,
    earlyEntryParkingCost: Double,
    savings: Double,
    flightStatus: String,
    actualArrivalTime: Instant,
    timeToDepartMinutes: Int,
    travelTimeFallback: Boolean
)

/**
 * Computes the recommended terminal-entry time for airport rides. Behaviour depends on the flight direction:
 *
 *   - ARRIVAL (the driver's terminal-parking saver): pull the entry time FORWARD from the flight arrival, so the driver
 *     enters the (paid) parking late enough to use the free window but early enough that the passenger does not wait.
 *     {{{
 *       passengerAtCurbside = arrivalTime + walkBuffer
 *       latestEntryTime     = passengerAtCurbside
 *       optimalEntryTime    = passengerAtCurbside − freeWindow
 *     }}}
 *   - DEPARTURE (the client's "don't miss the flight" reminder, served to the client card): the "be at the airport by"
 *     instant, pulled BACK from the flight departure by the airline check-in-close + safety margin.
 *     {{{
 *       latestEntryTime  = flightDeparture − checkInCloseMargin
 *       optimalEntryTime = latestEntryTime
 *     }}}
 *
 * In both cases `optimalEntryTime` is the travel-free target instant and `timeToDepart = minutesBetween(now,
 * optimalEntryTime − travelTime)` subtracts the drive exactly once (`≤ 0` ⇒ depart now).
 *
 * Travel time is obtained from [[TravelTimeService]] (HERE-backed at the DI layer). When routing returns [[None]] the
 * service falls back to Haversine so the card is never blocked. The driver's live position comes from
 * [[DriverLocationProvider]]; when it is unavailable the caller-supplied fallback coordinates (the driver's GPS POSTed
 * by the app) are used for the travel estimate only — never for authorization.
 *
 * Tenant isolation: the ride is loaded by id and its `companyId` is checked against the caller's JWT company. A ride
 * from another tenant is reported as [[AirportTimingService.Error.NotFound]] (→ 404) so existence is not leaked.
 *
 * Flight-time / terminal seam: today the flight time falls back to `ride.scheduledTime` and the terminal is unknown (so
 * the normal walk buffer applies). The future flight-status integration plugs the real estimated time and terminal code
 * into [[AirportTimingService.estimatedFlightTime]] — that single function is the only place to change.
 */
trait AirportTimingService:

  def compute(
      rideId: RideId,
      callerCompanyId: CompanyId,
      fallbackCoords: Option[(Double, Double)]
  ): IO[AirportTimingService.Error, AirportTimingResult]

object AirportTimingService:

  enum Error:
    case NotFound
    case NotAnAirportTransfer
    case SettingsLoadFailed(cause: Throwable)

  /**
   * Estimated flight time (arrival for arrival rides, departure for departure rides) and terminal code for the ride.
   * This is the single seam where the flight-status integration plugs in.
   *
   * The live `flightStatus` row (gate/terminal/status/time) is kept fresh by the flight-status monitor and supplies the
   * real terminal code, which drives the walk-out buffer (satellite terminals such as MUC K/T2K need the longer walk).
   * When no flight data has been recorded yet the terminal is unknown (→ normal buffer).
   *
   *   - Flight time: falls back to `ride.scheduledTime` (or now + 2h as a last resort) — the estimated-time integration
   *     still plugs in here later.
   *   - Status: "On time" for now.
   *
   * @return
   *   (flightTime, terminalCode, flightStatus)
   */
  def estimatedFlightTime(
      ride: Ride,
      flightStatus: Option[FlightStatusRow],
      now: Instant
  ): (Instant, Option[String], String) =
    val flightTime   = ride.scheduledTime.getOrElse(now.plus(2, ChronoUnit.HOURS))
    // Terminal comes from the live flight-status row (RideSpecifics.AirportTransfer itself carries only
    // airportCode/flightNumber/isArrival). Unknown terminal → normal buffer via walkBuffer.
    val terminalCode = flightStatus.flatMap(_.terminal).filter(_.trim.nonEmpty)
    (flightTime, terminalCode, "On time")

  /**
   * Pure resolution: the walk-out buffer for the (possibly unknown) terminal. A satellite terminal needs the longer
   * buffer; an unknown terminal defaults to the normal buffer.
   */
  def walkBuffer(terminalCode: Option[String], config: AirportArrivalTimingConfig): Int =
    val isSatellite = terminalCode.exists(t => config.satelliteTerminalCodes.contains(t.trim.toUpperCase))
    if isSatellite then config.satelliteWalkMinutes else config.normalWalkMinutes

  /**
   * Pure arithmetic: latest entry instant = arrival + walk buffer (passenger at curbside).
   */
  def computeLatestEntry(arrival: Instant, walkBufferMin: Int): Instant = arrival.plusSeconds(
    walkBufferMin.toLong * 60L
  )

  /**
   * Pure arithmetic: optimal entry instant = latest entry − free-parking window.
   */
  def computeOptimalEntry(latestEntry: Instant, freeWindowMin: Int): Instant = latestEntry.minusSeconds(
    freeWindowMin.toLong * 60L
  )

  /**
   * Pure, GPS-free recommended terminal-entry instant ("Einfahrt um") for an airport arrival ride, for list contexts
   * (driver "Today" / dispatcher "My Rides" cards) where there is no driver position and so no travel time. This is the
   * same `(arrival + walkBuffer) − freeWindow` the live [[compute]] uses, minus the travel-aware "depart now" part.
   *
   * The arrival instant is taken from the live flight time when the monitor has fetched one, else the booking's
   * scheduled time. Returns [[None]] when no arrival time is known (so the card simply omits the line) — never the `now
   * + 2h` placeholder the live path uses, which would be wrong for a static list.
   *
   * @param arrivalTime
   *   the flight arrival instant (`flight.flightTime` or `ride.scheduledTime`), if known
   * @param terminalCode
   *   the live terminal code (drives the satellite vs normal walk buffer), if known
   */
  def arrivalOptimalEntry(
      arrivalTime: Option[Instant],
      terminalCode: Option[String],
      config: AirportArrivalTimingConfig
  ): Option[Instant] = arrivalTime.map { arrival =>
    val latest = computeLatestEntry(arrival, walkBuffer(terminalCode, config))
    computeOptimalEntry(latest, config.freeParkingMinutes)
  }

  /**
   * Pure arithmetic: signed minutes until departure = (optimalEntry − travel) − now. `≤ 0` ⇒ depart now.
   */
  def computeTimeToDepart(now: Instant, optimalEntry: Instant, travelMin: Int): Int =
    val departInstant = optimalEntry.minusSeconds(travelMin.toLong * 60L)
    ChronoUnit.MINUTES.between(now, departInstant).toInt

  /**
   * Departure timing (the client "don't miss the flight" reminder served to the client card): the "be at the airport
   * by" instant, pulled BACK from the flight departure by the check-in-close + safety margin. This is the travel-free
   * target instant — `computeTimeToDepart` subtracts the drive once, exactly as for arrivals.
   */
  def computeDepartureLatestEntry(flightDeparture: Instant, marginMin: Int): Instant = flightDeparture.minusSeconds(
    marginMin.toLong * 60L
  )

  /**
   * Haversine-based fallback travel-time estimate (50 km/h, minimum 1 minute). Reuses [[PickupTimeService]].
   */
  private def haversineTravelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Int =
    PickupTimeService.haversineTravelMinutes(fromLat, fromLng, toLat, toLng)

  final class Live(
      rideService: RideService,
      airportConfigService: AirportConfigService,
      travelTimeService: TravelTimeService,
      driverLocationProvider: DriverLocationProvider,
      config: AirportArrivalTimingConfig,
      departureConfig: AirportPickupConfig
  ) extends AirportTimingService:

    def compute(
        rideId: RideId,
        callerCompanyId: CompanyId,
        fallbackCoords: Option[(Double, Double)]
    ): IO[Error, AirportTimingResult] =
      for {
        ride                                    <- rideService.getRideById(rideId).mapError {
                                                     case RideError.RideNotFound(_) => Error.NotFound
                                                     case other                     => Error.SettingsLoadFailed(other)
                                                   }
        // Tenant isolation: never reveal a ride from another company.
        _                                       <- ZIO.fail(Error.NotFound).when(ride.companyId != callerCompanyId)
        _                                       <- ZIO.fail(Error.NotAnAirportTransfer).when(!ride.isAirportTransfer)
        // Live flight status (kept fresh by the flight-status monitor) supplies the real terminal → walk buffer.
        flightStatusRow                         <- rideService.getFlightStatus(rideId).mapError(Error.SettingsLoadFailed.apply)
        now                                      = Instant.now()
        seam                                     = estimatedFlightTime(ride, flightStatusRow, now)
        (flightTime, terminalCode, flightStatus) = seam
        isArrival                                = ride.isArrivalAirportTransfer
        // Arrival uses the terminal walk-out buffer; departure uses the airline check-in-close window plus a safety
        // buffer (the same departure margin PickupTimeService applies), NOT a terminal walk.
        bufferMin                                =
          if isArrival then walkBuffer(terminalCode, config)
          else departureConfig.defaultCheckInCloseMinutes + departureConfig.defaultBufferMinutes
        destCoords                              <- terminalCoords(ride)
        origin                                  <- resolveOrigin(ride, fallbackCoords)
        travel                                  <- travelTime(origin, destCoords)
        (travelMin, fallback)                    = travel
        // Arrival: pull the entry time FORWARD from the flight arrival (walk-out buffer, then back into the free
        // window). Departure: pull it BACK from the flight departure (the client "don't miss the flight" reminder) —
        // optimal == latest == "be at the airport by". In both cases `optimalEntry` is the travel-free target instant,
        // so `computeTimeToDepart` subtracts the drive exactly once.
        (latestEntry, optimalEntry)              =
          if isArrival then
            val latest = computeLatestEntry(flightTime, bufferMin)
            (latest, computeOptimalEntry(latest, config.freeParkingMinutes))
          else
            val latest = computeDepartureLatestEntry(flightTime, bufferMin)
            (latest, latest)
        timeToDepart                             = computeTimeToDepart(now, optimalEntry, travelMin)
      } yield AirportTimingResult(
        optimalEntryTime = optimalEntry,
        latestEntryTime = latestEntry,
        travelMinutes = travelMin,
        walkBufferMinutes = bufferMin,
        optimalParkingCost = config.optimalParkingCost,
        earlyEntryParkingCost = config.earlyEntryParkingCost,
        savings = config.earlyEntryParkingCost - config.optimalParkingCost,
        flightStatus = flightStatus,
        actualArrivalTime = flightTime,
        timeToDepartMinutes = timeToDepart,
        travelTimeFallback = fallback
      )

    /**
     * Resolves the terminal destination coordinates. Prefers the airport's checkpoint zone matching the ride's terminal
     * (when known); falls back to the airport's landing geofence centre. Returns [[None]] only when the airport itself
     * is unconfigured — then the travel estimate is skipped (treated as Haversine over zero distance ⇒ minimal travel).
     */
    private def terminalCoords(ride: Ride): IO[Error, Option[(Double, Double)]] =
      ride.specifics.collectFirst { case at: RideSpecifics.AirportTransfer => at.airportCode } match
        case None              => ZIO.none
        case Some(airportCode) =>
          airportConfigService
            .getAirport(airportCode)
            .mapError(Error.SettingsLoadFailed.apply)
            .map(_.map(a => (a.landingLat, a.landingLon)))

    /**
     * Driver's live position; falls back to the app-POSTed coordinates (travel estimate only, never for auth).
     */
    private def resolveOrigin(
        ride: Ride,
        fallbackCoords: Option[(Double, Double)]
    ): IO[Error, Option[(Double, Double)]] =
      ride.driverId match
        case None           => ZIO.succeed(fallbackCoords)
        case Some(driverId) =>
          driverLocationProvider
            .getDriverLocation(driverId)
            .mapError(Error.SettingsLoadFailed.apply)
            .map(_.map { case (lat, lng, _) => (lat, lng) }.orElse(fallbackCoords))

    /**
     * Routing travel time with Haversine fallback. When origin or destination is unknown, returns (1, true).
     */
    private def travelTime(
        origin: Option[(Double, Double)],
        dest: Option[(Double, Double)]
    ): IO[Error, (Int, Boolean)] =
      (origin, dest) match
        case (Some((fromLat, fromLng)), Some((toLat, toLng))) =>
          travelTimeService
            .travelMinutes(fromLat, fromLng, toLat, toLng)
            .mapError(Error.SettingsLoadFailed.apply)
            .map {
              case Some(m) => (m, false)
              case None    => (haversineTravelMinutes(fromLat, fromLng, toLat, toLng), true)
            }
        case _                                                =>
          // Missing driver location or airport coords — cannot route; report a minimal fallback travel time.
          ZIO.succeed((1, true))

  val layer: ZLayer[
    RideService & AirportConfigService & TravelTimeService & DriverLocationProvider & AirportArrivalTimingConfig & AirportPickupConfig,
    Nothing,
    AirportTimingService
  ] = ZLayer.fromFunction(Live.apply)

  /**
   * No-op implementation for tests that wire the full ride environment but do not exercise the airport-timing logic.
   * Always reports [[Error.NotFound]] (the timing endpoint is not under test in those specs).
   */
  val noopLayer: ZLayer[Any, Nothing, AirportTimingService] = ZLayer.succeed(
    new AirportTimingService:
      def compute(
          rideId: RideId,
          callerCompanyId: CompanyId,
          fallbackCoords: Option[(Double, Double)]
      ): IO[Error, AirportTimingResult] = ZIO.fail(Error.NotFound)
  )
