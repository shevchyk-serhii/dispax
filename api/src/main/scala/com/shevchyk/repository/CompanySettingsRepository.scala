package com.shevchyk.repository

import com.shevchyk.core.domain.*
import zio.*
import java.util.concurrent.ConcurrentHashMap

trait CompanySettingsRepository:
  def findByCompanyId(companyId: CompanyId): Task[Option[CompanySettings]]
  def upsert(settings: CompanySettings): Task[CompanySettings]

class InMemoryCompanySettingsRepository extends CompanySettingsRepository:
  private val store = new ConcurrentHashMap[CompanyId, CompanySettings]()

  def findByCompanyId(companyId: CompanyId): Task[Option[CompanySettings]] = ZIO.succeed {
    Option(store.get(companyId))
  }

  def upsert(settings: CompanySettings): Task[CompanySettings] = ZIO.succeed {
    store.put(settings.companyId, settings)
    settings
  }

object CompanySettingsRepository:
  val inMemory: ZLayer[Any, Nothing, CompanySettingsRepository] = ZLayer.succeed(new InMemoryCompanySettingsRepository)

  val layer: ZLayer[Any, Throwable, CompanySettingsRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresCompanySettingsRepository.postgresLayer
