package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, GeofenceService, ActiveRideInfo}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.ride.domain.{Ride, RideStatus}
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
    rideRepository: RideRepository
) extends DriverLocationService:

  override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
    for {
      _           <- repository.updateLocation(driverId, latitude, longitude)
      driverRides <- rideRepository.findByDriverId(driverId)
      companyIdOpt = driverRides.headOption.map(_.companyId)
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
      _           <- checkGeofences(driverId, latitude, longitude).forkDaemon
    } yield ()

  private def checkGeofences(driverId: PersonId, latitude: Double, longitude: Double): UIO[Unit] =
    val effect: Task[Unit] =
      for {
        // Try to determine driver's company from their active rides or location data
        driverRides <- rideRepository.findByDriverId(driverId)
        companyIdOpt = driverRides.headOption.map(_.companyId)
        _           <-
          companyIdOpt match
            case Some(companyId) =>
              geofenceService.checkDriverLocation(driverId, companyId, latitude, longitude).unit *> {
                val activeRides = driverRides
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
                geofenceService.checkClientProximity(driverId, latitude, longitude, activeRides)
              }
            case None            => ZIO.unit
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
      : ZLayer[DriverLocationRepository & EventHub & GeofenceService & RideRepository, Nothing, DriverLocationService] =
    ZLayer.fromFunction(DriverLocationServiceImpl.apply)

  val providerLayer: ZLayer[DriverLocationRepository, Nothing, DriverLocationProvider] = ZLayer.fromFunction {
    (repo: DriverLocationRepository) =>
      new DriverLocationProvider:
        override def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]] = repo
          .getLocation(driverId)
          .map(_.map(dl => (dl.latitude, dl.longitude, dl.updatedAt)))
  }
