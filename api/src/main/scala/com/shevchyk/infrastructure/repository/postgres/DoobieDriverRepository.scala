package com.shevchyk.infrastructure.repository.postgres

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

case class DoobieDriverRepository(xa: Transactor[Task]) extends DriverRepository:

  implicit val driverStatusMeta: Meta[DriverStatus] = Meta[String].timap(s => DriverStatus.valueOf(s))(_.toString)

  implicit val personIdMeta: Meta[PersonId] = Meta[Int].timap(PersonId.apply)(_.value)

  implicit val companyIdMeta: Meta[CompanyId] = Meta[Int].timap(CompanyId.apply)(_.value)

  def findById(id: PersonId): IO[RepositoryError, Option[Driver]] =
    val selectSql =
      sql"""
      SELECT d.id, p.name, d.current_location_address, d.current_location_lat, 
             d.current_location_lng, d.status, d.company_id
      FROM drivers d
      JOIN persons p ON d.id = p.id
      WHERE d.id = $id
    """

    selectSql
      .query[DriverRow]
      .option
      .transact(xa)
      .map(_.map(toDriver))
      .mapError(RepositoryError.DatabaseError.apply)

  def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]] =
    val radiusKm = radius.kilometers
    val lat      = location.latitude.getOrElse(0.0)
    val lng      = location.longitude.getOrElse(0.0)

    val selectSql =
      sql"""
      SELECT d.id, p.name, d.current_location_address, d.current_location_lat, 
             d.current_location_lng, d.status, d.company_id
      FROM drivers d
      JOIN persons p ON d.id = p.id
      WHERE d.status = 'Available'
        AND d.current_location_lat IS NOT NULL 
        AND d.current_location_lng IS NOT NULL
        AND (
          6371 * acos(
            cos(radians($lat)) * cos(radians(d.current_location_lat)) *
            cos(radians(d.current_location_lng) - radians($lng)) +
            sin(radians($lat)) * sin(radians(d.current_location_lat))
          )
        ) <= $radiusKm
      ORDER BY (
        6371 * acos(
          cos(radians($lat)) * cos(radians(d.current_location_lat)) *
          cos(radians(d.current_location_lng) - radians($lng)) +
          sin(radians($lat)) * sin(radians(d.current_location_lat))
        )
      ) ASC
    """

    selectSql
      .query[DriverRow]
      .to[List]
      .transact(xa)
      .map(_.map(toDriver))
      .mapError(RepositoryError.DatabaseError.apply)

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]] =
    val selectSql =
      sql"""
      SELECT d.id, p.name, d.current_location_address, d.current_location_lat, 
             d.current_location_lng, d.status, d.company_id
      FROM drivers d
      JOIN persons p ON d.id = p.id
      WHERE d.company_id = $companyId
      ORDER BY p.name
    """

    selectSql
      .query[DriverRow]
      .to[List]
      .transact(xa)
      .map(_.map(toDriver))
      .mapError(RepositoryError.DatabaseError.apply)

  def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit] =
    sql"UPDATE drivers SET status = $status WHERE id = $driverId".update.run
      .transact(xa)
      .flatMap {
        case 1 => ZIO.unit
        case 0 => ZIO.fail(RepositoryError.NotFound(driverId.value.toString))
        case n => ZIO.fail(RepositoryError.DatabaseError(new Exception(s"Update affected $n rows, expected 1")))
      }
      .mapError {
        case e: RepositoryError => e
        case t                  => RepositoryError.DatabaseError(t)
      }

  def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit] =
    val updateSql =
      sql"""
      UPDATE drivers SET 
        current_location_address = ${location.address},
        current_location_lat = ${location.latitude},
        current_location_lng = ${location.longitude}
      WHERE id = $driverId
    """

    updateSql.update.run
      .transact(xa)
      .flatMap {
        case 1 => ZIO.unit
        case 0 => ZIO.fail(RepositoryError.NotFound(driverId.value.toString))
        case n => ZIO.fail(RepositoryError.DatabaseError(new Exception(s"Update affected $n rows, expected 1")))
      }
      .mapError {
        case e: RepositoryError => e
        case t                  => RepositoryError.DatabaseError(t)
      }

  def save(driver: Driver): IO[RepositoryError, Driver] =
    val upsertSql =
      sql"""
      INSERT INTO drivers (id, current_location_address, current_location_lat, 
                          current_location_lng, status, company_id)
      VALUES (${driver.id}, ${driver.currentLocation.address}, 
              ${driver.currentLocation.latitude}, ${driver.currentLocation.longitude},
              ${driver.status}, ${driver.companyId})
      ON CONFLICT (id) DO UPDATE SET
        current_location_address = EXCLUDED.current_location_address,
        current_location_lat = EXCLUDED.current_location_lat,
        current_location_lng = EXCLUDED.current_location_lng,
        status = EXCLUDED.status,
        company_id = EXCLUDED.company_id
    """

    upsertSql.update.run
      .transact(xa)
      .map(_ => driver)
      .mapError(RepositoryError.DatabaseError.apply)

  private case class DriverRow(
      id: PersonId,
      name: String,
      currentLocationAddress: Option[String],
      currentLocationLat: Option[Double],
      currentLocationLng: Option[Double],
      status: DriverStatus,
      companyId: CompanyId
  )

  private def toDriver(row: DriverRow): Driver = Driver(
    id = row.id,
    name = row.name,
    currentLocation = Location(
      address = row.currentLocationAddress.getOrElse("Unknown"),
      latitude = row.currentLocationLat,
      longitude = row.currentLocationLng
    ),
    status = row.status,
    companyId = row.companyId
  )
