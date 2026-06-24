package com.shevchyk.driver.application

import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.domain.*
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.ride.domain.{ClientLocation, Ride, RideStatus}
import com.shevchyk.ride.repository.ClientLocationRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object EtaServiceSpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.randomUUID())
  private val driver    = PersonId(UUID.randomUUID())
  private val client    = PersonId(UUID.randomUUID())

  // Munich centre → Munich Airport, ~30 km apart (well-separated for the
  // Haversine fallback to yield a deterministic, large ETA).
  private val munichLat  = 48.137
  private val munichLng  = 11.575
  private val airportLat = 48.353
  private val airportLng = 11.786

  private def ride(pickupHasCoords: Boolean, withDriver: Boolean = true): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = companyId,
    driverId = if withDriver then Some(driver) else None,
    status = RideStatus.Assigned,
    pickupLocation =
      if pickupHasCoords then Location("Munich Airport", Some(airportLat), Some(airportLng))
      else Location("Munich Airport"),
    dropoffLocation = Location("Somewhere"),
    pickupDateTime = Instant.now().plusSeconds(1800)
  )

  // DriverLocationService stub: returns the driver at Munich centre (or nothing).
  private def driverLocLayer(loc: Option[DriverLocation]): ZLayer[Any, Nothing, DriverLocationService] = ZLayer.succeed(
    new DriverLocationService:
      def getLocation(driverId: PersonId): Task[Option[DriverLocation]]                       = ZIO.succeed(loc)
      def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] = ZIO.unit
      def updateAvailability(driverId: PersonId, status: String): Task[Unit]                  = ZIO.unit
      def getAvailability(driverId: PersonId): Task[Option[String]]                           = ZIO.none
      def getAvailableDrivers(
          companyId: CompanyId
      ): Task[List[com.shevchyk.driver.infrastructure.http.AvailableDriverDto]] = ZIO.succeed(Nil)
  )

  private val driverAtMunich = driverLocLayer(Some(DriverLocation(driver, munichLat, munichLng)))
  private val driverMissing  = driverLocLayer(None)

  // HERE stub: either returns a fixed ETA or None (forcing the fallback).
  private def hereLayer(eta: Option[Int]): ZLayer[Any, Nothing, HereRoutingService] = ZLayer.succeed(
    new HereRoutingService:
      def getEtaMinutes(oLat: Double, oLng: Double, dLat: Double, dLng: Double): Task[Option[Int]] = ZIO.succeed(eta)
  )

  // ClientLocationRepository stub: optional live client location.
  private def clientLocLayer(loc: Option[ClientLocation]): ZLayer[Any, Nothing, ClientLocationRepository] = ZLayer
    .succeed(
      new ClientLocationRepository:
        def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
          ZIO.unit
        def getLocation(rideId: RideId): Task[Option[ClientLocation]]                                           = ZIO.succeed(loc)
    )

  private val noClientLoc = clientLocLayer(None)

  private def etaLayer(
      driverLoc: ZLayer[Any, Nothing, DriverLocationService],
      here: ZLayer[Any, Nothing, HereRoutingService],
      clientLoc: ZLayer[Any, Nothing, ClientLocationRepository] = noClientLoc
  ): ZLayer[Any, Nothing, EtaService] = (driverLoc ++ here ++ GeocodingService.noop ++ clientLoc) >>> EtaService.layer

  def spec =
    suite("EtaService.etaForRide")(
      test("uses the HERE value when present") {
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = true))
        } yield assertTrue(eta.contains(17)))
          .provide(etaLayer(driverAtMunich, hereLayer(Some(17))))
      },
      test("falls back to Haversine when HERE returns None") {
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = true))
        } yield assertTrue(
          // ~30 km at 50 km/h ≈ 36 min; assert a sane non-trivial estimate.
          eta.exists(e => e >= 20 && e <= 60)
        ))
          .provide(etaLayer(driverAtMunich, hereLayer(None)))
      },
      test("returns None when the driver has no live location") {
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = true))
        } yield assertTrue(eta.isEmpty))
          .provide(etaLayer(driverMissing, hereLayer(Some(10))))
      },
      test("returns None when the ride has no assigned driver") {
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = true, withDriver = false))
        } yield assertTrue(eta.isEmpty))
          .provide(etaLayer(driverAtMunich, hereLayer(Some(10))))
      },
      test("prefers the live client location over the pickup coords") {
        // Client is right next to the driver (Munich centre) → tiny ETA, despite
        // the pickup address pointing at the airport ~30 km away.
        val nearClient = clientLocLayer(Some(ClientLocation(RideId(UUID.randomUUID()), client, munichLat, munichLng)))
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = true))
        } yield assertTrue(eta.exists(_ <= 5)))
          .provide(etaLayer(driverAtMunich, hereLayer(None), nearClient))
      },
      // -----------------------------------------------------------------------
      // NEW: missing destination coordinate combinations
      // -----------------------------------------------------------------------
      test("returns None when pickup has no coords and geocoding returns original (no coords)") {
        // GeocodingService.noop returns the original Location unchanged (no coords added).
        // With pickup.latitude == None, the Option zip short-circuits → None.
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = false))
        } yield assertTrue(eta.isEmpty))
          .provide(etaLayer(driverAtMunich, hereLayer(Some(17))))
      },
      test("geocoding enriches pickup coords → HERE returns ETA") {
        val enrichingGeocoding: ZLayer[Any, Nothing, GeocodingService] = ZLayer.succeed(
          new GeocodingService:
            def geocode(address: String): Task[Option[(Double, Double)]] = ZIO.succeed(Some((airportLat, airportLng)))
        )
        val layers                                                     = (driverAtMunich ++ hereLayer(Some(20)) ++ enrichingGeocoding ++ noClientLoc) >>> EtaService.layer
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = false))
        } yield assertTrue(eta.contains(20)))
          .provide(layers)
      },
      test("geocoding fails → falls back to original pickup (no coords) → returns None") {
        val failingGeocoding: ZLayer[Any, Nothing, GeocodingService] = ZLayer.succeed(
          new GeocodingService:
            def geocode(address: String): Task[Option[(Double, Double)]] = ZIO.fail(RuntimeException("geocoding down"))
        )
        // The source uses .orElse(ZIO.succeed(ride.pickupLocation)) so the failure
        // yields the original Location which has no coords → eta is None.
        val layers                                                   = (driverAtMunich ++ hereLayer(Some(20)) ++ failingGeocoding ++ noClientLoc) >>> EtaService.layer
        (for {
          svc <- ZIO.service[EtaService]
          eta <- svc.etaForRide(ride(pickupHasCoords = false))
        } yield assertTrue(eta.isEmpty))
          .provide(layers)
      },
      // -----------------------------------------------------------------------
      // NEW: estimateEtaMinutes direct unit tests (private[application])
      // -----------------------------------------------------------------------
      test("estimateEtaMinutes: zero distance clamps to 1 minute") {
        val result = EtaService.estimateEtaMinutes(48.1351, 11.5820, 48.1351, 11.5820)
        assertTrue(result.contains(1))
      },
      test("estimateEtaMinutes: non-trivial distance yields result >= 1") {
        val result = EtaService.estimateEtaMinutes(48.1, 11.5, 48.2, 11.6)
        assertTrue(result.exists(_ >= 1))
      },
      // -----------------------------------------------------------------------
      // MUTATION KILL: haversine longitude weight + urban speed
      // -----------------------------------------------------------------------
      // Two points at Munich latitude (48.137°N) separated by exactly 1 degree of
      // longitude and ZERO latitude difference.  At this latitude the cos² factor
      // shrinks the longitudinal arc from ~111 km (equator) to ~74 km.
      //
      // Mutations targeted:
      //   • cos weight dropped (L40–L41) → dist ~111 km → ETA ~134 min (kills range [85,95])
      //   • longitude term zeroed (L41)  → dist ≈ 0    → ETA clamped to 1 min (kills range)
      //   • urban speed 50→60 km/h (L43) → ETA 75 min              (kills range)
      //
      // Correct: dist ≈ 74 206 m at 50 km/h → ETA = ceil(74206 / 833.33) = 90 min
      test(
        "estimateEtaMinutes: purely longitudinal separation at Munich latitude kills cos-weight and speed mutations"
      ) {
        // 48.137°N, 10.000°E  →  48.137°N, 11.000°E  (1° longitude, 0° latitude)
        // Expected distance ≈ 74 206 m  (= 111 195 m * cos(48.137°))
        // Expected ETA at 50 km/h: ceil(74206 / (50000/60)) = ceil(89.05) = 90 min
        val result = EtaService.estimateEtaMinutes(48.137, 10.0, 48.137, 11.0)
        assertTrue(result.exists(e => e >= 85 && e <= 95))
      }
    )
