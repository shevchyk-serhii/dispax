package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.{Airport, AirportCheckpoint, AirportCheckpointZone, RideError}
import com.shevchyk.ride.repository.AirportConfigRepository
import zio.*

import java.util.UUID

/**
 * Application service for airport configuration CRUD.
 *
 * Provides a read-through in-memory cache (backed by a [[Ref]]) so that [[AirportCheckpointService]] can look up
 * geofence coordinates on every location update without hitting PostgreSQL each time. The cache is invalidated on every
 * write operation.
 *
 * DESIGN NOTE: No `CompanyId` parameter in any method. Airports are intentionally global (cross-tenant). Access control
 * is enforced exclusively at the HTTP layer via `requireSuperAdmin(user)` in
 * [[com.shevchyk.app.openapi.SuperAdminAirportApi]].
 */
trait AirportConfigService:
  def listAirports(): Task[List[Airport]]
  def getAirport(code: String): Task[Option[Airport]]
  def createAirport(airport: Airport): Task[Airport]
  def updateAirport(code: String, airport: Airport): Task[Option[Airport]]
  def deleteAirport(code: String): Task[Boolean]
  def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone]
  def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]]
  def deleteZone(id: UUID): Task[Boolean]

  /**
   * Used internally by [[AirportCheckpointService]] — returns None when airport not found or inactive.
   */
  def getLandingGeofence(airportCode: String): Task[Option[(Double, Double, Int)]]

  /**
   * Returns the display name for a checkpoint from the DB config, falling back to enum name.
   */
  def getCheckpointDisplayName(airportCode: String, checkpoint: AirportCheckpoint): Task[String]

object AirportConfigService:

  val layer: ZLayer[AirportConfigRepository, Nothing, AirportConfigService] = ZLayer {
    for
      repo  <- ZIO.service[AirportConfigRepository]
      cache <- Ref.make(Map.empty[String, Airport])
    yield AirportConfigServiceImpl(repo, cache)
  }

final private class AirportConfigServiceImpl(
    repo: AirportConfigRepository,
    // Cache: keyed by IATA airport code, only active airports.
    // Populated lazily on first read; invalidated on any write.
    cache: Ref[Map[String, Airport]]
) extends AirportConfigService:

  // Populate cache from DB if empty, then return it.
  private def cachedAll(): Task[Map[String, Airport]] = cache.get.flatMap { m =>
    if m.nonEmpty then ZIO.succeed(m)
    else
      repo
        .findAll()
        .flatMap { airports =>
          val activeMap = airports.filter(_.isActive).map(a => a.code -> a).toMap
          cache.set(activeMap).as(activeMap)
        }
  }

  private def invalidate(): UIO[Unit] = cache.set(Map.empty)

  // ─── Shared coordinate / type validation (application layer) ──────────────
  // Fails with RideError.ValidationError so the HTTP layer can map it to 400.
  // De-duplicated: used by both create and update paths for airports and zones.

  private val validCheckpointTypes: Set[String] = Set("landed", "arrivals_hall", "terminal_exit")

  private def validateLat(lat: Double): IO[RideError, Unit] =
    ZIO
      .fail(RideError.ValidationError("Latitude must be between -90 and 90"))
      .when(lat < -90.0 || lat > 90.0)
      .unit

  private def validateLon(lon: Double): IO[RideError, Unit] =
    ZIO
      .fail(RideError.ValidationError("Longitude must be between -180 and 180"))
      .when(lon < -180.0 || lon > 180.0)
      .unit

  private def validateRadius(radius: Int, fieldName: String = "Radius"): IO[RideError, Unit] =
    ZIO
      .fail(RideError.ValidationError(s"$fieldName must be positive"))
      .when(radius <= 0)
      .unit

  private def validateCheckpointType(checkpointType: String): IO[RideError, Unit] =
    ZIO
      .fail(
        RideError.ValidationError(
          s"Invalid checkpoint type: $checkpointType. Valid: ${validCheckpointTypes.mkString(", ")}"
        )
      )
      .when(!validCheckpointTypes.contains(checkpointType))
      .unit

  private def validateAirportCoords(lat: Double, lon: Double, radius: Int): IO[RideError, Unit] =
    validateLat(lat) *> validateLon(lon) *> validateRadius(radius, "Landing radius")

  private def validateZoneCoords(lat: Double, lon: Double, radius: Int): IO[RideError, Unit] =
    validateLat(lat) *> validateLon(lon) *> validateRadius(radius)

  override def listAirports(): Task[List[Airport]] = repo.findAll()

  override def getAirport(code: String): Task[Option[Airport]] = repo.findByCode(code)

  override def createAirport(airport: Airport): Task[Airport] =
    validateAirportCoords(airport.landingLat, airport.landingLon, airport.landingRadius) *>
      repo.create(airport).tap(_ => invalidate())

  override def updateAirport(code: String, airport: Airport): Task[Option[Airport]] =
    validateAirportCoords(airport.landingLat, airport.landingLon, airport.landingRadius) *>
      repo.update(code, airport).tap(_ => invalidate())

  override def deleteAirport(code: String): Task[Boolean] = repo.delete(code).tap(_ => invalidate())

  override def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone] =
    validateZoneCoords(zone.lat, zone.lon, zone.radiusMeters) *>
      validateCheckpointType(zone.checkpointType) *>
      repo.createZone(zone).tap(_ => invalidate())

  override def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] =
    validateZoneCoords(zone.lat, zone.lon, zone.radiusMeters) *>
      validateCheckpointType(zone.checkpointType) *>
      repo.updateZone(id, zone).tap(_ => invalidate())

  override def deleteZone(id: UUID): Task[Boolean] = repo.deleteZone(id).tap(_ => invalidate())

  override def getLandingGeofence(airportCode: String): Task[Option[(Double, Double, Int)]] = cachedAll().map(
    _.get(airportCode).map(a => (a.landingLat, a.landingLon, a.landingRadius))
  )

  override def getCheckpointDisplayName(airportCode: String, checkpoint: AirportCheckpoint): Task[String] =
    val checkpointTypeStr = AirportCheckpoint.toDbString(checkpoint)
    cachedAll().map { airportMap =>
      airportMap
        .get(airportCode)
        .flatMap(_.zones.find(_.checkpointType == checkpointTypeStr))
        .map(_.displayName)
        .getOrElse(checkpoint.toString) // fallback: enum name
    }
