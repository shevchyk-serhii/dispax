package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresGeofenceRepository(xa: Transactor[Task]) extends GeofenceRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val geofenceTypeMeta: Meta[GeofenceType] = Meta[String].imap(GeofenceType.valueOf)(_.toString)

  override def create(geofence: Geofence): Task[Geofence] =
    sql"""
      INSERT INTO geofences (id, company_id, name, geofence_type, center_latitude, center_longitude,
                              radius_meters, is_active, notify_on_entry, notify_on_exit, created_at)
      VALUES (${geofence.id.value}, ${geofence.companyId.value}, ${geofence.name},
              ${geofence.geofenceType.toString}, ${geofence.centerLatitude}, ${geofence.centerLongitude},
              ${geofence.radiusMeters}, ${geofence.isActive}, ${geofence.notifyOnEntry},
              ${geofence.notifyOnExit}, ${geofence.createdAt})
    """.update.run
      .transact(xa)
      .as(geofence)

  override def findByCompanyId(companyId: CompanyId): Task[List[Geofence]] =
    sql"""
      SELECT id, company_id, name, geofence_type, center_latitude, center_longitude,
             radius_meters, is_active, notify_on_entry, notify_on_exit, created_at
      FROM geofences WHERE company_id = ${companyId.value}
    """
      .query[Geofence]
      .to[List]
      .transact(xa)

  override def findActiveByCompanyId(companyId: CompanyId): Task[List[Geofence]] =
    sql"""
      SELECT id, company_id, name, geofence_type, center_latitude, center_longitude,
             radius_meters, is_active, notify_on_entry, notify_on_exit, created_at
      FROM geofences WHERE company_id = ${companyId.value} AND is_active = true
    """
      .query[Geofence]
      .to[List]
      .transact(xa)

  override def findById(id: GeofenceId): Task[Option[Geofence]] =
    sql"""
      SELECT id, company_id, name, geofence_type, center_latitude, center_longitude,
             radius_meters, is_active, notify_on_entry, notify_on_exit, created_at
      FROM geofences WHERE id = ${id.value}
    """
      .query[Geofence]
      .option
      .transact(xa)

  override def update(geofence: Geofence): Task[Geofence] =
    sql"""
      UPDATE geofences SET
        name = ${geofence.name}, geofence_type = ${geofence.geofenceType.toString},
        center_latitude = ${geofence.centerLatitude}, center_longitude = ${geofence.centerLongitude},
        radius_meters = ${geofence.radiusMeters}, is_active = ${geofence.isActive},
        notify_on_entry = ${geofence.notifyOnEntry}, notify_on_exit = ${geofence.notifyOnExit}
      WHERE id = ${geofence.id.value}
    """.update.run
      .transact(xa)
      .as(geofence)

  override def delete(id: GeofenceId): Task[Boolean] = sql"""DELETE FROM geofences WHERE id = ${id.value}""".update.run
    .transact(xa)
    .map(_ > 0)

  override def saveAlert(alert: GeofenceAlert): Task[GeofenceAlert] =
    sql"""
      INSERT INTO geofence_alerts (id, geofence_id, driver_id, company_id, alert_type, geofence_name, latitude, longitude, created_at)
      VALUES (${alert.id}, ${alert.geofenceId.value}, ${alert.driverId.value},
              ${alert.companyId.value}, ${alert.alertType}, ${alert.geofenceName},
              ${alert.latitude}, ${alert.longitude}, ${alert.timestamp})
    """.update.run
      .transact(xa)
      .as(alert)

  override def findAlertsByCompany(companyId: CompanyId, limit: Int): Task[List[GeofenceAlert]] =
    sql"""
      SELECT id, geofence_id, driver_id, company_id, alert_type, geofence_name, latitude, longitude, created_at
      FROM geofence_alerts WHERE company_id = ${companyId.value}
      ORDER BY created_at DESC LIMIT $limit
    """
      .query[GeofenceAlert]
      .to[List]
      .transact(xa)

  override def findAlertsByDriver(driverId: PersonId, limit: Int): Task[List[GeofenceAlert]] =
    sql"""
      SELECT id, geofence_id, driver_id, company_id, alert_type, geofence_name, latitude, longitude, created_at
      FROM geofence_alerts WHERE driver_id = ${driverId.value}
      ORDER BY created_at DESC LIMIT $limit
    """
      .query[GeofenceAlert]
      .to[List]
      .transact(xa)

  implicit val geofenceRead: Read[Geofence] =
    Read[(UUID, UUID, String, String, Double, Double, Int, Boolean, Boolean, Boolean, Instant)].map {
      case (
            id,
            companyId,
            name,
            geofenceType,
            centerLat,
            centerLng,
            radius,
            isActive,
            notifyEntry,
            notifyExit,
            createdAt
          ) =>
        Geofence(
          id = GeofenceId(id),
          companyId = CompanyId(companyId),
          name = name,
          geofenceType = GeofenceType.valueOf(geofenceType),
          centerLatitude = centerLat,
          centerLongitude = centerLng,
          radiusMeters = radius,
          isActive = isActive,
          notifyOnEntry = notifyEntry,
          notifyOnExit = notifyExit,
          createdAt = createdAt
        )
    }

  implicit val alertRead: Read[GeofenceAlert] = Read[(UUID, UUID, UUID, UUID, String, String, Double, Double, Instant)]
    .map { case (id, geofenceId, driverId, companyId, alertType, geofenceName, lat, lng, timestamp) =>
      GeofenceAlert(
        id = id,
        geofenceId = GeofenceId(geofenceId),
        driverId = PersonId(driverId),
        companyId = CompanyId(companyId),
        alertType = alertType,
        geofenceName = geofenceName,
        latitude = lat,
        longitude = lng,
        timestamp = timestamp
      )
    }

object PostgresGeofenceRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, GeofenceRepository] = ZLayer.fromFunction(
    PostgresGeofenceRepository(_)
  )
