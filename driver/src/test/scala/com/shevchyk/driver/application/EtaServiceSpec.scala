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
      def getAvailability(driverId: PersonId): Task[Option[String]]                           = ZIO.succeed(None)
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
      }
    )
