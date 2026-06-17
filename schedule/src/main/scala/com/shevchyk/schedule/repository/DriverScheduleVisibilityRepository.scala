package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.schedule.domain.DriverScheduleVisibility
import doobie.Transactor
import zio.*

trait DriverScheduleVisibilityRepository:
  def findByDriver(driverId: PersonId): Task[Option[DriverScheduleVisibility]]
  def upsert(visibility: DriverScheduleVisibility): Task[DriverScheduleVisibility]
  def findByCompany(companyId: CompanyId): Task[List[DriverScheduleVisibility]]

object DriverScheduleVisibilityRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, DriverScheduleVisibilityRepository] = ZLayer.fromFunction(
    PostgresDriverScheduleVisibilityRepository.apply
  )

  val layer: ZLayer[Any, Throwable, DriverScheduleVisibilityRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
