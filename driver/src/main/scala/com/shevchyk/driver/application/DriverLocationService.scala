package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import zio.*

trait DriverLocationService:
  def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(driverId: PersonId): Task[Option[DriverLocation]]

class DriverLocationServiceImpl(
    repository: DriverLocationRepository
) extends DriverLocationService:

  override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] = repository
    .updateLocation(driverId, latitude, longitude)

  override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] = repository.getLocation(driverId)

object DriverLocationService:

  val layer: ZLayer[DriverLocationRepository, Nothing, DriverLocationService] = ZLayer.fromFunction(
    DriverLocationServiceImpl(_)
  )
