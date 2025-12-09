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

  override def findAll(): IO[RepositoryError, List[Person]] = storage.get.map(_.values.toList)

  override def update(person: Person): IO[RepositoryError, Person] = storage
    .update(_ + (person.id -> person))
    .as(person)

  override def delete(id: PersonId): IO[RepositoryError, Boolean] = storage.modify { map =>
    if (map.contains(id))
      (true, map - id)
    else
      (false, map)
  }

object InMemoryPersonRepository:

  val layer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.fromZIO(
    Ref.make(Map.empty[PersonId, Person]).map(InMemoryPersonRepository(_))
  )
