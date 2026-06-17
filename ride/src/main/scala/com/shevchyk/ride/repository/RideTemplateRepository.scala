package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait RideTemplateRepository:
  def create(template: RideTemplate): Task[RideTemplate]
  def findById(id: RideTemplateId): Task[Option[RideTemplate]]
  def findByCompanyId(companyId: CompanyId): Task[List[RideTemplate]]
  def findActiveByCompanyId(companyId: CompanyId): Task[List[RideTemplate]]
  def update(template: RideTemplate): Task[RideTemplate]
  // Tenant-scoped: only affect the template when it belongs to `companyId`.
  def delete(id: RideTemplateId, companyId: CompanyId): Task[Boolean]
  def deactivate(id: RideTemplateId, companyId: CompanyId): Task[Boolean]

class InMemoryRideTemplateRepository extends RideTemplateRepository:
  private val store = new ConcurrentHashMap[RideTemplateId, RideTemplate]()

  def create(template: RideTemplate): Task[RideTemplate] = ZIO.succeed {
    store.put(template.id, template)
    template
  }

  def findById(id: RideTemplateId): Task[Option[RideTemplate]] = ZIO.succeed {
    Option(store.get(id))
  }

  def findByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] = ZIO.succeed {
    store.values().asScala.filter(_.companyId == companyId).toList.sortBy(_.createdAt)
  }

  def findActiveByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] = ZIO.succeed {
    store.values().asScala.filter(t => t.companyId == companyId && t.isActive).toList.sortBy(_.createdAt)
  }

  def update(template: RideTemplate): Task[RideTemplate] = ZIO.succeed {
    store.put(template.id, template)
    template
  }

  def delete(id: RideTemplateId, companyId: CompanyId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)) match
      case Some(t) if t.companyId == companyId => store.remove(id) != null
      case _                                   => false
  }

  def deactivate(id: RideTemplateId, companyId: CompanyId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)) match
      case Some(template) if template.companyId == companyId =>
        store.put(id, template.copy(isActive = false, updatedAt = java.time.Instant.now()))
        true
      case _                                                 => false
  }

object RideTemplateRepository:
  val inMemory: ZLayer[Any, Nothing, RideTemplateRepository] = ZLayer.succeed(new InMemoryRideTemplateRepository)

  val layer: ZLayer[Any, Throwable, RideTemplateRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresRideTemplateRepository.postgresLayer
