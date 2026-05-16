package com.shevchyk.driver.repository

import com.shevchyk.core.domain.*
import com.shevchyk.driver.domain.DriverLocation
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresDriverLocationRepository(xa: Transactor[Task]) extends DriverLocationRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
    sql"""
      UPDATE drivers SET
        current_location_lat = $latitude,
        current_location_lng = $longitude,
        updated_at = NOW()
      WHERE id = ${driverId.value}
    """.update.run
      .transact(xa)
      .flatMap { rowsUpdated =>
        if (rowsUpdated == 0)
          sql"""
            INSERT INTO drivers (id, current_location_lat, current_location_lng, company_id, status)
            SELECT ${driverId.value}, $latitude, $longitude, p.company_id, 'Available'
            FROM persons p WHERE p.id = ${driverId.value}
          """.update.run.transact(xa).unit
        else
          ZIO.unit
      }

  override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] =
    sql"""
      SELECT id, current_location_lat, current_location_lng, updated_at
      FROM drivers
      WHERE id = ${driverId.value}
        AND current_location_lat IS NOT NULL
        AND current_location_lng IS NOT NULL
    """
      .query[(UUID, Double, Double, Instant)]
      .option
      .transact(xa)
      .map(_.map { case (id, lat, lng, updatedAt) => DriverLocation(PersonId(id), lat, lng, updatedAt) })

  override def updateAvailability(driverId: PersonId, status: String): Task[Unit] =
    sql"""
      UPDATE drivers SET status = ${status}::driver_status
      WHERE id = ${driverId.value}
    """.update.run
      .transact(xa)
      .unit

  override def getAvailability(driverId: PersonId): Task[Option[String]] =
    sql"""
      SELECT status::text FROM drivers WHERE id = ${driverId.value}
    """
      .query[String]
      .option
      .transact(xa)

  override def findAvailableByCompanyId(
      companyId: CompanyId
  ): Task[List[(PersonId, String, Option[Double], Option[Double])]] =
    sql"""
      SELECT id, status::text, current_location_lat, current_location_lng
      FROM drivers
      WHERE company_id = ${companyId.value} AND status = 'Available'
    """
      .query[(UUID, String, Option[Double], Option[Double])]
      .to[List]
      .transact(xa)
      .map(_.map { case (id, status, lat, lng) => (PersonId(id), status, lat, lng) })

object PostgresDriverLocationRepository:

  val layer: ZLayer[Transactor[Task], Nothing, DriverLocationRepository] = ZLayer.fromFunction(
    PostgresDriverLocationRepository(_)
  )
