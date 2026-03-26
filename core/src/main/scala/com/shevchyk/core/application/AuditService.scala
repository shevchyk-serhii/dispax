package com.shevchyk.core.application

import com.shevchyk.core.domain.*
import zio.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait AuditService:
  def log(entry: AuditLogEntry): Task[Unit]
  def findByEntity(entityType: String, entityId: UUID): Task[List[AuditLogEntry]]
  def findByCompany(companyId: CompanyId, limit: Int, offset: Int): Task[List[AuditLogEntry]]

class InMemoryAuditService extends AuditService:
  private val store = new ConcurrentHashMap[AuditLogId, AuditLogEntry]()

  def log(entry: AuditLogEntry): Task[Unit] = ZIO.succeed {
    store.put(entry.id, entry)
  }

  def findByEntity(entityType: String, entityId: UUID): Task[List[AuditLogEntry]] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(e => e.entityType == entityType && e.entityId == entityId)
      .toList
      .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
  }

  def findByCompany(companyId: CompanyId, limit: Int, offset: Int): Task[List[AuditLogEntry]] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(_.companyId == companyId)
      .toList
      .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
      .drop(offset)
      .take(limit)
  }

object AuditService:
  val inMemory: ZLayer[Any, Nothing, AuditService] = ZLayer.succeed(new InMemoryAuditService)

  val layer: ZLayer[Any, Throwable, AuditService] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresAuditService.postgresLayer
