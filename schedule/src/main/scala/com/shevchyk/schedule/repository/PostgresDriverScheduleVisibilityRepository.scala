package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.schedule.domain.{DriverScheduleVisibility, ScheduleError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, OffsetDateTime, ZoneOffset}
import java.util.UUID

final class PostgresDriverScheduleVisibilityRepository(xa: Transactor[Task]) extends DriverScheduleVisibilityRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[OffsetDateTime].imap(_.toInstant)(instant => OffsetDateTime.ofInstant(instant, ZoneOffset.UTC))

  implicit val visibilityRead: Read[DriverScheduleVisibility] = Read[(UUID, UUID, Boolean, Instant)].map {
    case (driverId, companyId, canView, updatedAt) =>
      DriverScheduleVisibility(
        driverId = PersonId(driverId),
        companyId = CompanyId(companyId),
        canViewOtherSchedules = canView,
        updatedAt = updatedAt
      )
  }

  override def findByDriver(driverId: PersonId): Task[Option[DriverScheduleVisibility]] =
    sql"""
      SELECT driver_id, company_id, can_view_other_schedules, updated_at
      FROM driver_schedule_visibility
      WHERE driver_id = ${driverId.value}
    """
      .query[DriverScheduleVisibility]
      .option
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def upsert(visibility: DriverScheduleVisibility): Task[DriverScheduleVisibility] =
    sql"""
      INSERT INTO driver_schedule_visibility (driver_id, company_id, can_view_other_schedules, updated_at)
      VALUES (
        ${visibility.driverId.value},
        ${visibility.companyId.value},
        ${visibility.canViewOtherSchedules},
        NOW()
      )
      ON CONFLICT (driver_id) DO UPDATE SET
        can_view_other_schedules = EXCLUDED.can_view_other_schedules,
        updated_at = NOW()
    """.update.run
      .transact(xa)
      .as(visibility)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByCompany(companyId: CompanyId): Task[List[DriverScheduleVisibility]] =
    sql"""
      SELECT driver_id, company_id, can_view_other_schedules, updated_at
      FROM driver_schedule_visibility
      WHERE company_id = ${companyId.value}
    """
      .query[DriverScheduleVisibility]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

object PostgresDriverScheduleVisibilityRepository:

  val layer: ZLayer[Transactor[Task], Nothing, DriverScheduleVisibilityRepository] = ZLayer.fromFunction(
    PostgresDriverScheduleVisibilityRepository.apply
  )
