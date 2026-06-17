package com.shevchyk.core.repository

import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId}
import com.shevchyk.core.database.DatabaseConfig
import zio.*

trait ClientCompanyRepository:
  def create(company: ClientCompany): Task[ClientCompany]
  def findById(id: ClientCompanyId): Task[Option[ClientCompany]]
  def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]
  def update(company: ClientCompany): Task[ClientCompany]
  // Tenant-scoped delete: only removes the client company owned by `taxiCompanyId`.
  def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean]

object ClientCompanyRepository:

  val layer: ZLayer[Any, Throwable, ClientCompanyRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresClientCompanyRepository.layer
