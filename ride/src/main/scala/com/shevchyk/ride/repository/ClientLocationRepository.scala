package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, PersonId}
import com.shevchyk.ride.domain.ClientLocation
import com.shevchyk.core.database.DatabaseConfig
import zio.*

trait ClientLocationRepository:
  def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(rideId: RideId): Task[Option[ClientLocation]]

object ClientLocationRepository:

  val layer: ZLayer[Any, Throwable, ClientLocationRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresClientLocationRepository.layer
