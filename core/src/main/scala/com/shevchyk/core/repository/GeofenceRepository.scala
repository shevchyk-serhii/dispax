package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait GeofenceRepository:
  def create(geofence: Geofence): Task[Geofence]
  def findByCompanyId(companyId: CompanyId): Task[List[Geofence]]
  def findActiveByCompanyId(companyId: CompanyId): Task[List[Geofence]]
  def findById(id: GeofenceId): Task[Option[Geofence]]
  def update(geofence: Geofence): Task[Geofence]
  // Tenant-scoped delete: only removes the geofence when it belongs to `companyId`.
  def delete(id: GeofenceId, companyId: CompanyId): Task[Boolean]
  def saveAlert(alert: GeofenceAlert): Task[GeofenceAlert]
  def findAlertsByCompany(companyId: CompanyId, limit: Int): Task[List[GeofenceAlert]]
  def findAlertsByDriver(driverId: PersonId, limit: Int): Task[List[GeofenceAlert]]

class InMemoryGeofenceRepository extends GeofenceRepository:
  private val geofences = new ConcurrentHashMap[GeofenceId, Geofence]()
  private val alerts    = new ConcurrentHashMap[UUID, GeofenceAlert]()

  def create(geofence: Geofence): Task[Geofence] = ZIO.succeed {
    geofences.put(geofence.id, geofence)
    geofence
  }

  def findByCompanyId(companyId: CompanyId): Task[List[Geofence]] = ZIO.succeed {
    geofences.values().asScala.filter(_.companyId == companyId).toList
  }

  def findActiveByCompanyId(companyId: CompanyId): Task[List[Geofence]] = ZIO.succeed {
    geofences.values().asScala.filter(g => g.companyId == companyId && g.isActive).toList
  }

  def findById(id: GeofenceId): Task[Option[Geofence]] = ZIO.succeed {
    Option(geofences.get(id))
  }

  def update(geofence: Geofence): Task[Geofence] = ZIO.succeed {
    geofences.put(geofence.id, geofence)
    geofence
  }

  def delete(id: GeofenceId, companyId: CompanyId): Task[Boolean] = ZIO.succeed {
    Option(geofences.get(id)) match
      case Some(g) if g.companyId == companyId => geofences.remove(id) != null
      case _                                   => false
  }

  def saveAlert(alert: GeofenceAlert): Task[GeofenceAlert] = ZIO.succeed {
    alerts.put(alert.id, alert)
    alert
  }

  def findAlertsByCompany(companyId: CompanyId, limit: Int): Task[List[GeofenceAlert]] = ZIO.succeed {
    alerts
      .values()
      .asScala
      .filter(_.companyId == companyId)
      .toList
      .sortBy(_.timestamp)(using Ordering[java.time.Instant].reverse)
      .take(limit)
  }

  def findAlertsByDriver(driverId: PersonId, limit: Int): Task[List[GeofenceAlert]] = ZIO.succeed {
    alerts
      .values()
      .asScala
      .filter(_.driverId == driverId)
      .toList
      .sortBy(_.timestamp)(using Ordering[java.time.Instant].reverse)
      .take(limit)
  }

object GeofenceRepository:
  val inMemory: ZLayer[Any, Nothing, GeofenceRepository] = ZLayer.succeed(new InMemoryGeofenceRepository)

  val layer: ZLayer[Any, Throwable, GeofenceRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresGeofenceRepository.postgresLayer
