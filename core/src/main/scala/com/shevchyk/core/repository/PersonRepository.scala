package com.shevchyk.core.repository

import com.shevchyk.core.domain.{CompanyId, Person, PersonId, PersonRole, UserStatus}
import com.shevchyk.core.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait PersonRepository {
  def create(person: Person): Task[Person]
  def findById(id: PersonId): Task[Option[Person]]
  def findByEmail(email: String): Task[Option[Person]]
  def findByRole(role: PersonRole): Task[List[Person]]
  def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]
  def findByCompanyId(companyId: CompanyId): Task[List[Person]]
  def findAll(): Task[List[Person]]
  def update(person: Person): Task[Person]
  def delete(id: PersonId): Task[Unit]
  def findByStatus(status: UserStatus): Task[List[Person]]
  def searchByQuery(query: String): Task[List[Person]]
  def updateLastLogin(id: PersonId): Task[Unit]
}

object PersonRepository {

  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] = ZLayer.fromFunction(
    PostgresPersonRepository.apply
  )

  val layer: ZLayer[Any, Throwable, PersonRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
