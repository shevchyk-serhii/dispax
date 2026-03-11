package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.schedule.domain.ScheduleDay
import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*
import java.time.LocalDate

trait ScheduleDayRepository:
  def create(scheduleDay: ScheduleDay): Task[ScheduleDay]
  def findById(id: ScheduleDayId): Task[Option[ScheduleDay]]
  def findByDriverId(driverId: PersonId): Task[List[ScheduleDay]]
  def findByDriverAndDate(driverId: PersonId, date: LocalDate): Task[Option[ScheduleDay]]
  def findByCompanyAndDate(companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]]
  def findByCompanyAndDateRange(companyId: CompanyId, from: LocalDate, to: LocalDate): Task[List[ScheduleDay]]
  def update(scheduleDay: ScheduleDay): Task[ScheduleDay]
  def delete(id: ScheduleDayId): Task[Unit]

object ScheduleDayRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, ScheduleDayRepository] = ZLayer.fromFunction(
    PostgresScheduleDayRepository.apply
  )

  val layer: ZLayer[Any, Throwable, ScheduleDayRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
