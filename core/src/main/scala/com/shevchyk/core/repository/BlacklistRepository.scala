package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*

trait BlacklistRepository:
  def create(entry: BlacklistEntry): Task[BlacklistEntry]
  def findByCompanyId(companyId: CompanyId): Task[List[BlacklistEntry]]
  def findByClientId(clientId: PersonId): Task[List[BlacklistEntry]]
  def findByDriverId(driverId: PersonId): Task[List[BlacklistEntry]]
  def isBlacklisted(clientId: PersonId, driverId: PersonId): Task[Boolean]
  // Tenant-scoped: only deactivates the entry when it belongs to `companyId`.
  def deactivate(id: BlacklistEntryId, companyId: CompanyId): Task[Boolean]
  // NOTE: not tenant-scoped — hard delete by id alone. No production caller; tests only.
  def delete(id: BlacklistEntryId): Task[Boolean]

object BlacklistRepository:
  val inMemory: ZLayer[Any, Nothing, BlacklistRepository] = ZLayer.succeed(InMemoryBlacklistRepository())

  val layer: ZLayer[Any, Throwable, BlacklistRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresBlacklistRepository.postgresLayer

class InMemoryBlacklistRepository extends BlacklistRepository:
  private var entries: List[BlacklistEntry] = List.empty

  override def create(entry: BlacklistEntry): Task[BlacklistEntry] = ZIO.succeed {
    entries = entries.filterNot(e => e.clientId == entry.clientId && e.driverId == entry.driverId) :+ entry
    entry
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[BlacklistEntry]] = ZIO.succeed {
    entries.filter(e => e.companyId == companyId && e.isActive)
  }

  override def findByClientId(clientId: PersonId): Task[List[BlacklistEntry]] = ZIO.succeed {
    entries.filter(e => e.clientId == clientId && e.isActive)
  }

  override def findByDriverId(driverId: PersonId): Task[List[BlacklistEntry]] = ZIO.succeed {
    entries.filter(e => e.driverId == driverId && e.isActive)
  }

  override def isBlacklisted(clientId: PersonId, driverId: PersonId): Task[Boolean] = ZIO.succeed {
    entries.exists(e => e.clientId == clientId && e.driverId == driverId && e.isActive)
  }

  override def deactivate(id: BlacklistEntryId, companyId: CompanyId): Task[Boolean] = ZIO.succeed {
    val idx = entries.indexWhere(e => e.id == id && e.companyId == companyId)
    if idx >= 0 then
      entries = entries.updated(idx, entries(idx).copy(isActive = false))
      true
    else false
  }

  override def delete(id: BlacklistEntryId): Task[Boolean] = ZIO.succeed {
    val before = entries.length
    entries = entries.filterNot(_.id == id)
    entries.length < before
  }
