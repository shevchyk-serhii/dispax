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
  def delete(id: RideTemplateId): Task[Boolean]
  def deactivate(id: RideTemplateId): Task[Boolean]

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

  def delete(id: RideTemplateId): Task[Boolean] = ZIO.succeed {
    store.remove(id) != null
  }

  def deactivate(id: RideTemplateId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)) match
      case Some(template) =>
        store.put(id, template.copy(isActive = false, updatedAt = java.time.Instant.now()))
        true
      case None           => false
  }

object RideTemplateRepository:
  val inMemory: ZLayer[Any, Nothing, RideTemplateRepository] = ZLayer.succeed(new InMemoryRideTemplateRepository)

  val layer: ZLayer[Any, Throwable, RideTemplateRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresRideTemplateRepository.postgresLayer
