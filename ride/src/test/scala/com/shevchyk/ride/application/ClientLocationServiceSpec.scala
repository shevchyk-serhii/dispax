package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  ClientLocationService,
  ClientLocationServiceImpl
}
import com.shevchyk.ride.repository.{InMemoryRideRepository, ClientLocationRepository}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * No-op stub for AirportCheckpointService used in ClientLocationService tests.
 */
class NoOpAirportCheckpointService extends AirportCheckpointService:
  def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]] = ZIO.none

  def markCheckpoint(ride: Ride, requestedCheckpoint: AirportCheckpoint, markedBy: PersonId): IO[RideError, Unit] =
    ZIO.unit

object NoOpAirportCheckpointService:
  val layer: ULayer[AirportCheckpointService] = ZLayer.succeed(new NoOpAirportCheckpointService)

class InMemoryClientLocationRepository extends ClientLocationRepository:
  private val store = new ConcurrentHashMap[RideId, ClientLocation]()

  def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): Task[Unit] = ZIO
    .succeed {
      store.put(rideId, ClientLocation(rideId, clientId, latitude, longitude))
      ()
    }

  def getLocation(rideId: RideId): Task[Option[ClientLocation]] = ZIO.succeed(Option(store.get(rideId)))

object InMemoryClientLocationRepository:
  val layer: ULayer[ClientLocationRepository] = ZLayer.succeed(InMemoryClientLocationRepository())

class InMemoryDriverLocationProvider extends DriverLocationProvider:
  private var locations: Map[PersonId, (Double, Double, Instant)] = Map.empty

  def setLocation(driverId: PersonId, lat: Double, lng: Double): Unit =
    locations = locations.updated(driverId, (lat, lng, Instant.now()))

  def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]] = ZIO.succeed(
    locations.get(driverId)
  )

object InMemoryDriverLocationProvider:
  val layer: ULayer[DriverLocationProvider] = ZLayer.succeed(InMemoryDriverLocationProvider())

object ClientLocationServiceSpec extends ZIOSpecDefault {

  val companyId   = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId    = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
  val otherClient = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000003"))
  val driverId    = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000004"))

  def makeRide(withDriver: Boolean = true): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = if withDriver then Some(driverId) else None,
    status = RideStatus.InProgress,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B"),
    pickupDateTime = Instant.now().plusSeconds(3600)
  )

  def layers =
    InMemoryRideRepository.layer ++
      InMemoryClientLocationRepository.layer ++
      InMemoryDriverLocationProvider.layer ++
      EventHub.layer ++
      NoOpAirportCheckpointService.layer >>>
      (ZLayer.fromFunction(ClientLocationServiceImpl.apply) ++
        InMemoryRideRepository.layer ++
        InMemoryClientLocationRepository.layer ++
        InMemoryDriverLocationProvider.layer ++
        EventHub.layer)

  def createRide(withDriver: Boolean = true) = ZIO
    .serviceWithZIO[com.shevchyk.ride.repository.RideRepository](_.create(makeRide(withDriver)).orDie)

  def spec =
    suite("ClientLocationService")(
      suite("updateClientLocation")(
        test("stores location for own ride") {
          for {
            ride <- createRide()
            svc  <- ZIO.service[ClientLocationService]
            _    <- svc.updateClientLocation(ride.id, clientId, 48.1, 11.5)
          } yield assertCompletes
        }.provide(layers),
        test("fails with UnauthorizedAccess when clientId does not match ride") {
          for {
            ride   <- createRide()
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.updateClientLocation(ride.id, otherClient, 48.1, 11.5).exit
          } yield assertTrue(result.isFailure)
        }.provide(layers),
        test("unauthorized access error is specifically RideError.UnauthorizedAccess, not RideNotFound") {
          // Mutation-kill: mutant changes ZIO.fail(RideError.UnauthorizedAccess) → ZIO.fail(RideError.RideNotFound)
          // This test distinguishes the two by checking the exact error type.
          for {
            ride   <- createRide()
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.updateClientLocation(ride.id, otherClient, 48.1, 11.5).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case _: RideError.UnauthorizedAccess => true
                case _                               => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("fails with RideNotFound for unknown ride") {
          for {
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.updateClientLocation(RideId.generate(), clientId, 48.1, 11.5).exit
          } yield assertTrue(result.isFailure)
        }.provide(layers),
        test("publishes LocationUpdated event with correct locationType") {
          for {
            hub   <- ZIO.service[EventHub]
            ride  <- createRide()
            svc   <- ZIO.service[ClientLocationService]
            event <- ZIO.scoped {
                       for {
                         queue <- hub.subscribe
                         _     <- svc.updateClientLocation(ride.id, clientId, 48.1, 11.5)
                         e     <- queue.take
                       } yield e
                     }
          } yield assertTrue(
            event.isInstanceOf[WebSocketEvent.LocationUpdated],
            event.asInstanceOf[WebSocketEvent.LocationUpdated].locationType == "client"
          )
        }.provide(layers),
        test("published event contains correct coordinates") {
          for {
            hub   <- ZIO.service[EventHub]
            ride  <- createRide()
            svc   <- ZIO.service[ClientLocationService]
            event <- ZIO.scoped {
                       for {
                         queue <- hub.subscribe
                         _     <- svc.updateClientLocation(ride.id, clientId, 52.5, 13.4)
                         e     <- queue.take.map(_.asInstanceOf[WebSocketEvent.LocationUpdated])
                       } yield e
                     }
          } yield assertTrue(event.latitude == 52.5, event.longitude == 13.4)
        }.provide(layers),
        // -- Coordinate validation added by test audit 2026-06 -------------
        test("rejects latitude out of range") {
          for {
            ride   <- createRide()
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.updateClientLocation(ride.id, clientId, 91.0, 11.5).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(msg) => msg.contains("Latitude")
                case _                              => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("rejects longitude out of range") {
          for {
            ride   <- createRide()
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.updateClientLocation(ride.id, clientId, 48.1, 181.0).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(msg) => msg.contains("Longitude")
                case _                              => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("accepts boundary coordinates (-90/180)") {
          for {
            ride <- createRide()
            svc  <- ZIO.service[ClientLocationService]
            _    <- svc.updateClientLocation(ride.id, clientId, -90.0, 180.0)
          } yield assertCompletes
        }.provide(layers)
      ),
      suite("getRideLocations")(
        test("returns None for both when no locations stored") {
          for {
            ride   <- createRide(withDriver = false)
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.getRideLocations(ride.id)
          } yield assertTrue(result.clientLocation.isEmpty, result.driverLocation.isEmpty)
        }.provide(layers),
        test("returns stored client location") {
          for {
            ride   <- createRide()
            svc    <- ZIO.service[ClientLocationService]
            _      <- svc.updateClientLocation(ride.id, clientId, 48.1, 11.5)
            result <- svc.getRideLocations(ride.id)
          } yield assertTrue(
            result.clientLocation.isDefined,
            result.clientLocation.get.latitude == 48.1,
            result.clientLocation.get.longitude == 11.5
          )
        }.provide(layers),
        test("returns driver location from DriverLocationProvider") {
          for {
            provider <- ZIO.service[DriverLocationProvider]
            ride     <- createRide(withDriver = true)
            svc      <- ZIO.service[ClientLocationService]
            _        <- ZIO.succeed(provider.asInstanceOf[InMemoryDriverLocationProvider].setLocation(driverId, 48.2, 11.6))
            result   <- svc.getRideLocations(ride.id)
          } yield assertTrue(result.driverLocation.isDefined, result.driverLocation.get.latitude == 48.2)
        }.provide(layers),
        test("returns None for driver when no driver assigned") {
          for {
            ride   <- createRide(withDriver = false)
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.getRideLocations(ride.id)
          } yield assertTrue(result.driverLocation.isEmpty)
        }.provide(layers),
        test("fails with RideNotFound for unknown ride") {
          for {
            svc    <- ZIO.service[ClientLocationService]
            result <- svc.getRideLocations(RideId.generate()).exit
          } yield assertTrue(result.isFailure)
        }.provide(layers),
        test("returns both locations when both are available") {
          for {
            provider <- ZIO.service[DriverLocationProvider]
            ride     <- createRide(withDriver = true)
            svc      <- ZIO.service[ClientLocationService]
            _        <- svc.updateClientLocation(ride.id, clientId, 48.1, 11.5)
            _        <- ZIO.succeed(provider.asInstanceOf[InMemoryDriverLocationProvider].setLocation(driverId, 48.2, 11.6))
            result   <- svc.getRideLocations(ride.id)
          } yield assertTrue(result.clientLocation.isDefined, result.driverLocation.isDefined)
        }.provide(layers)
      )
    )
}
