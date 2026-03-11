package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.{ScheduleDay, ScheduleDayStatus, ScheduleError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

final class PostgresScheduleDayRepository(xa: Transactor[Task]) extends ScheduleDayRepository:

  implicit val scheduleDayStatusMeta: Meta[ScheduleDayStatus] = pgEnumString(
    "schedule_day_status",
    {
      case "Scheduled" => ScheduleDayStatus.Scheduled
      case "Active"    => ScheduleDayStatus.Active
      case "Completed" => ScheduleDayStatus.Completed
      case "Cancelled" => ScheduleDayStatus.Cancelled
    },
    {
      case ScheduleDayStatus.Scheduled => "Scheduled"
      case ScheduleDayStatus.Active    => "Active"
      case ScheduleDayStatus.Completed => "Completed"
      case ScheduleDayStatus.Cancelled => "Cancelled"
    }
  )

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val scheduleDayRead: Read[ScheduleDay] =
    Read[
      (
          UUID,
          UUID,
          UUID,
          LocalDate,
          LocalTime,
          LocalTime,
          ScheduleDayStatus,
          Option[String],
          Instant,
          Instant
      )
    ].map { case (id, driverId, companyId, date, startTime, endTime, status, notes, createdAt, updatedAt) =>
      ScheduleDay(
        id = ScheduleDayId(id),
        driverId = PersonId(driverId),
        companyId = CompanyId(companyId),
        date = date,
        startTime = startTime,
        endTime = endTime,
        status = status,
        notes = notes,
        createdAt = createdAt,
        updatedAt = updatedAt
      )
    }

  override def create(scheduleDay: ScheduleDay): Task[ScheduleDay] =
    sql"""
      INSERT INTO schedule_days (id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at)
      VALUES (
        ${scheduleDay.id.value}, ${scheduleDay.driverId.value}, ${scheduleDay.companyId.value},
        ${scheduleDay.date}, ${scheduleDay.startTime}, ${scheduleDay.endTime},
        ${scheduleDay.status}, ${scheduleDay.notes}, ${scheduleDay.createdAt}, ${scheduleDay.updatedAt}
      )
    """.update.run
      .transact(xa)
      .mapBoth(
        {
          case ex if ex.getMessage != null && ex.getMessage.contains("uq_driver_date") =>
            ScheduleError.DuplicateScheduleDay(scheduleDay.driverId, scheduleDay.date)
          case ex                                                                      => ScheduleError.DatabaseError(ex)
        },
        _ => scheduleDay
      )

  override def findById(id: ScheduleDayId): Task[Option[ScheduleDay]] =
    sql"""
      SELECT id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at
      FROM schedule_days WHERE id = ${id.value}
    """
      .query[ScheduleDay]
      .option
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByDriverId(driverId: PersonId): Task[List[ScheduleDay]] =
    sql"""
      SELECT id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at
      FROM schedule_days WHERE driver_id = ${driverId.value}
      ORDER BY date ASC
    """
      .query[ScheduleDay]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByDriverAndDate(driverId: PersonId, date: LocalDate): Task[Option[ScheduleDay]] =
    sql"""
      SELECT id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at
      FROM schedule_days WHERE driver_id = ${driverId.value} AND date = $date
    """
      .query[ScheduleDay]
      .option
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByCompanyAndDate(companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]] =
    sql"""
      SELECT id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at
      FROM schedule_days WHERE company_id = ${companyId.value} AND date = $date
      ORDER BY start_time ASC
    """
      .query[ScheduleDay]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByCompanyAndDateRange(
      companyId: CompanyId,
      from: LocalDate,
      to: LocalDate
  ): Task[List[ScheduleDay]] =
    sql"""
      SELECT id, driver_id, company_id, date, start_time, end_time, status, notes, created_at, updated_at
      FROM schedule_days WHERE company_id = ${companyId.value} AND date >= $from AND date <= $to
      ORDER BY date ASC, start_time ASC
    """
      .query[ScheduleDay]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def update(scheduleDay: ScheduleDay): Task[ScheduleDay] =
    sql"""
      UPDATE schedule_days SET
        start_time = ${scheduleDay.startTime},
        end_time = ${scheduleDay.endTime},
        status = ${scheduleDay.status},
        notes = ${scheduleDay.notes},
        updated_at = NOW()
      WHERE id = ${scheduleDay.id.value}
    """.update.run
      .transact(xa)
      .as(scheduleDay)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def delete(id: ScheduleDayId): Task[Unit] =
    sql"""DELETE FROM schedule_days WHERE id = ${id.value}""".update.run
      .transact(xa)
      .unit
      .mapError(ex => ScheduleError.DatabaseError(ex))

object PostgresScheduleDayRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ScheduleDayRepository] = ZLayer.fromFunction(
    PostgresScheduleDayRepository.apply
  )
