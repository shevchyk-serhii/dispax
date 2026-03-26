package com.shevchyk.core.repository

import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.domain.{PersonId, CompanyId, Person, PersonRole, UserStatus}
import zio.*

class InMemoryPersonRepository extends PersonRepository:
  private val people = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[PersonId, Person])).getOrThrowFiberFailure()
  }

  override def create(person: Person): Task[Person] =
    people.update(_.updated(person.id, person)).as(person)

  override def findById(id: PersonId): Task[Option[Person]] =
    people.get.map(_.get(id))

  override def findByEmail(email: String): Task[Option[Person]] =
    people.get.map(_.values.find(_.email == email))

  override def findByRole(role: PersonRole): Task[List[Person]] =
    people.get.map(_.values.filter(_.role == role).toList)

  override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] =
    people.get.map(_.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList)

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] =
    people.get.map(_.values.filter(_.companyId == companyId).toList)

  override def findAll(): Task[List[Person]] =
    people.get.map(_.values.toList)

  override def update(person: Person): Task[Person] =
    people.update(_.updated(person.id, person)).as(person)

  override def delete(id: PersonId): Task[Unit] =
    people.update(_.removed(id)).unit

  override def findByStatus(status: UserStatus): Task[List[Person]] =
    people.get.map(_.values.filter(_.status == status).toList)

  override def searchByQuery(query: String): Task[List[Person]] =
    people.get.map(_.values.filter { p =>
      p.name.toLowerCase.contains(query.toLowerCase) ||
      p.email.toLowerCase.contains(query.toLowerCase)
    }.toList)

  override def updateLastLogin(id: PersonId): Task[Unit] =
    people.update(m => m.get(id).fold(m)(p => m.updated(id, p.copy(lastLoginAt = Some(java.time.Instant.now()))))).unit

object InMemoryPersonRepository:
  val layer: ZLayer[Any, Nothing, PersonRepository] =
    ZLayer.succeed(new InMemoryPersonRepository)
