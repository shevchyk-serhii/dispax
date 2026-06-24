package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.{PersonId, RideId, DriverLocationProvider, WebSocketEvent}
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.domain.RideError
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.{ClientLocationRepository, RideRepository}
import zio.*
import zio.json.*
import java.time.Instant

final case class LocationWithTimestamp(
    latitude: Double,
    longitude: Double,
    updatedAt: Instant
) derives JsonCodec

final case class RideLocationsResponse(
    driverLocation: Option[LocationWithTimestamp],
    clientLocation: Option[LocationWithTimestamp]
) derives JsonCodec

trait ClientLocationService:
  def updateClientLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): IO[RideError, Unit]
  def getRideLocations(rideId: RideId): IO[RideError, RideLocationsResponse]

class ClientLocationServiceImpl(
    clientLocationRepository: ClientLocationRepository,
    rideRepository: RideRepository,
    driverLocationProvider: DriverLocationProvider,
    eventHub: EventHub,
    airportCheckpointService: AirportCheckpointService
) extends ClientLocationService:

  override def updateClientLocation(
      rideId: RideId,
      clientId: PersonId,
      latitude: Double,
      longitude: Double
  ): IO[RideError, Unit] =
    for {
      _    <- validateCoordinates(latitude, longitude)
      ride <- rideRepository.findById(rideId).mapDatabaseError.flatMap {
                case Some(r) => ZIO.succeed(r)
                case None    => ZIO.fail(RideError.RideNotFound(rideId))
              }
      _    <-
        ZIO
          .fail(RideError.UnauthorizedAccess(clientId, rideId))
          .when(ride.clientId != clientId)
          .unit
      _    <- clientLocationRepository.updateLocation(rideId, clientId, latitude, longitude).mapDatabaseError
      _    <-
        eventHub
          .publish(
            WebSocketEvent.LocationUpdated(
              rideId = Some(rideId.value),
              userId = clientId.value,
              latitude = latitude,
              longitude = longitude,
              locationType = "client",
              companyId = ride.companyId.value
            )
          )
          .ignore
      // Best-effort: check if client just entered the terminal perimeter (auto-Landed trigger)
      _    <- airportCheckpointService.checkGeofenceForLanded(ride, latitude, longitude).ignore
    } yield ()

  /**
   * Rejects out-of-range coordinates before they reach the DB / Haversine math.
   */
  private def validateCoordinates(latitude: Double, longitude: Double): IO[RideError, Unit] =
    if latitude < -90.0 || latitude > 90.0 then
      ZIO.fail(RideError.ValidationError(s"Latitude out of range [-90, 90]: $latitude"))
    else if longitude < -180.0 || longitude > 180.0 then
      ZIO.fail(RideError.ValidationError(s"Longitude out of range [-180, 180]: $longitude"))
    else ZIO.unit

  override def getRideLocations(rideId: RideId): IO[RideError, RideLocationsResponse] =
    for {
      ride      <- rideRepository.findById(rideId).mapDatabaseError.flatMap {
                     case Some(r) => ZIO.succeed(r)
                     case None    => ZIO.fail(RideError.RideNotFound(rideId))
                   }
      clientLoc <- clientLocationRepository.getLocation(rideId).mapDatabaseError
      driverLoc <-
        ride.driverId match
          case Some(driverId) =>
            driverLocationProvider
              .getDriverLocation(driverId)
              .mapError(ex => RideError.DatabaseError(ex))
          case None           => ZIO.none
    } yield RideLocationsResponse(
      driverLocation = driverLoc.map { case (lat, lng, ts) => LocationWithTimestamp(lat, lng, ts) },
      clientLocation = clientLoc.map(cl => LocationWithTimestamp(cl.latitude, cl.longitude, cl.updatedAt))
    )

object ClientLocationService:

  val layer
      : ZLayer[ClientLocationRepository & RideRepository & DriverLocationProvider & EventHub & AirportCheckpointService, Nothing, ClientLocationService] =
    ZLayer.fromFunction(ClientLocationServiceImpl.apply)
