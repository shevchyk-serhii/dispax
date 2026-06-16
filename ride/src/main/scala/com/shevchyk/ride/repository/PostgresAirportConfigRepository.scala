package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
import doobie.*
import doobie.implicits.*
import doobie.implicits.javasql.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, OffsetDateTime, ZoneOffset}
import java.util.UUID

/**
 * PostgreSQL implementation of [[AirportConfigRepository]].
 *
 * DESIGN NOTE: No company_id filter in any query — airports are intentionally global (cross-tenant) configuration data.
 * The access-control substitute is the `requireSuperAdmin(user)` gate in
 * [[com.shevchyk.app.openapi.SuperAdminAirportApi]]. This is equivalent to the `countAllRidesByStatus` and other
 * platform-level methods in [[PostgresRideRepository]].
 *
 * Two-query approach for loading zones: a JOIN produces duplicate airport columns for each zone row, so we load
 * airports first and zones second, then assemble in-process with a groupBy.
 */
final class PostgresAirportConfigRepository(xa: Transactor[Task]) extends AirportConfigRepository:

  implicit private val instantMeta: Meta[Instant] =
    Meta[OffsetDateTime].imap(_.toInstant)((i: Instant) => i.atOffset(ZoneOffset.UTC))

  // ---------------------------------------------------------------------------
  // Airport rows
  // ---------------------------------------------------------------------------

  private type AirportRow = (String, String, String, Double, Double, Int, Boolean, Instant, Instant)

  private val airportCols =
    fr"code, name, country, landing_lat, landing_lon, landing_radius, is_active, created_at, updated_at"

  private def rowToAirport(row: AirportRow, zones: List[AirportCheckpointZone]): Airport = Airport(
    code = row._1,
    name = row._2,
    country = row._3,
    landingLat = row._4,
    landingLon = row._5,
    landingRadius = row._6,
    isActive = row._7,
    zones = zones,
    createdAt = row._8,
    updatedAt = row._9
  )

  // ---------------------------------------------------------------------------
  // Zone rows
  // ---------------------------------------------------------------------------

  private type ZoneRow = (UUID, String, String, String, String, Double, Double, Int, Int, Instant, Instant)

  private val zoneCols =
    fr"id, airport_code, terminal_code, checkpoint_type, display_name, lat, lon, radius_meters, sort_order, created_at, updated_at"

  private def rowToZone(row: ZoneRow): AirportCheckpointZone = AirportCheckpointZone(
    id = row._1,
    airportCode = row._2,
    terminalCode = row._3,
    checkpointType = row._4,
    displayName = row._5,
    lat = row._6,
    lon = row._7,
    radiusMeters = row._8,
    sortOrder = row._9,
    createdAt = row._10,
    updatedAt = row._11
  )

  private def loadZonesForAirport(code: String): ConnectionIO[List[AirportCheckpointZone]] =
    (fr"SELECT" ++ zoneCols ++
      fr"FROM airport_checkpoint_zones WHERE airport_code = $code ORDER BY sort_order")
      .query[ZoneRow]
      .to[List]
      .map(_.map(rowToZone))

  private def loadZonesForAll(): ConnectionIO[Map[String, List[AirportCheckpointZone]]] =
    (fr"SELECT" ++ zoneCols ++
      fr"FROM airport_checkpoint_zones ORDER BY airport_code, sort_order")
      .query[ZoneRow]
      .to[List]
      .map(_.map(rowToZone).groupBy(_.airportCode))

  // ---------------------------------------------------------------------------
  // Repository methods
  // ---------------------------------------------------------------------------

  override def findAll(): Task[List[Airport]] =
    (for
      rows <- (fr"SELECT" ++ airportCols ++ fr"FROM airports ORDER BY code")
                .query[AirportRow]
                .to[List]
      zMap <- loadZonesForAll()
    yield rows.map(r => rowToAirport(r, zMap.getOrElse(r._1, Nil))))
      .transact(xa)

  override def findByCode(code: String): Task[Option[Airport]] =
    (for
      rowOpt <-
        (fr"SELECT" ++ airportCols ++ fr"FROM airports WHERE code = $code")
          .query[AirportRow]
          .option
      result <-
        rowOpt match
          case None      => doobie.free.connection.pure(None)
          case Some(row) => loadZonesForAirport(code).map(z => Some(rowToAirport(row, z)))
    yield result)
      .transact(xa)

  override def create(airport: Airport): Task[Airport] =
    sql"""
      INSERT INTO airports
        (code, name, country, landing_lat, landing_lon, landing_radius, is_active)
      VALUES
        (${airport.code}, ${airport.name}, ${airport.country},
         ${airport.landingLat}, ${airport.landingLon}, ${airport.landingRadius}, ${airport.isActive})
    """.update.run
      .transact(xa)
      .zipRight(findByCode(airport.code))
      .flatMap(
        ZIO.fromOption(_).orElseFail(new RuntimeException(s"Failed to create airport ${airport.code}"))
      )

  override def update(code: String, airport: Airport): Task[Option[Airport]] =
    sql"""
      UPDATE airports SET
        name           = ${airport.name},
        country        = ${airport.country},
        landing_lat    = ${airport.landingLat},
        landing_lon    = ${airport.landingLon},
        landing_radius = ${airport.landingRadius},
        is_active      = ${airport.isActive},
        updated_at     = NOW()
      WHERE code = $code
    """.update.run
      .transact(xa)
      .flatMap(n => if n > 0 then findByCode(code) else ZIO.succeed(None))

  override def delete(code: String): Task[Boolean] =
    sql"""
      UPDATE airports SET is_active = FALSE, updated_at = NOW() WHERE code = $code AND is_active = TRUE
    """.update.run
      .transact(xa)
      .map(_ > 0)

  override def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone] =
    sql"""
      INSERT INTO airport_checkpoint_zones
        (airport_code, terminal_code, checkpoint_type, display_name, lat, lon, radius_meters, sort_order)
      VALUES
        (${zone.airportCode}, ${zone.terminalCode}, ${zone.checkpointType}, ${zone.displayName},
         ${zone.lat}, ${zone.lon}, ${zone.radiusMeters}, ${zone.sortOrder})
      RETURNING id, airport_code, terminal_code, checkpoint_type, display_name,
                lat, lon, radius_meters, sort_order, created_at, updated_at
    """
      .query[ZoneRow]
      .unique
      .transact(xa)
      .map(rowToZone)

  override def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] =
    sql"""
      UPDATE airport_checkpoint_zones SET
        terminal_code   = ${zone.terminalCode},
        checkpoint_type = ${zone.checkpointType},
        display_name    = ${zone.displayName},
        lat             = ${zone.lat},
        lon             = ${zone.lon},
        radius_meters   = ${zone.radiusMeters},
        sort_order      = ${zone.sortOrder},
        updated_at      = NOW()
      WHERE id = $id
      RETURNING id, airport_code, terminal_code, checkpoint_type, display_name,
                lat, lon, radius_meters, sort_order, created_at, updated_at
    """
      .query[ZoneRow]
      .option
      .transact(xa)
      .map(_.map(rowToZone))

  override def deleteZone(id: UUID): Task[Boolean] = sql"DELETE FROM airport_checkpoint_zones WHERE id = $id".update.run
    .transact(xa)
    .map(_ > 0)

object PostgresAirportConfigRepository:

  val layer: ZLayer[Transactor[Task], Nothing, AirportConfigRepository] = ZLayer.fromFunction(
    PostgresAirportConfigRepository.apply
  )
