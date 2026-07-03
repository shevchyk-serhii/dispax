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
  // NOTE: not tenant-scoped — deletes by id alone, ignoring company. Prefer deleteInCompany
  // for anything driven by a request. Kept for cross-tenant maintenance and tests; any API
  // caller using it must first verify ownership (e.g. via findByIdAndCompany), or it breaks
  // company isolation.
  def delete(id: PersonId): Task[Unit]
  // Tenant-scoped hard delete: only removes the person when it belongs to `companyId`.
  // Safe to call with an id taken from a request as long as companyId comes from the JWT.
  def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]
  def findByStatus(status: UserStatus): Task[List[Person]]
  def searchByQuery(query: String): Task[List[Person]]
  // Tenant-scoped (defense-in-depth): when companyId is Some, the write only applies if the
  // person belongs to that company; None (a person without a company, e.g. SuperAdmin) is unscoped.
  def updateLastLogin(id: PersonId, companyId: Option[CompanyId]): Task[Unit]
  def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]

  /**
   * Ensure a row exists in the `drivers` table for the given person. Used when a person gains the Driver role so they
   * can receive location updates and appear in driver queries. Idempotent: safe to call even when the row already
   * exists (ON CONFLICT DO NOTHING).
   */
  def upsertDriverRow(personId: PersonId): Task[Unit]

  /**
   * Return the avatar bytes and MIME type for the given person, or None if no avatar has been uploaded. Avatar bytes
   * are intentionally kept out of the regular selectColumns to avoid loading megabytes on every list/find query.
   */
  def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]

  /**
   * Store (or replace) the avatar for the given person. Validation (MIME type, size limit) is enforced by AvatarService
   * before this method is called. Tenant-scoped: the write is a no-op unless the person belongs to `companyId`
   * (defense-in-depth on top of the route-level company check).
   */
  def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit]

  /**
   * Remove the avatar for the given person. Idempotent: safe to call when no avatar exists. Tenant-scoped: the write is
   * a no-op unless the person belongs to `companyId` (defense-in-depth on top of the route-level company check).
   */
  def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]
}

object PersonRepository {

  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] = ZLayer.fromFunction(
    PostgresPersonRepository.apply
  )

  val layer: ZLayer[Any, Throwable, PersonRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
