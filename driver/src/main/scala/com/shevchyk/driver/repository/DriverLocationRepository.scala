package com.shevchyk.driver.repository

import com.shevchyk.core.domain.*
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait DriverLocationRepository:
  def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(driverId: PersonId): Task[Option[DriverLocation]]

object DriverLocationRepository:

  val layer: ZLayer[Any, Throwable, DriverLocationRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresDriverLocationRepository.layer
