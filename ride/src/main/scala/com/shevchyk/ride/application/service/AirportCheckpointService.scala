package com.shevchyk.ride.application.service

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{PersonId, WebSocketEvent}
import com.shevchyk.ride.domain.{AirportCheckpoint, MucCheckpoints, Ride, RideError, RideStatus}
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
    eventHub: EventHub
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

  override def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]] =
    // Only trigger when:
    //  - ride is an arrival airport transfer
    //  - ride is in progress
    //  - no checkpoint has been reached yet (None = not even landed)
    if !ride.isArrivalAirportTransfer || ride.status != RideStatus.InProgress || ride.airportCheckpoint.isDefined
    then ZIO.succeed(None)
    else
      val distance = haversineDistance(
        lat,
        lon,
        MucCheckpoints.TerminalPerimeterLat,
        MucCheckpoints.TerminalPerimeterLon
      )
      if distance <= MucCheckpoints.TerminalPerimeterRadius
      then
        markCheckpoint(ride, AirportCheckpoint.Landed, ride.clientId)
          .as(Some(AirportCheckpoint.Landed))
          .catchAll(e => ZIO.logWarning(s"Auto-landed trigger failed: $e").as(None))
      else ZIO.succeed(None)

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
      // Forward-only guard (skip-ahead allowed; backward and same-level rejected)
      currentOrdinal   = ride.airportCheckpoint.map(_.ordinal).getOrElse(-1)
      requestedOrdinal = requestedCheckpoint.ordinal
      _               <- ZIO
                           .fail(RideError.InvalidOperation("Checkpoint already passed or at the same level"))
                           .when(requestedOrdinal <= currentOrdinal)
      // Persist
      _               <- rideRepository.updateCheckpoint(ride.id, requestedCheckpoint).mapError(RideError.DatabaseError.apply)
      // Publish event (fire-and-forget; skip-ahead emits exactly one event for the requested checkpoint)
      _               <-
        eventHub
          .publish(
            WebSocketEvent.AirportCheckpointReached(
              rideId = ride.id.value,
              driverId = ride.driverId.map(_.value).getOrElse(java.util.UUID.randomUUID()),
              clientId = ride.clientId.value,
              checkpointType = AirportCheckpoint.toDbString(requestedCheckpoint),
              checkpointName = MucCheckpoints.displayName(requestedCheckpoint),
              companyId = ride.companyId.value
            )
          )
          .ignore
    yield ()

object AirportCheckpointService:

  val layer: ZLayer[RideRepository & EventHub, Nothing, AirportCheckpointService] = ZLayer.fromFunction(
    AirportCheckpointServiceImpl.apply
  )
