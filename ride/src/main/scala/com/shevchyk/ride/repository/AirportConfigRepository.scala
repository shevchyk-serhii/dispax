package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
import zio.*

import java.util.UUID

/**
 * Repository for global airport configuration.
 *
 * DESIGN NOTE: No `CompanyId` parameter in any method. Airports are intentionally global (cross-tenant) configuration
 * data. Access control is enforced exclusively at the HTTP layer via `requireSuperAdmin(user)` in
 * [[com.shevchyk.app.openapi.SuperAdminAirportApi]]. This comment mirrors the pattern used in the platform-level
 * methods of [[RideRepository]].
 */
trait AirportConfigRepository:
  def findAll(): Task[List[Airport]]
  def findByCode(code: String): Task[Option[Airport]]
  def create(airport: Airport): Task[Airport]
  def update(code: String, airport: Airport): Task[Option[Airport]]
  def delete(code: String): Task[Boolean] // soft-delete: sets is_active = false
  def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone]
  def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]]
  def deleteZone(id: UUID): Task[Boolean]

object AirportConfigRepository:
  import com.shevchyk.core.database.DatabaseConfig
  import doobie.Transactor

  val postgresLayer: ZLayer[Transactor[Task], Nothing, AirportConfigRepository] = ZLayer.fromFunction(
    PostgresAirportConfigRepository.apply
  )

  val layer: ZLayer[Any, Throwable, AirportConfigRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
