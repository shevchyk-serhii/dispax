package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.{Instant, LocalTime}
import java.util.UUID

final class PostgresRideTemplateRepository(xa: Transactor[Task]) extends RideTemplateRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val recurrenceMeta: Meta[RecurrencePattern] = Meta[String].imap(RecurrencePattern.valueOf)(_.toString)

  override def create(template: RideTemplate): Task[RideTemplate] =
    sql"""
      INSERT INTO ride_templates (id, company_id, client_id, creator_id, name,
        from_address, from_lat, from_lng, to_address, to_lat, to_lng,
        preferred_driver_id, notes, recurrence_pattern, recurrence_days, pickup_time,
        is_active, flight_number, is_airport_transfer, price, created_at, updated_at)
      VALUES (${template.id.value}, ${template.companyId.value}, ${template.clientId.value},
              ${template.creatorId.value}, ${template.name},
              ${template.fromAddress}, ${template.fromLat}, ${template.fromLng},
              ${template.toAddress}, ${template.toLat}, ${template.toLng},
              ${template.preferredDriverId.map(_.value)}, ${template.notes},
              ${template.recurrencePattern.toString}, ${template.recurrenceDays}, ${template.pickupTime},
              ${template.isActive}, ${template.flightNumber}, ${template.isAirportTransfer},
              ${template.price}, ${template.createdAt}, ${template.updatedAt})
    """.update.run
      .transact(xa)
      .as(template)

  override def findById(id: RideTemplateId): Task[Option[RideTemplate]] =
    sql"""
      SELECT id, company_id, client_id, creator_id, name,
             from_address, from_lat, from_lng, to_address, to_lat, to_lng,
             preferred_driver_id, notes, recurrence_pattern, recurrence_days, pickup_time,
             is_active, flight_number, is_airport_transfer, price, created_at, updated_at
      FROM ride_templates WHERE id = ${id.value}
    """
      .query[RideTemplate]
      .option
      .transact(xa)

  override def findByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] =
    sql"""
      SELECT id, company_id, client_id, creator_id, name,
             from_address, from_lat, from_lng, to_address, to_lat, to_lng,
             preferred_driver_id, notes, recurrence_pattern, recurrence_days, pickup_time,
             is_active, flight_number, is_airport_transfer, price, created_at, updated_at
      FROM ride_templates WHERE company_id = ${companyId.value} ORDER BY created_at
    """
      .query[RideTemplate]
      .to[List]
      .transact(xa)

  override def findActiveByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] =
    sql"""
      SELECT id, company_id, client_id, creator_id, name,
             from_address, from_lat, from_lng, to_address, to_lat, to_lng,
             preferred_driver_id, notes, recurrence_pattern, recurrence_days, pickup_time,
             is_active, flight_number, is_airport_transfer, price, created_at, updated_at
      FROM ride_templates WHERE company_id = ${companyId.value} AND is_active = true ORDER BY created_at
    """
      .query[RideTemplate]
      .to[List]
      .transact(xa)

  override def update(template: RideTemplate): Task[RideTemplate] =
    sql"""
      UPDATE ride_templates SET
        name = ${template.name},
        from_address = ${template.fromAddress}, from_lat = ${template.fromLat}, from_lng = ${template.fromLng},
        to_address = ${template.toAddress}, to_lat = ${template.toLat}, to_lng = ${template.toLng},
        preferred_driver_id = ${template.preferredDriverId.map(_.value)}, notes = ${template.notes},
        recurrence_pattern = ${template.recurrencePattern.toString}, recurrence_days = ${template.recurrenceDays},
        pickup_time = ${template.pickupTime}, is_active = ${template.isActive},
        flight_number = ${template.flightNumber}, is_airport_transfer = ${template.isAirportTransfer},
        price = ${template.price}, updated_at = NOW()
      WHERE id = ${template.id.value}
    """.update.run
      .transact(xa)
      .as(template.copy(updatedAt = Instant.now()))

  override def delete(id: RideTemplateId): Task[Boolean] =
    sql"""DELETE FROM ride_templates WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def deactivate(id: RideTemplateId): Task[Boolean] =
    sql"""UPDATE ride_templates SET is_active = false, updated_at = NOW() WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  implicit val templateRead: Read[RideTemplate] =
    Read[
      (
          UUID,
          UUID,
          UUID,
          UUID,
          String,
          String,
          Option[Double],
          Option[Double],
          String,
          Option[Double],
          Option[Double],
          Option[UUID],
          Option[String],
          String,
          Option[String],
          LocalTime,
          Boolean,
          Option[String],
          Boolean,
          Option[BigDecimal],
          Instant,
          Instant
      )
    ].map {
      case (
            id,
            companyId,
            clientId,
            creatorId,
            name,
            fromAddress,
            fromLat,
            fromLng,
            toAddress,
            toLat,
            toLng,
            preferredDriverId,
            notes,
            recurrencePattern,
            recurrenceDays,
            pickupTime,
            isActive,
            flightNumber,
            isAirportTransfer,
            price,
            createdAt,
            updatedAt
          ) =>
        RideTemplate(
          id = RideTemplateId(id),
          companyId = CompanyId(companyId),
          clientId = PersonId(clientId),
          creatorId = PersonId(creatorId),
          name = name,
          fromAddress = fromAddress,
          fromLat = fromLat,
          fromLng = fromLng,
          toAddress = toAddress,
          toLat = toLat,
          toLng = toLng,
          preferredDriverId = preferredDriverId.map(PersonId.apply),
          notes = notes,
          recurrencePattern = RecurrencePattern.valueOf(recurrencePattern),
          recurrenceDays = recurrenceDays,
          pickupTime = pickupTime,
          isActive = isActive,
          flightNumber = flightNumber,
          isAirportTransfer = isAirportTransfer,
          price = price,
          createdAt = createdAt,
          updatedAt = updatedAt
        )
    }

object PostgresRideTemplateRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideTemplateRepository] = ZLayer.fromFunction(
    PostgresRideTemplateRepository(_)
  )
