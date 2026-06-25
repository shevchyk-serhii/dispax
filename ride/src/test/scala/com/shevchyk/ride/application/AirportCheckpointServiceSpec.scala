package com.shevchyk.ride.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId, WebSocketEvent}
import com.shevchyk.ride.application.service.{AirportCheckpointService, AirportConfigService}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{InMemoryAirportConfigRepository, InMemoryRideRepository, RideRepository}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object AirportCheckpointServiceSpec extends ZIOSpecDefault {

  // -- Test UUIDs ----------------------------------------------------------
  val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  val driverId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  // -- Ride factory --------------------------------------------------------
  // isArrival is encoded in AirportTransfer.isArrival (persisted via the specifics JSONB column),
  // NOT in the flightIsArrival column which is never written by create()/update().
  def makeInProgressArrivalRide(checkpoint: Option[AirportCheckpoint] = None): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = RideStatus.InProgress,
    pickupLocation = Location("MUC Airport"),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH123", isArrival = true)),
    airportCheckpoint = checkpoint
  )

  // InMemoryAirportConfigRepository seeded with the MUC airport so that geofence checks
  // that rely on the real MUC coordinates (lat 48.3537, lon 11.7860, radius 2000 m) work.
  private val mucAirport = Airport(
    code = "MUC",
    name = "München Franz Josef Strauß",
    country = "DE",
    landingLat = 48.3537,
    landingLon = 11.7860,
    landingRadius = 2000,
    isActive = true,
    zones = Nil,
    createdAt = Instant.EPOCH,
    updatedAt = Instant.EPOCH
  )

  // A ZLayer backed by InMemoryAirportConfigRepository, pre-seeded with MUC.
  // .orDie converts the Throwable channel to Nothing (create on in-memory repo can't fail).
  private val airportConfigRepoLayer: ZLayer[Any, Nothing, com.shevchyk.ride.repository.AirportConfigRepository] =
    ZLayer
      .fromZIO(
        for {
          repo <- ZIO.succeed(new InMemoryAirportConfigRepository)
          _    <- repo.create(mucAirport)
        } yield repo: com.shevchyk.ride.repository.AirportConfigRepository
      )
      .orDie

  private val airportConfigServiceLayer: ZLayer[Any, Nothing, AirportConfigService] =
    airportConfigRepoLayer >>> AirportConfigService.layer

  // Returns the service plus a way to drain published events.
  def layersWithHub =
    (InMemoryRideRepository.layer ++ EventHub.layer ++ airportConfigServiceLayer) >>>
      (AirportCheckpointService.layer ++ ZLayer.environment[RideRepository] ++ EventHub.layer)

  // -- spec ----------------------------------------------------------------
  def spec =
    suite("AirportCheckpointService")(
      suite("markCheckpoint")(
        test("None → Landed succeeds: repo updated and one event published") {
          ZIO.scoped {
            for {
              hub   <- ZIO.service[EventHub]
              sub   <- hub.subscribe // subscribe before the action
              repo  <- ZIO.service[RideRepository]
              svc   <- ZIO.service[AirportCheckpointService]
              ride  <- repo.create(makeInProgressArrivalRide(checkpoint = None))
              _     <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId)
              saved <- repo.findById(ride.id)
              event <- sub.take      // exactly one event
            } yield assertTrue(
              saved.exists(_.airportCheckpoint.contains(AirportCheckpoint.Landed)),
              event.isInstanceOf[WebSocketEvent.AirportCheckpointReached],
              event.asInstanceOf[WebSocketEvent.AirportCheckpointReached].checkpointType == "landed"
            )
          }
        }.provide(layersWithHub),
        test("forward advance Landed → ArrivalsHall succeeds") {
          ZIO.scoped {
            for {
              hub   <- ZIO.service[EventHub]
              sub   <- hub.subscribe
              repo  <- ZIO.service[RideRepository]
              svc   <- ZIO.service[AirportCheckpointService]
              ride  <- repo.create(makeInProgressArrivalRide(checkpoint = Some(AirportCheckpoint.Landed)))
              _     <- svc.markCheckpoint(ride, AirportCheckpoint.ArrivalsHall, clientId)
              saved <- repo.findById(ride.id)
              event <- sub.take
            } yield assertTrue(
              saved.exists(_.airportCheckpoint.contains(AirportCheckpoint.ArrivalsHall)),
              event.asInstanceOf[WebSocketEvent.AirportCheckpointReached].checkpointType == "arrivals_hall"
            )
          }
        }.provide(layersWithHub),
        test("skip-ahead None → TerminalExit allowed, emits EXACTLY ONE event for terminal_exit only") {
          ZIO.scoped {
            for {
              hub    <- ZIO.service[EventHub]
              sub    <- hub.subscribe
              repo   <- ZIO.service[RideRepository]
              svc    <- ZIO.service[AirportCheckpointService]
              ride   <- repo.create(makeInProgressArrivalRide(checkpoint = None))
              _      <- svc.markCheckpoint(ride, AirportCheckpoint.TerminalExit, clientId)
              saved  <- repo.findById(ride.id)
              // take the one event that must exist, then verify no second event was emitted
              event  <- sub.take
              noMore <- sub.poll
            } yield assertTrue(
              saved.exists(_.airportCheckpoint.contains(AirportCheckpoint.TerminalExit)),
              event.asInstanceOf[WebSocketEvent.AirportCheckpointReached].checkpointType == "terminal_exit",
              noMore.isEmpty // exactly one event: no second
            )
          }
        }.provide(layersWithHub),
        test("skip-ahead Landed → TerminalExit allowed, emits exactly one event, ArrivalsHall NOT in repo") {
          ZIO.scoped {
            for {
              hub    <- ZIO.service[EventHub]
              sub    <- hub.subscribe
              repo   <- ZIO.service[RideRepository]
              svc    <- ZIO.service[AirportCheckpointService]
              ride   <- repo.create(makeInProgressArrivalRide(checkpoint = Some(AirportCheckpoint.Landed)))
              _      <- svc.markCheckpoint(ride, AirportCheckpoint.TerminalExit, clientId)
              saved  <- repo.findById(ride.id)
              // take the one event that must exist, then verify no second event was emitted
              event  <- sub.take
              noMore <- sub.poll
            } yield assertTrue(
              // Only TerminalExit stored; ArrivalsHall not back-filled
              saved.exists(_.airportCheckpoint.contains(AirportCheckpoint.TerminalExit)),
              event.asInstanceOf[WebSocketEvent.AirportCheckpointReached].checkpointType == "terminal_exit",
              noMore.isEmpty // exactly one event: ArrivalsHall not emitted
            )
          }
        }.provide(layersWithHub),
        test("same checkpoint repeated (Landed → Landed) returns InvalidOperation") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride   <- repo.create(makeInProgressArrivalRide(checkpoint = Some(AirportCheckpoint.Landed)))
            result <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidOperation])
            case _                   => false
          })
        }.provide(layersWithHub),
        test("backward (ArrivalsHall → Landed) rejected with InvalidOperation") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride   <- repo.create(makeInProgressArrivalRide(checkpoint = Some(AirportCheckpoint.ArrivalsHall)))
            result <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidOperation])
            case _                   => false
          })
        }.provide(layersWithHub),
        test("ride not InProgress rejected with InvalidOperation") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride    = makeInProgressArrivalRide().copy(status = RideStatus.Completed)
            _      <- repo.create(ride)
            result <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidOperation])
            case _                   => false
          })
        }.provide(layersWithHub),
        test("ride not an arrival airport transfer rejected with InvalidOperation") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride    = Ride(
                        id = RideId.generate(),
                        clientId = clientId,
                        creatorId = clientId,
                        companyId = companyId,
                        status = RideStatus.InProgress,
                        pickupLocation = Location("A"),
                        dropoffLocation = Location("B"),
                        pickupDateTime = Instant.now().plusSeconds(3600),
                        specifics = None,
                        flightIsArrival = None
                      )
            _      <- repo.create(ride)
            result <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidOperation])
            case _                   => false
          })
        }.provide(layersWithHub),
        test("airport transfer with isArrival=false in specifics rejected with InvalidOperation") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            // isArrival=false in specifics → isArrivalAirportTransfer=false → InvalidOperation
            ride    = makeInProgressArrivalRide().copy(
                        specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH123", isArrival = false))
                      )
            _      <- repo.create(ride)
            result <- svc.markCheckpoint(ride, AirportCheckpoint.Landed, clientId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidOperation])
            case _                   => false
          })
        }.provide(layersWithHub)
      ),
      suite("checkGeofenceForLanded")(
        test("triggers Landed when client is inside terminal perimeter (< 2000 m)") {
          ZIO.scoped {
            for {
              hub    <- ZIO.service[EventHub]
              sub    <- hub.subscribe
              repo   <- ZIO.service[RideRepository]
              svc    <- ZIO.service[AirportCheckpointService]
              ride   <- repo.create(makeInProgressArrivalRide(checkpoint = None))
              // Exactly the terminal perimeter center — distance == 0
              result <- svc.checkGeofenceForLanded(ride, 48.3537, 11.7860)
              saved  <- repo.findById(ride.id)
              event  <- sub.take
            } yield assertTrue(
              result.contains(AirportCheckpoint.Landed),
              saved.exists(_.airportCheckpoint.contains(AirportCheckpoint.Landed)),
              event.isInstanceOf[WebSocketEvent.AirportCheckpointReached]
            )
          }
        }.provide(layersWithHub),
        test("no-op when client is outside terminal perimeter (> 2000 m)") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride   <- repo.create(makeInProgressArrivalRide(checkpoint = None))
            // Coordinates clearly outside MUC (Munich city center ≈ 30 km away)
            result <- svc.checkGeofenceForLanded(ride, 48.1374, 11.5755)
            saved  <- repo.findById(ride.id)
          } yield assertTrue(
            result.isEmpty,
            saved.exists(_.airportCheckpoint.isEmpty)
          )
        }.provide(layersWithHub),
        test("no-op when Landed already set (idempotent)") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride   <- repo.create(makeInProgressArrivalRide(checkpoint = Some(AirportCheckpoint.Landed)))
            // Inside perimeter, but already landed
            result <- svc.checkGeofenceForLanded(ride, 48.3537, 11.7860)
          } yield assertTrue(result.isEmpty)
        }.provide(layersWithHub),
        test("no-op when ride is not InProgress") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride    = makeInProgressArrivalRide().copy(status = RideStatus.Completed)
            _      <- repo.create(ride)
            result <- svc.checkGeofenceForLanded(ride, 48.3537, 11.7860)
          } yield assertTrue(result.isEmpty)
        }.provide(layersWithHub),
        test("no-op when ride is not an arrival airport transfer") {
          for {
            repo   <- ZIO.service[RideRepository]
            svc    <- ZIO.service[AirportCheckpointService]
            ride    = Ride(
                        id = RideId.generate(),
                        clientId = clientId,
                        creatorId = clientId,
                        companyId = companyId,
                        status = RideStatus.InProgress,
                        pickupLocation = Location("A"),
                        dropoffLocation = Location("B"),
                        pickupDateTime = Instant.now().plusSeconds(3600)
                      )
            _      <- repo.create(ride)
            result <- svc.checkGeofenceForLanded(ride, 48.3537, 11.7860)
          } yield assertTrue(result.isEmpty)
        }.provide(layersWithHub)
      )
    )
}
