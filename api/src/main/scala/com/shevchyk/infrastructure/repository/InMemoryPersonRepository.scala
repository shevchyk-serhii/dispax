package com.shevchyk.infrastructure.repository

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{PersonRepository, RepositoryError}
import zio.*

case class InMemoryPersonRepository(storage: Ref[Map[PersonId, Person]]) extends PersonRepository:

  override def findById(id: PersonId): IO[RepositoryError, Option[Person]] = storage.get.map(_.get(id))

  override def findByEmail(email: String): IO[RepositoryError, Option[Person]] = storage.get.map(
    _.values.find(_.email == email)
  )

  override def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] = storage.get.map(
    _.values.filter(_.companyId.contains(companyId)).toList
  )

  override def save(person: Person): IO[RepositoryError, Person] = storage.update(_ + (person.id -> person)).as(person)

object InMemoryPersonRepository:

  val layer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.fromZIO(
    Ref.make(mockPersons).map(InMemoryPersonRepository(_))
  )

  private val mockPersons: Map[PersonId, Person] = Map(
    PersonId(1) -> Person(
      id = PersonId(1),
      name = "John Driver",
      email = "john.driver@oktopus.com",
      role = PersonRole.driver,
      companyId = Some(CompanyId(1))
    ),
    PersonId(2) -> Person(
      id = PersonId(2),
      name = "Anna Client",
      email = "anna.client@example.com",
      role = PersonRole.client,
      companyId = Some(CompanyId(1))
    ),
    PersonId(3) -> Person(
      id = PersonId(3),
      name = "Maria Secretary",
      email = "maria.secretary@oktopus.com",
      role = PersonRole.secretary,
      companyId = Some(CompanyId(1))
    ),
    PersonId(4) -> Person(
      id = PersonId(4),
      name = "Peter Dispatcher",
      email = "peter.dispatcher@oktopus.com",
      role = PersonRole.dispatcher,
      companyId = Some(CompanyId(1))
    )
  )
