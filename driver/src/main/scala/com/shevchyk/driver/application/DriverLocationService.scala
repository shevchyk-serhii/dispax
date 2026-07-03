package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, GeofenceService, ActiveRideInfo}
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.ride.domain.RideStatus
import com.shevchyk.ride.repository.RideRepository
import zio.*
import java.time.Instant

trait DriverLocationService:
  def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(driverId: PersonId): Task[Option[DriverLocation]]
  def updateAvailability(driverId: PersonId, status: String): Task[Unit]
  def getAvailability(driverId: PersonId): Task[Option[String]]
  def getAvailableDrivers(companyId: CompanyId): Task[List[com.shevchyk.driver.infrastructure.http.AvailableDriverDto]]

class DriverLocationServiceImpl(
    repository: DriverLocationRepository,
    eventHub: EventHub,
    geofenceService: GeofenceService,
    rideRepository: RideRepository,
    personRepository: PersonRepository
) extends DriverLocationService:

  override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
    for {
      _           <- validateCoordinates(latitude, longitude)
      _           <- repository.updateLocation(driverId, latitude, longitude)
      personOpt   <- personRepository.findById(driverId)
      companyIdOpt = personOpt.flatMap(_.companyId)
      _           <-
        companyIdOpt match
          case Some(companyId) =>
            eventHub
              .publish(
                WebSocketEvent.LocationUpdated(
                  rideId = None,
                  userId = driverId.value,
                  latitude = latitude,
                  longitude = longitude,
                  locationType = "driver",
                  companyId = companyId.value
                )
              )
              .ignore
          case None            => ZIO.unit
      _           <- checkGeofences(driverId, companyIdOpt, latitude, longitude).forkDaemon
    } yield ()

  /**
   * Rejects out-of-range coordinates before they reach the DB / Haversine math.
   */
  private def validateCoordinates(latitude: Double, longitude: Double): Task[Unit] =
    ZIO
      .fail(new IllegalArgumentException(s"Latitude out of range [-90, 90]: $latitude"))
      .when(latitude < -90.0 || latitude > 90.0) *>
      ZIO
        .fail(new IllegalArgumentException(s"Longitude out of range [-180, 180]: $longitude"))
        .when(longitude < -180.0 || longitude > 180.0)
        .unit

  private def checkGeofences(
      driverId: PersonId,
      companyIdOpt: Option[CompanyId],
      latitude: Double,
      longitude: Double
  ): UIO[Unit] =
    val effect: Task[Unit] =
      for {
        // Zone entry/exit alerts only need the driver's company geofences. The company comes
        // from the driver's Person row (already resolved by updateLocation) — NOT from ride
        // history, so a driver on shift without any rides still triggers enter/exit alerts.
        _           <-
          companyIdOpt match
            case Some(companyId) => geofenceService.checkDriverLocation(driverId, companyId, latitude, longitude).unit
            case None            => ZIO.unit
        // Client-proximity alerts are per active ride — only meaningful when the driver has some.
        driverRides <- rideRepository.findByDriverId(driverId)
        activeRides  = driverRides
                         .filter(r => r.status == RideStatus.Assigned || r.status == RideStatus.InProgress)
                         .map(r =>
                           ActiveRideInfo(
                             rideId = r.id.value,
                             clientId = r.clientId.value,
                             pickupLatitude = r.pickupLocation.latitude,
                             pickupLongitude = r.pickupLocation.longitude,
                             companyId = r.companyId.value
                           )
                         )
        _           <-
          ZIO.unless(activeRides.isEmpty)(
            geofenceService.checkClientProximity(driverId, latitude, longitude, activeRides)
          )
      } yield ()
    effect.catchAll(e => ZIO.logWarning(s"Geofence check error: ${Option(e.getMessage).getOrElse(e.toString)}"))

  override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] = repository.getLocation(driverId)

  override def updateAvailability(driverId: PersonId, status: String): Task[Unit] = repository.updateAvailability(
    driverId,
    status
  )

  override def getAvailability(driverId: PersonId): Task[Option[String]] = repository.getAvailability(driverId)

  override def getAvailableDrivers(
      companyId: CompanyId
  ): Task[List[com.shevchyk.driver.infrastructure.http.AvailableDriverDto]] = repository
    .findAvailableByCompanyId(companyId)
    .map(_.map { case (id, status, lat, lng) =>
      com.shevchyk.driver.infrastructure.http.AvailableDriverDto(
        id = id.value.toString,
        status = status,
        latitude = lat,
        longitude = lng
      )
    })

object DriverLocationService:

  val layer
      : ZLayer[DriverLocationRepository & EventHub & GeofenceService & RideRepository & PersonRepository, Nothing, DriverLocationService] =
    ZLayer.fromFunction(DriverLocationServiceImpl.apply)

  val providerLayer: ZLayer[DriverLocationRepository, Nothing, DriverLocationProvider] = ZLayer.fromFunction {
    (repo: DriverLocationRepository) =>
      new DriverLocationProvider:
        override def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]] = repo
          .getLocation(driverId)
          .map(_.map(dl => (dl.latitude, dl.longitude, dl.updatedAt)))
  }
