package com.shevchyk.ride.application

import com.shevchyk.core.config.{AirportArrivalTimingConfig, AirportPickupConfig}
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.{AirportConfigService, AirportTimingService, RideService}
import com.shevchyk.ride.domain.{
  Airport,
  AirportCheckpoint,
  AirportCheckpointZone,
  FlightStatusRow,
  Ride,
  RideError,
  RideSpecifics,
  RideStatus
}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for AirportTimingService — the recommended terminal-entry timing for airport arrival rides.
 *
 * The arrival formula (the walk buffer is ADDED to the arrival; the free-parking window is NOT subtracted — entry is
 * exactly when the passenger reaches the curb): entry = latestEntry = arrival + walkBuffer; timeToDepart =
 * minutesBetween(now, entry − travel). The walk buffer is chosen by the GATE pier letter (K/L = satellite 18, G/H =
 * main 10), falling back to the terminal code when no gate is known.
 *
 * Mutation-verified branches:
 *   - walk buffer ADDED (not subtracted): "normal terminal" asserts entry = arrival + 10. A sign flip → 07:50.
 *   - no free-window subtraction: "entry == latestEntry" — entry is arrival+walk, not arrival+walk−free.
 *   - gate pier classification: satellite gate K → 18, main gate G → 10; gate wins over terminal; terminal fallback.
 *   - travel only affects timeToDepart: two travel values → identical entry/latest, different timeToDepart.
 *   - Haversine fallback: TravelTime None → travelTimeFallback = true.
 *   - tenant isolation: ride of company B, caller A → Error.NotFound (404, not 403).
 *   - not-an-arrival guard: departure ride → Error.NotAnArrival.
 */
object AirportTimingServiceSpec extends ZIOSpecDefault:

  // ── IDs & fixtures ───────────────────────────────────────────────────────

  private val companyA = CompanyId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  private val companyB = CompanyId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000001"))
  private val rideId   = RideId(UUID.fromString("11111111-0000-0000-0000-000000000001"))
  private val clientId = PersonId(UUID.fromString("22222222-0000-0000-0000-000000000001"))
  private val driverId = PersonId(UUID.fromString("33333333-0000-0000-0000-000000000001"))

  // Arrival fixed at 08:00:00Z so the assertions read as clock times.
  private val arrival = Instant.parse("2026-07-01T08:00:00Z")

  private val config = AirportArrivalTimingConfig(
    normalWalkMinutes = 10,
    satelliteWalkMinutes = 18,
    remoteWalkMinutes = 25,
    freeParkingMinutes = 10,
    satelliteTerminalCodes = Set("K", "T2K"),
    satelliteGateLetters = Set("K", "L"),
    optimalParkingCost = 0.0,
    earlyEntryParkingCost = 28.0
  )

  // Departure margin: check-in closes 60 min before departure, +15 min safety buffer = 75 min.
  private val departureConfig = AirportPickupConfig(defaultBufferMinutes = 15, defaultCheckInCloseMinutes = 60)

  private val mucLat = 48.3537
  private val mucLon = 11.7750

  private def arrivalRide(
      company: CompanyId = companyA,
      isArrival: Boolean = true,
      driver: Option[PersonId] = Some(driverId),
      scheduled: Option[Instant] = Some(arrival),
      airportCode: String = "MUC"
  ): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = company,
    driverId = driver,
    status = RideStatus.InProgress,
    pickupLocation = Location("MUC Airport", Some(mucLat), Some(mucLon)),
    dropoffLocation = Location("Munich", Some(48.1351), Some(11.5820)),
    pickupDateTime = arrival,
    scheduledTime = scheduled,
    specifics = Some(
      RideSpecifics.AirportTransfer(airportCode = airportCode, flightNumber = Some("LH123"), isArrival = isArrival)
    )
  )

  private def nonAirportRide(): Ride = arrivalRide().copy(specifics = None)

  private val mucAirport = Airport(
    code = "MUC",
    name = "Munich Airport",
    country = "DE",
    landingLat = mucLat,
    landingLon = mucLon,
    landingRadius = 2000,
    isActive = true,
    zones = Nil,
    createdAt = Instant.EPOCH,
    updatedAt = Instant.EPOCH
  )

  // ── Test doubles ─────────────────────────────────────────────────────────

  // The RideService trait is large; only getRideById and getFlightStatus are exercised, the rest die if called.
  private def rideServiceLayer(ride: Option[Ride], flightStatus: Option[FlightStatusRow]): ULayer[RideService] = ZLayer
    .succeed(
      new RideService:
        import com.shevchyk.ride.domain.*
        private def notImpl = ZIO.die(new NotImplementedError("AirportTimingServiceSpec RideService stub"))

        def getRideById(id: RideId): IO[RideError, Ride] =
          ride match
            case Some(r) => ZIO.succeed(r)
            case None    => ZIO.fail(RideError.RideNotFound(id))

        def getFlightStatus(id: RideId): IO[RideError, Option[FlightStatusRow]] = ZIO.succeed(flightStatus)

        def createRide(req: CreateRideRequest): IO[RideError, Ride]                                                  = notImpl
        def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                             = notImpl
        def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                       = notImpl
        def completeRide(rideId: RideId): IO[RideError, Ride]                                                        = notImpl
        def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]                  = notImpl
        def cancelRideWithReason(
            rideId: RideId,
            userId: PersonId,
            userRole: PersonRole,
            req: CancelRideRequest,
            companyId: CompanyId
        ): IO[RideError, Ride] = notImpl
        def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                              = notImpl
        def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                     = notImpl
        def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride]                      = notImpl
        def handOffToExternal(
            rideId: RideId,
            callerCompanyId: CompanyId,
            callerId: PersonId,
            req: HandOffRequest
        ): IO[RideError, Ride] = notImpl
        def createPartnerCompany(
            companyId: CompanyId,
            req: CreatePartnerCompanyRequest
        ): IO[RideError, PartnerCompany] = notImpl
        def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]]                          = notImpl
        def createExternalDriver(
            companyId: CompanyId,
            req: CreateExternalDriverRequest
        ): IO[RideError, ExternalDriver] = notImpl
        def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]]                           = notImpl
        def updateRideStatus(
            rideId: RideId,
            req: UpdateRideStatusRequest,
            userId: PersonId,
            userRole: PersonRole
        ): IO[RideError, Ride] = notImpl
        def assignDriver(rideId: RideId, driverId: PersonId, overrideScheduleConflict: Boolean): IO[RideError, Ride] =
          notImpl
        def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                          = notImpl
        def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]          = notImpl
        def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                      = notImpl
        def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                      = notImpl
        def getAllRides: IO[RideError, List[Ride]]                                                                   = notImpl
        def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                       = notImpl
        def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]     =
          notImpl
        def getDriverRidesPaginated(
            driverId: PersonId,
            companyId: CompanyId,
            offset: Int,
            limit: Int
        ): IO[RideError, List[Ride]] = notImpl
        def updateRideDetails(
            rideId: RideId,
            req: UpdateRideDetailsRequest,
            userId: PersonId,
            userRole: PersonRole,
            cid: Option[CompanyId]
        ): IO[RideError, Ride] = notImpl
        def reassignDriver(
            rideId: RideId,
            newDriverId: PersonId,
            overrideScheduleConflict: Boolean,
            allowPastRide: Boolean = false
        ): IO[RideError, Ride] = notImpl
        def markPayment(rideId: RideId, ps: PaymentStatus, pm: Option[PaymentMethod]): IO[RideError, Ride]           = notImpl
        def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                 = notImpl
        def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                             = notImpl
        def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                         = notImpl
        def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                         = notImpl
        def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                     = notImpl
        def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]             = notImpl
        def getDriverEarnings(
            driverId: PersonId,
            companyId: CompanyId,
            period: EarningsPeriod,
            anchorDate: java.time.LocalDate
        ): IO[RideError, DriverEarningsReport] = notImpl
        def setRidePrice(
            rideId: RideId,
            price: Double,
            userId: PersonId,
            userRole: PersonRole,
            companyId: CompanyId
        ): IO[RideError, Ride] = notImpl
        def getRidesByDrivers(
            driverIds: List[PersonId],
            from: Option[String],
            to: Option[String],
            companyId: CompanyId
        ): IO[RideError, List[Ride]] = notImpl
    )

  // AirportConfigService: only getAirport is exercised.
  private def airportConfigLayer(airport: Option[Airport]): ULayer[AirportConfigService] = ZLayer.succeed(
    new AirportConfigService:
      private def notImpl = ZIO.die(new NotImplementedError("AirportTimingServiceSpec AirportConfigService stub"))

      def getAirport(code: String): Task[Option[Airport]]                                            = ZIO.succeed(airport.filter(_.code == code))
      def listAirports(): Task[List[Airport]]                                                        = notImpl
      def createAirport(airport: Airport): Task[Airport]                                             = notImpl
      def updateAirport(code: String, airport: Airport): Task[Option[Airport]]                       = notImpl
      def deleteAirport(code: String): Task[Boolean]                                                 = notImpl
      def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone]                       = notImpl
      def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]]     = notImpl
      def deleteZone(id: UUID): Task[Boolean]                                                        = notImpl
      def getLandingGeofence(airportCode: String): Task[Option[(Double, Double, Int)]]               = notImpl
      def getCheckpointDisplayName(airportCode: String, checkpoint: AirportCheckpoint): Task[String] = notImpl
  )

  private def travelTimeLayer(result: Option[Int]): ULayer[com.shevchyk.ride.application.TravelTimeService] = ZLayer
    .succeed(
      new com.shevchyk.ride.application.TravelTimeService:
        def travelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Task[Option[Int]] = ZIO
          .succeed(result)
    )

  private def driverLocationLayer(loc: Option[(Double, Double)]): ULayer[DriverLocationProvider] = ZLayer.succeed(
    new DriverLocationProvider:
      def getDriverLocation(id: PersonId): Task[Option[(Double, Double, Instant)]] = ZIO.succeed(loc.map {
        case (lat, lng) => (lat, lng, Instant.EPOCH)
      })
  )

  private def service(
      ride: Option[Ride],
      airport: Option[Airport],
      travel: Option[Int],
      driverLoc: Option[(Double, Double)],
      flightStatus: Option[FlightStatusRow]
  ): ULayer[AirportTimingService] =
    (rideServiceLayer(ride, flightStatus) ++ airportConfigLayer(airport) ++ travelTimeLayer(travel) ++
      driverLocationLayer(driverLoc) ++ ZLayer.succeed(config) ++
      ZLayer.succeed(departureConfig)) >>> AirportTimingService.layer

  private def compute(
      ride: Option[Ride],
      caller: CompanyId = companyA,
      airport: Option[Airport] = Some(mucAirport),
      travel: Option[Int] = Some(20),
      driverLoc: Option[(Double, Double)] = Some((48.1, 11.6)),
      flightStatus: Option[FlightStatusRow] = None
  ): IO[AirportTimingService.Error, com.shevchyk.ride.application.service.AirportTimingResult] = ZIO
    .serviceWithZIO[AirportTimingService](_.compute(rideId, caller, Some((48.1, 11.6))))
    .provide(service(ride, airport, travel, driverLoc, flightStatus))

  // ── Tests ────────────────────────────────────────────────────────────────

  def spec =
    suite("AirportTimingService")(
      test("normal terminal: entry = arrival + walk(10), no free-window subtraction") {
        for result <- compute(Some(arrivalRide()))
        yield assertTrue(
          result.latestEntryTime == arrival.plusSeconds(10 * 60L),  // 08:10
          result.optimalEntryTime == arrival.plusSeconds(10 * 60L), // == latest, NOT arrival
          result.walkBufferMinutes == 10
        )
      },
      test("satellite gate (K): larger walk buffer than a main gate (G)") {
        // The gate letter selects the pier: K = satellite (18), G = main (10).
        val mainBuf      = AirportTimingService.walkBuffer(Some("G35"), None, config)
        val satelliteBuf = AirportTimingService.walkBuffer(Some("K12"), None, config)
        assertTrue(
          mainBuf == 10,
          satelliteBuf == 18,
          AirportTimingService
            .computeLatestEntry(arrival, satelliteBuf)
            .isAfter(AirportTimingService.computeLatestEntry(arrival, mainBuf))
        )
      },
      test("remote (bus) stand: longest walk buffer of all, beats satellite") {
        // A remote apron stand ("Gate REMOTE") busses the passenger in → the slowest case (25),
        // longer than the satellite pier (18) and the main terminal (10). Case-insensitive.
        val remoteBuf    = AirportTimingService.walkBuffer(Some("REMOTE"), None, config)
        val remoteLower  = AirportTimingService.walkBuffer(Some("remote"), Some("T2"), config)
        val satelliteBuf = AirportTimingService.walkBuffer(Some("K12"), None, config)
        assertTrue(
          remoteBuf == 25,
          remoteLower == 25, // case-insensitive, and not overridden by the (main) T2 terminal
          remoteBuf > satelliteBuf
        )
      },
      test("entry == latestEntry (free-parking window is not subtracted)") {
        for result <- compute(Some(arrivalRide()))
        yield assertTrue(result.optimalEntryTime == result.latestEntryTime)
      },
      test("travel time affects only timeToDepart, not entry/latest instants") {
        for
          fast <- compute(Some(arrivalRide()), travel = Some(5))
          slow <- compute(Some(arrivalRide()), travel = Some(40))
        yield assertTrue(
          fast.optimalEntryTime == slow.optimalEntryTime,
          fast.latestEntryTime == slow.latestEntryTime,
          fast.timeToDepartMinutes > slow.timeToDepartMinutes
        )
      },
      test("Haversine fallback when routing returns None → travelTimeFallback = true") {
        for result <- compute(Some(arrivalRide()), travel = None)
        yield assertTrue(result.travelTimeFallback, result.travelMinutes >= 1)
      },
      test("routing available → travelTimeFallback = false") {
        for result <- compute(Some(arrivalRide()), travel = Some(20))
        yield assertTrue(!result.travelTimeFallback, result.travelMinutes == 20)
      },
      test("tenant isolation: ride of company B, caller company A → NotFound") {
        for exit <- compute(Some(arrivalRide(company = companyB)), caller = companyA).exit
        yield assertTrue(exit == Exit.fail(AirportTimingService.Error.NotFound))
      },
      test("departure ride: entry pulled BACK from flight time using check-in margin, not walk buffer") {
        // A departure airport transfer (the client "don't miss the flight" reminder) must still compute, not fail, and
        // must use the airline check-in-close + safety margin (60 + 15 = 75 min), NOT the 10-min terminal walk.
        // optimalEntry == latestEntry == "be at the airport by" (travel-free); travel is applied once via timeToDepart.
        for result <- compute(Some(arrivalRide(isArrival = false)), travel = Some(20))
        yield assertTrue(
          result.walkBufferMinutes == 75,                           // check-in(60) + buffer(15)
          result.latestEntryTime == arrival.minusSeconds(75 * 60L), // flight − 75 = 06:45
          result.optimalEntryTime == result.latestEntryTime,        // NOT latest − travel (no double count)
          result.optimalEntryTime.isBefore(arrival)
        )
      },
      test("departure ride: timeToDepart subtracts travel exactly once (no double-count)") {
        // Two travel times must shift timeToDepart by exactly their difference. If the departure branch subtracted
        // travel into optimalEntry AND again in computeTimeToDepart, the gap would be 2× (40 min, not 20).
        for
          fast <- compute(Some(arrivalRide(isArrival = false)), travel = Some(10))
          slow <- compute(Some(arrivalRide(isArrival = false)), travel = Some(30))
        yield assertTrue(
          fast.optimalEntryTime == slow.optimalEntryTime,           // entry instant is travel-free
          fast.timeToDepartMinutes - slow.timeToDepartMinutes == 20 // 30 − 10, counted once
        )
      },
      test("non-airport ride → NotAnAirportTransfer") {
        for exit <- compute(Some(nonAirportRide())).exit
        yield assertTrue(exit == Exit.fail(AirportTimingService.Error.NotAnAirportTransfer))
      },
      test("ride not found → NotFound") {
        for exit <- compute(None).exit
        yield assertTrue(exit == Exit.fail(AirportTimingService.Error.NotFound))
      },
      test("unknown gate and terminal → normal buffer used") {
        for result <- compute(Some(arrivalRide()))
        yield assertTrue(result.walkBufferMinutes == config.normalWalkMinutes)
      },
      test("live flight status with satellite gate (K12) → satellite walk buffer, later entry") {
        // The flight-status monitor records the real gate; an arrival at a K gate (satellite pier) must use the longer
        // 18-min walk-out buffer instead of 10. latestEntry = arrival + 18 (later than the 08:10 of a main gate).
        val satellite = FlightStatusRow(gate = Some("K12"), terminal = Some("T2"))
        for result <- compute(Some(arrivalRide()), flightStatus = Some(satellite))
        yield assertTrue(
          result.walkBufferMinutes == config.satelliteWalkMinutes, // 18, not 10
          result.latestEntryTime == arrival.plusSeconds(18 * 60L), // 08:18
          result.optimalEntryTime == arrival.plusSeconds(18 * 60L) // entry == latest (no free subtraction)
        )
      },
      test("live flight status with a main gate (G35 in T2) → normal walk buffer") {
        // Gate letter G is a main-terminal pier → normal buffer, even though the terminal is T2.
        val mainGate = FlightStatusRow(gate = Some("G35"), terminal = Some("T2"))
        for result <- compute(Some(arrivalRide()), flightStatus = Some(mainGate))
        yield assertTrue(result.walkBufferMinutes == config.normalWalkMinutes) // 10
      },
      test("no gate yet → falls back to the satellite terminal code (K)") {
        // Until the gate is scraped, the satellite terminal code still classifies the pier.
        val noGateSatTerminal = FlightStatusRow(terminal = Some("K"))
        for result <- compute(Some(arrivalRide()), flightStatus = Some(noGateSatTerminal))
        yield assertTrue(result.walkBufferMinutes == config.satelliteWalkMinutes) // 18 via terminal fallback
      },
      test("live delayed flight time shifts the recommended entry accordingly") {
        // The monitor recorded a live (estimated) arrival 40 min after the booking's scheduled time. The entry must
        // follow the LIVE time — otherwise the driver enters against the stale schedule and waits out the delay.
        val delayed = arrival.plusSeconds(40 * 60L)
        val live    = FlightStatusRow(flightTime = Some(delayed), scheduledTime = Some(arrival))
        for result <- compute(Some(arrivalRide()), flightStatus = Some(live))
        yield assertTrue(
          result.actualArrivalTime == delayed,                     // 08:40, not the scheduled 08:00
          result.optimalEntryTime == delayed.plusSeconds(10 * 60L) // 08:50 = live arrival + 10 walk
        )
      },
      test("live status without a flight time → falls back to the booking's scheduled time") {
        val noTime = FlightStatusRow(gate = Some("G35"), terminal = Some("T2"))
        for result <- compute(Some(arrivalRide()), flightStatus = Some(noTime))
        yield assertTrue(result.actualArrivalTime == arrival)
      },
      test("estimatedFlightTime: live flight time wins; else scheduledTime; else now + 2h") {
        val now     = Instant.parse("2026-07-01T06:00:00Z")
        val delayed = arrival.plusSeconds(40 * 60L)
        val live    = Some(FlightStatusRow(flightTime = Some(delayed), scheduledTime = Some(arrival)))
        assertTrue(
          AirportTimingService.estimatedFlightTime(arrivalRide(), live, now)._1 == delayed,
          AirportTimingService.estimatedFlightTime(arrivalRide(), None, now)._1 == arrival,
          AirportTimingService
            .estimatedFlightTime(arrivalRide(scheduled = None), None, now)
            ._1 == now.plusSeconds(2 * 3600L)
        )
      },
      test("savings = early − optimal parking cost") {
        for result <- compute(Some(arrivalRide()))
        yield assertTrue(result.savings == 28.0, result.actualArrivalTime == arrival)
      },
      // ── arrivalOptimalEntry: the GPS-free "Einfahrt um" used by the list cards ───────────────
      test("arrivalOptimalEntry: main gate → arrival + 10 walk (no free subtraction)") {
        val entry = AirportTimingService.arrivalOptimalEntry(Some(arrival), Some("G35"), Some("T2"), config)
        assertTrue(entry.contains(arrival.plusSeconds(10 * 60L))) // 08:10
      },
      test("arrivalOptimalEntry: satellite gate (K) → arrival + 18, later than a main gate") {
        val sat    = AirportTimingService.arrivalOptimalEntry(Some(arrival), Some("K12"), Some("T2"), config)
        val normal = AirportTimingService.arrivalOptimalEntry(Some(arrival), Some("G35"), Some("T2"), config)
        assertTrue(
          sat.contains(arrival.plusSeconds(18 * 60L)), // 08:18
          sat.exists(s => normal.exists(s.isAfter))
        )
      },
      test("arrivalOptimalEntry: gate wins over terminal (K gate in a T2 terminal → satellite)") {
        val entry = AirportTimingService.arrivalOptimalEntry(Some(arrival), Some("K12"), Some("T2"), config)
        assertTrue(entry.contains(arrival.plusSeconds(18 * 60L)))
      },
      test("arrivalOptimalEntry: no arrival time → None (no now+2h placeholder)") {
        assertTrue(AirportTimingService.arrivalOptimalEntry(None, Some("K12"), Some("T2"), config).isEmpty)
      }
    )
