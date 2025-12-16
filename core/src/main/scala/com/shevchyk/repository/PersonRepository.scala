package com.shevchyk.repository

import com.shevchyk.core.domain.{CompanyId, Person, PersonId, PersonRole}
import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait PersonRepository {
  def create(person: Person): Task[Person]
  def findById(id: PersonId): Task[Option[Person]]
  def findByEmail(email: String): Task[Option[Person]]
  def findByRole(role: PersonRole): Task[List[Person]]
  def findByCompanyId(companyId: CompanyId): Task[List[Person]]
  def findAll(): Task[List[Person]]
  def update(person: Person): Task[Person]
  def delete(id: PersonId): Task[Unit]
}

object PersonRepository {

  // PostgreSQL layer for production
  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] = ZLayer.fromFunction(
    PostgresPersonRepository.apply
  )

  // Default layer (PostgreSQL with database transactor and migrations)
  val layer: ZLayer[Any, Throwable, PersonRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
