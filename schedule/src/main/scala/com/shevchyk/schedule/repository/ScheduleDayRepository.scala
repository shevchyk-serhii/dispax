package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.schedule.domain.ScheduleDay
import com.shevchyk.core.database.DatabaseConfig
import doobie.Transactor
import zio.*
import java.time.LocalDate

trait ScheduleDayRepository:
  def create(scheduleDay: ScheduleDay): Task[ScheduleDay]

  /**
   * Atomically persists all given schedule days in a single transaction: if any insert fails (e.g. the shift-overlap
   * exclusion constraint fires), NOTHING is committed. Used by batch creation so a mid-batch failure never leaves a
   * partial schedule behind.
   */
  def createAll(scheduleDays: List[ScheduleDay]): Task[List[ScheduleDay]]
  def findById(id: ScheduleDayId): Task[Option[ScheduleDay]]
  def findByDriverId(driverId: PersonId): Task[List[ScheduleDay]]
  def findByDriverAndDate(driverId: PersonId, date: LocalDate): Task[Option[ScheduleDay]]

  /**
   * All schedule days for a driver on a given date within a company. Used for shift-overlap validation in the
   * application layer. Unlike [[findByDriverAndDate]] this returns the full list (not capped at one row), so overlap
   * detection is correct even if the one-shift-per-date DB constraint is ever relaxed.
   */
  def findShiftsForDriverOnDate(driverId: PersonId, companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]]
  def findByCompanyAndDate(companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]]
  def findByCompanyAndDateRange(companyId: CompanyId, from: LocalDate, to: LocalDate): Task[List[ScheduleDay]]
  def update(scheduleDay: ScheduleDay): Task[ScheduleDay]
  // Tenant-scoped delete: only removes the schedule day when it belongs to `companyId`.
  def delete(id: ScheduleDayId, companyId: CompanyId): Task[Unit]

object ScheduleDayRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, ScheduleDayRepository] = ZLayer.fromFunction(
    PostgresScheduleDayRepository.apply
  )

  val layer: ZLayer[Any, Throwable, ScheduleDayRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
