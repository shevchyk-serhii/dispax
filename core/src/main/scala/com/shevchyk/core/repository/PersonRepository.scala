package com.shevchyk.core.repository

import com.shevchyk.core.domain.{ClientCompanyId, CompanyId, Person, PersonId, PersonRole, UserStatus}
import com.shevchyk.core.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait PersonRepository {
  def create(person: Person): Task[Person]
  def findById(id: PersonId): Task[Option[Person]]
  // Tenant-scoped lookup: returns the person only if it belongs to the given company.
  // Used to enforce company isolation on update/delete-by-id operations.
  def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]
  def findByEmail(email: String): Task[Option[Person]]
  def findByRole(role: PersonRole): Task[List[Person]]
  def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]
  def findByCompanyId(companyId: CompanyId): Task[List[Person]]
  def findAll(): Task[List[Person]]
  def update(person: Person): Task[Person]
  // NOTE: not tenant-scoped — deletes by id alone, ignoring company. Any API caller must
  // first verify ownership (e.g. via findByIdAndCompany) before calling this, or it breaks
  // company isolation. The production user-delete route uses a soft-delete guarded by
  // UserApi.requireSameCompany; this hard delete is currently only exercised by tests.
  def delete(id: PersonId): Task[Unit]
  def findByStatus(status: UserStatus): Task[List[Person]]
  def searchByQuery(query: String): Task[List[Person]]
  def updateLastLogin(id: PersonId): Task[Unit]
  def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]

  /**
   * Ensure a row exists in the `drivers` table for the given person. Used when a person gains the Driver role so they
   * can receive location updates and appear in driver queries. Idempotent: safe to call even when the row already
   * exists (ON CONFLICT DO NOTHING).
   */
  def upsertDriverRow(personId: PersonId): Task[Unit]
}

object PersonRepository {

  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] = ZLayer.fromFunction(
    PostgresPersonRepository.apply
  )

  val layer: ZLayer[Any, Throwable, PersonRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
