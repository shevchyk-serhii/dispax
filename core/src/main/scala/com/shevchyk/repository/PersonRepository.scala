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

final case class MockPersonRepository() extends PersonRepository {

  override def create(person: Person): Task[Person] = ZIO.succeed(person)

  override def findById(id: PersonId): Task[Option[Person]] = {
    ZIO.succeed(
      Some(
        Person(
          id = id,
          name = "Mock User",
          email = "mock@example.com",
          role = PersonRole.Client
        )
      )
    )
  }

  override def findByEmail(email: String): Task[Option[Person]] = {
    ZIO.succeed(
      Some(
        Person(
          id = PersonId(1),
          name = "Mock User",
          email = email,
          role = PersonRole.Client
        )
      )
    )
  }

  override def findByRole(role: PersonRole): Task[List[Person]] = {
    ZIO.succeed(
      List(
        Person(
          id = PersonId(1),
          name = "Mock User",
          email = "mock@example.com",
          role = role
        )
      )
    )
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = {
    ZIO.succeed(
      List(
        Person(
          id = PersonId(1),
          name = "Mock User",
          email = "mock@example.com",
          role = PersonRole.Client,
          companyId = Some(companyId)
        )
      )
    )
  }

  override def findAll(): Task[List[Person]] = {
    ZIO.succeed(
      List(
        Person(
          id = PersonId(1),
          name = "Mock User",
          email = "mock@example.com",
          role = PersonRole.Client
        )
      )
    )
  }

  override def update(person: Person): Task[Person] = ZIO.succeed(person)

  override def delete(id: PersonId): Task[Unit] = ZIO.succeed(())
}

object PersonRepository {
  // Mock layer for testing
  val mockLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(MockPersonRepository())

  // PostgreSQL layer for production
  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] = ZLayer.fromFunction(
    PostgresPersonRepository.apply
  )

  // Default layer (PostgreSQL with database transactor)
  val layer: ZLayer[Any, Throwable, PersonRepository] = DatabaseConfig.liveTransactor >>> postgresLayer
}
