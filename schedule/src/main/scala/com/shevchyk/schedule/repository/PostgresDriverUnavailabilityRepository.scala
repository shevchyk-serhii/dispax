package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, DriverUnavailabilityId, PersonId}
import com.shevchyk.schedule.domain.{DriverUnavailability, DriverUnavailabilityReason, ScheduleError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresDriverUnavailabilityRepository(xa: Transactor[Task]) extends DriverUnavailabilityRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val reasonMeta: Meta[DriverUnavailabilityReason] = pgEnumString(
    "driver_unavailability_reason",
    {
      case "Lunch"    => DriverUnavailabilityReason.Lunch
      case "Vacation" => DriverUnavailabilityReason.Vacation
      case "Personal" => DriverUnavailabilityReason.Personal
    },
    {
      case DriverUnavailabilityReason.Lunch    => "Lunch"
      case DriverUnavailabilityReason.Vacation => "Vacation"
      case DriverUnavailabilityReason.Personal => "Personal"
    }
  )

  implicit val unavailabilityRead: Read[DriverUnavailability] =
    Read[
      (UUID, UUID, UUID, Instant, Instant, DriverUnavailabilityReason, Option[String], Instant)
    ].map { case (id, driverId, companyId, fromTime, toTime, reason, note, createdAt) =>
      DriverUnavailability(
        id = DriverUnavailabilityId(id),
        driverId = PersonId(driverId),
        companyId = CompanyId(companyId),
        fromTime = fromTime,
        toTime = toTime,
        reason = reason,
        note = note,
        createdAt = createdAt
      )
    }

  override def create(u: DriverUnavailability): Task[DriverUnavailability] =
    sql"""
      INSERT INTO driver_unavailability (id, driver_id, company_id, from_time, to_time, reason, note, created_at)
      VALUES (
        ${u.id.value}, ${u.driverId.value}, ${u.companyId.value},
        ${u.fromTime}, ${u.toTime}, ${u.reason}, ${u.note}, ${u.createdAt}
      )
    """.update.run
      .transact(xa)
      .mapBoth(_ => ScheduleError.DatabaseError(new RuntimeException("Failed to create unavailability")), _ => u)

  override def findById(id: DriverUnavailabilityId): Task[Option[DriverUnavailability]] =
    sql"""
      SELECT id, driver_id, company_id, from_time, to_time, reason, note, created_at
      FROM driver_unavailability WHERE id = ${id.value}
    """
      .query[DriverUnavailability]
      .option
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByDriver(driverId: PersonId, companyId: CompanyId): Task[List[DriverUnavailability]] =
    sql"""
      SELECT id, driver_id, company_id, from_time, to_time, reason, note, created_at
      FROM driver_unavailability
      WHERE driver_id = ${driverId.value} AND company_id = ${companyId.value}
      ORDER BY from_time ASC
    """
      .query[DriverUnavailability]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findByCompanyAndRange(
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[DriverUnavailability]] =
    sql"""
      SELECT id, driver_id, company_id, from_time, to_time, reason, note, created_at
      FROM driver_unavailability
      WHERE company_id = ${companyId.value}
        AND from_time < $to AND $from < to_time
      ORDER BY from_time ASC
    """
      .query[DriverUnavailability]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def findOverlapping(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[DriverUnavailability]] =
    sql"""
      SELECT id, driver_id, company_id, from_time, to_time, reason, note, created_at
      FROM driver_unavailability
      WHERE driver_id = ${driverId.value} AND company_id = ${companyId.value}
        AND from_time < $to AND $from < to_time
      ORDER BY from_time ASC
    """
      .query[DriverUnavailability]
      .to[List]
      .transact(xa)
      .mapError(ex => ScheduleError.DatabaseError(ex))

  override def delete(id: DriverUnavailabilityId, driverId: PersonId, companyId: CompanyId): Task[Unit] =
    sql"""
      DELETE FROM driver_unavailability
      WHERE id = ${id.value} AND driver_id = ${driverId.value} AND company_id = ${companyId.value}
    """.update.run
      .transact(xa)
      .unit
      .mapError(ex => ScheduleError.DatabaseError(ex))

object PostgresDriverUnavailabilityRepository:

  val layer: ZLayer[Transactor[Task], Nothing, DriverUnavailabilityRepository] = ZLayer.fromFunction(
    PostgresDriverUnavailabilityRepository.apply
  )
