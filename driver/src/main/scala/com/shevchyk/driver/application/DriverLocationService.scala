package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.EventHub
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import zio.*
import java.time.Instant

trait DriverLocationService:
  def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(driverId: PersonId): Task[Option[DriverLocation]]

class DriverLocationServiceImpl(
    repository: DriverLocationRepository,
    eventHub: EventHub
) extends DriverLocationService:

  override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
    for {
      _ <- repository.updateLocation(driverId, latitude, longitude)
      _ <-
        eventHub
          .publish(
            WebSocketEvent.LocationUpdated(
              rideId = None,
              userId = driverId.value,
              latitude = latitude,
              longitude = longitude,
              locationType = "driver",
              companyId = java.util.UUID.randomUUID() // driver location events filtered by subscriber
            )
          )
          .ignore
    } yield ()

  override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] = repository.getLocation(driverId)

object DriverLocationService:

  val layer: ZLayer[DriverLocationRepository & EventHub, Nothing, DriverLocationService] = ZLayer.fromFunction(
    DriverLocationServiceImpl.apply
  )

  val providerLayer: ZLayer[DriverLocationRepository, Nothing, DriverLocationProvider] = ZLayer.fromFunction {
    (repo: DriverLocationRepository) =>
      new DriverLocationProvider:
        override def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]] = repo
          .getLocation(driverId)
          .map(_.map(dl => (dl.latitude, dl.longitude, dl.updatedAt)))
  }
