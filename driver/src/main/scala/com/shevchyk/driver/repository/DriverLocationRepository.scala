package com.shevchyk.driver.repository

import com.shevchyk.core.domain.*
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.core.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait DriverLocationRepository:
  def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit]
  def getLocation(driverId: PersonId): Task[Option[DriverLocation]]
  def updateAvailability(driverId: PersonId, status: String): Task[Unit]
  def getAvailability(driverId: PersonId): Task[Option[String]]
  def findAvailableByCompanyId(companyId: CompanyId): Task[List[(PersonId, String, Option[Double], Option[Double])]]

object DriverLocationRepository:

  val layer: ZLayer[Any, Throwable, DriverLocationRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresDriverLocationRepository.layer
