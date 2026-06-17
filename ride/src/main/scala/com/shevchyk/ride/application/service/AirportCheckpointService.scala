package com.shevchyk.ride.application.service

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{PersonId, WebSocketEvent}
import com.shevchyk.ride.domain.{AirportCheckpoint, MucCheckpoints, Ride, RideError, RideSpecifics, RideStatus}
import com.shevchyk.ride.repository.RideRepository
import zio.*

trait AirportCheckpointService:

  /**
   * Called from ClientLocationService after every client location update. Returns the checkpoint reached if a Landed
   * auto-trigger fired. Always returns UIO — never fails the caller.
   */
  def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]]

  /**
   * Called from the manual-mark endpoint. Forward-only guard: requestedCheckpoint.ordinal must be strictly greater than
   * the current checkpoint ordinal. Skip-ahead is allowed (any forward jump).
   */
  def markCheckpoint(
      ride: Ride,
      requestedCheckpoint: AirportCheckpoint,
      markedBy: PersonId
  ): IO[RideError, Unit]

class AirportCheckpointServiceImpl(
    rideRepository: RideRepository,
    eventHub: EventHub,
    airportConfigService: AirportConfigService
) extends AirportCheckpointService:

  private val EARTH_RADIUS_METERS = 6371000.0

  private def haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double =
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    EARTH_RADIUS_METERS * c

  // Extract the IATA airport code from ride specifics, if this is an airport transfer.
  private def extractAirportCode(ride: Ride): Option[String] = ride.specifics.collect {
    case at: RideSpecifics.AirportTransfer => at.airportCode
  }

  override def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]] =
    // Only trigger when:
    //  - ride is an arrival airport transfer
    //  - ride is in progress
    //  - no checkpoint has been reached yet (None = not even landed)
    if !ride.isArrivalAirportTransfer || ride.status != RideStatus.InProgress || ride.airportCheckpoint.isDefined
    then ZIO.succeed(None)
    else
      // Resolve landing geofence from the configurable AirportConfigService.
      // Falls back gracefully to None when no config is found for the airport code.
      extractAirportCode(ride) match
        case None       => ZIO.succeed(None)
        case Some(code) =>
          airportConfigService
            .getLandingGeofence(code)
            .flatMap {
              case None                                             => ZIO.succeed(None)
              case Some((geofenceLat, geofenceLon, geofenceRadius)) =>
                val distance = haversineDistance(lat, lon, geofenceLat, geofenceLon)
                if distance <= geofenceRadius
                then
                  markCheckpoint(ride, AirportCheckpoint.Landed, ride.clientId)
                    .as(Some(AirportCheckpoint.Landed))
                    .catchAll(e => ZIO.logWarning(s"Auto-landed trigger failed: $e").as(None))
                else ZIO.succeed(None)
            }
            .catchAll(e => ZIO.logWarning(s"Failed to load landing geofence for $code: $e").as(None))

  override def markCheckpoint(
      ride: Ride,
      requestedCheckpoint: AirportCheckpoint,
      markedBy: PersonId
  ): IO[RideError, Unit] =
    for
      // Pre-conditions: must be an in-progress arrival airport transfer
      _               <- ZIO
                           .fail(RideError.InvalidOperation("Checkpoints only apply to in-progress arrival airport transfers"))
                           .when(!ride.isArrivalAirportTransfer || ride.status != RideStatus.InProgress)
      // Fast-fail in-memory pre-check (snapshot ordinal; cheap optimistic guard)
      currentOrdinal   = ride.airportCheckpoint.map(_.ordinal).getOrElse(-1)
      requestedOrdinal = requestedCheckpoint.ordinal
      _               <- ZIO
                           .fail(RideError.InvalidOperation("Checkpoint already passed or at the same level"))
                           .when(requestedOrdinal <= currentOrdinal)
      // Authoritative atomic forward-only guard in the DB (returns false if a concurrent writer already advanced)
      advanced        <- rideRepository.updateCheckpoint(ride.id, requestedCheckpoint).mapError(RideError.DatabaseError.apply)
      _               <- ZIO
                           .fail(RideError.InvalidOperation("Checkpoint already passed or at the same level (concurrent update)"))
                           .when(!advanced)
      // Resolve the display name from the configurable airport config, falling back to the enum name.
      // Uses the airport code from the ride specifics; gracefully defaults when config is unavailable.
      displayName     <-
        extractAirportCode(ride)
          .fold(ZIO.succeed(MucCheckpoints.displayName(requestedCheckpoint))) { code =>
            airportConfigService
              .getCheckpointDisplayName(code, requestedCheckpoint)
              .catchAll(_ => ZIO.succeed(MucCheckpoints.displayName(requestedCheckpoint)))
          }
      // Publish event only when a driverId is present; skip when None to avoid phantom dedup entries
      // and silently-failing FCM pushes to a non-existent recipient.
      _               <-
        ZIO.foreachDiscard(ride.driverId) { did =>
          eventHub
            .publish(
              WebSocketEvent.AirportCheckpointReached(
                rideId = ride.id.value,
                driverId = did.value,
                clientId = ride.clientId.value,
                checkpointType = AirportCheckpoint.toDbString(requestedCheckpoint),
                checkpointName = displayName,
                companyId = ride.companyId.value
              )
            )
            .ignore
        }
    yield ()

object AirportCheckpointService:

  val layer: ZLayer[RideRepository & EventHub & AirportConfigService, Nothing, AirportCheckpointService] = ZLayer
    .fromFunction(AirportCheckpointServiceImpl.apply)
