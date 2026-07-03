package com.shevchyk.core.repository

import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.domain.{ClientCompanyId, PersonId, CompanyId, Person, PersonRole, UserStatus}
import zio.*

class InMemoryPersonRepository extends PersonRepository:

  // In-memory avatar store: maps PersonId -> (bytes, contentType)
  private val avatars = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[PersonId, (Array[Byte], String)]))
      .getOrThrowFiberFailure()
  }

  private val people = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[PersonId, Person])).getOrThrowFiberFailure()
  }

  override def create(person: Person): Task[Person] = people.update(_.updated(person.id, person)).as(person)

  override def findById(id: PersonId): Task[Option[Person]] = people.get.map(_.get(id))

  override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]] = people.get.map(
    _.get(id).filter(_.companyId.contains(companyId))
  )

  override def findByEmail(email: String): Task[Option[Person]] = people.get.map(_.values.find(_.email == email))

  override def findByRole(role: PersonRole): Task[List[Person]] = people.get.map(
    _.values.filter(_.hasRole(role)).toList
  )

  override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = people.get.map(
    _.values.filter(p => p.hasRole(role) && p.companyId.contains(companyId)).toList
  )

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = people.get.map(
    // Person.companyId is Option[CompanyId]; compare against Some(companyId) — a bare `== companyId`
    // is always false (Some(x) never equals x) and silently returned an empty list.
    _.values.filter(_.companyId.contains(companyId)).toList
  )

  override def findAll(): Task[List[Person]] = people.get.map(_.values.toList)

  override def update(person: Person): Task[Person] = people.update(_.updated(person.id, person)).as(person)

  override def delete(id: PersonId): Task[Unit] = people.update(_.removed(id)).unit

  override def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit] =
    people
      .update(m =>
        m.get(id) match
          case Some(p) if p.companyId.contains(companyId) => m.removed(id)
          case _                                          => m
      )
      .unit

  override def findByStatus(status: UserStatus): Task[List[Person]] = people.get.map(
    _.values.filter(_.status == status).toList
  )

  override def searchByQuery(query: String): Task[List[Person]] = people.get.map(
    _.values
      .filter { p =>
        p.name.toLowerCase.contains(query.toLowerCase) ||
        p.email.toLowerCase.contains(query.toLowerCase)
      }
      .toList
  )

  override def updateLastLogin(id: PersonId, companyId: Option[CompanyId]): Task[Unit] =
    // Mirror the SQL "AND company_id = ?" guard: a scoped write for a person of another company is a no-op.
    people
      .update(m =>
        m.get(id)
          .filter(p => companyId.forall(c => p.companyId.contains(c)))
          .fold(m)(p => m.updated(id, p.copy(lastLoginAt = Some(java.time.Instant.now()))))
      )
      .unit

  override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]] = people.get.map(
    _.values.filter(_.clientCompanyId.contains(clientCompanyId)).toList
  )

  override def upsertDriverRow(personId: PersonId): Task[Unit] = ZIO.unit

  override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]] = avatars.get.map(_.get(id))

  // Tenant-scoped: mirror the SQL "AND company_id = ?" guard so an avatar write for a
  // person in another company is a no-op.
  private def belongsToCompany(id: PersonId, companyId: CompanyId): Task[Boolean] = people.get.map(
    _.get(id).exists(_.companyId.contains(companyId))
  )

  override def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] =
    ZIO.whenZIO(belongsToCompany(id, companyId))(avatars.update(_.updated(id, (bytes, contentType)))).unit

  override def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit] =
    ZIO.whenZIO(belongsToCompany(id, companyId))(avatars.update(_.removed(id))).unit

object InMemoryPersonRepository:
  val layer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(new InMemoryPersonRepository)
