package com.shevchyk.core.repository

import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus}
import zio.*

/**
 * Platform-level repository for tenant companies (the `companies` table).
 *
 * All methods in this trait operate across ALL tenants — they have no `company_id` parameter that could act as a tenant
 * filter. This is by design: only [[com.shevchyk.app.openapi.SuperAdminApi]] calls these methods, and it guards every
 * handler with `requireSuperAdmin` first.
 *
 * Names containing `All` or `Platform` make the cross-tenant intent explicit and grep-auditable.
 */
trait CompanyRepository:
  /**
   * List all registered taxi-operator companies. No company_id filter.
   */
  def findAll(): Task[List[Company]]

  /**
   * Find a single company by its primary key (no tenant filter).
   */
  def findById(id: CompanyId): Task[Option[Company]]

  /**
   * Register a new taxi-operator company (platform onboarding).
   */
  def create(company: Company): Task[Company]

  /**
   * Update an existing company (status, plan, contact info).
   */
  def update(company: Company): Task[Company]

  /**
   * Return a count per [[CompanyStatus]] across all companies.
   */
  def countByStatus(): Task[Map[CompanyStatus, Int]]

  /**
   * Soft-delete a company by marking its status as [[CompanyStatus.Inactive]]. Returns the updated company if found, or
   * [[None]] if no row with the given id exists. Cross-tenant — no companyId filter by design (SuperAdmin only).
   */
  def softDelete(id: CompanyId): Task[Option[Company]]

object CompanyRepository:

  val postgresLayer: ZLayer[doobie.Transactor[Task], Nothing, CompanyRepository] = ZLayer.fromFunction(
    PostgresCompanyRepository.apply
  )

  val layer: ZLayer[Any, Throwable, CompanyRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
