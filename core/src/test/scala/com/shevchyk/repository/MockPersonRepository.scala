package com.shevchyk.repository

import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId}
import zio.*

final case class MockPersonRepository() extends PersonRepository {

  override def create(person: Person): Task[Person] = ZIO.succeed(person)

  override def findById(id: PersonId): Task[Option[Person]] = {
    ZIO.some {
      Person(
        id = id,
        name = "Mock User",
        email = "mock@example.com",
        role = PersonRole.Client
      )
    }
  }

  override def findByEmail(email: String): Task[Option[Person]] = {
    ZIO.some {
      Person(
        id = PersonId(1),
        name = "Mock User",
        email = email,
        role = PersonRole.Client
      )
    }
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

  override def delete(id: PersonId): Task[Unit] = ZIO.unit
}