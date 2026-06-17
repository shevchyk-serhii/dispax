package com.shevchyk.auth.repository

import com.shevchyk.core.domain.{ClientCompanyId, Person, PersonId, PersonRole, UserStatus}
import com.shevchyk.core.repository.PersonRepository
import zio.*
import java.time.Instant
import java.util.UUID
import org.mindrot.jbcrypt.BCrypt

object TestUUIDs:
  val testUserId1  = UUID.fromString("11111111-1111-1111-1111-111111111111")
  val testUserId50 = UUID.fromString("50505050-5050-5050-5050-505050505050")
  val testUserId10 = UUID.fromString("10101010-1010-1010-1010-101010101010")
  val testUserId99 = UUID.fromString("99999999-9999-9999-9999-999999999999")

/**
 * InMemoryPersonRepository with pre-seeded test users for auth tests
 */
final class InMemoryPersonRepositoryWithUsers extends PersonRepository:
  import TestUUIDs._

  private def hashPassword(password: String): String = BCrypt.hashpw(password, BCrypt.gensalt(12))

  private val people = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        Ref.Synchronized.make(
          Map[PersonId, Person](
            PersonId(testUserId1)  -> Person(
              PersonId(testUserId1),
              "Test User",
              "test@example.com",
              PersonRole.Client,
              passwordHash = hashPassword("Password123"),
              phone = Some("+1234567890"),
              status = UserStatus.ACTIVE
            ),
            PersonId(testUserId50) -> Person(
              PersonId(testUserId50),
              "Client User",
              "client@example.com",
              PersonRole.Client,
              passwordHash = hashPassword("Password123"),
              phone = Some("+1111111111"),
              status = UserStatus.ACTIVE
            ),
            PersonId(testUserId10) -> Person(
              PersonId(testUserId10),
              "Driver User",
              "driver@example.com",
              PersonRole.Driver,
              passwordHash = hashPassword("Password123"),
              phone = Some("+2222222222"),
              status = UserStatus.ACTIVE
            ),
            PersonId(testUserId99) -> Person(
              PersonId(testUserId99),
              "Admin User",
              "admin@example.com",
              PersonRole.Admin,
              passwordHash = hashPassword("Password123"),
              phone = Some("+3333333333"),
              status = UserStatus.ACTIVE
            )
          )
        )
      )
      .getOrThrow()
  }

  override def create(person: Person): Task[Person] =
    val p = if person.id.value == null then person.copy(id = PersonId.generate()) else person
    people.update(_.updated(p.id, p)).as(p)

  override def findById(id: PersonId): Task[Option[Person]] = people.get.map(_.get(id))

  override def findByIdAndCompany(
      id: PersonId,
      companyId: com.shevchyk.core.domain.CompanyId
  ): Task[Option[Person]] = people.get.map(_.get(id).filter(_.companyId.contains(companyId)))

  override def findByEmail(email: String): Task[Option[Person]] = people.get.map(_.values.find(_.email == email))

  override def findAll(): Task[List[Person]] = people.get.map(_.values.toList.sortBy(_.id.value.toString))

  override def findByRole(role: PersonRole): Task[List[Person]] = people.get.map(
    _.values.filter(_.hasRole(role)).toList.sortBy(_.id.value.toString)
  )

  override def findByRoleAndCompany(
      role: PersonRole,
      companyId: com.shevchyk.core.domain.CompanyId
  ): Task[List[Person]] = people.get.map(_.values.filter(p => p.hasRole(role) && p.companyId.contains(companyId)).toList)

  override def findByCompanyId(companyId: com.shevchyk.core.domain.CompanyId): Task[List[Person]] = people.get.map(
    _.values.filter(_.companyId.contains(companyId)).toList
  )

  override def findByStatus(status: UserStatus): Task[List[Person]] = people.get.map(
    _.values.filter(_.status == status).toList.sortBy(_.id.value.toString)
  )

  override def update(person: Person): Task[Person] = people.update(_.updated(person.id, person)).as(person)

  override def delete(id: PersonId): Task[Unit] = people.update(_.removed(id)).unit

  override def searchByQuery(query: String): Task[List[Person]] = people.get.map(
    _.values
      .filter { p =>
        p.name.toLowerCase.contains(query.toLowerCase) ||
        p.email.toLowerCase.contains(query.toLowerCase)
      }
      .toList
      .sortBy(_.id.value.toString)
  )

  override def updateLastLogin(id: PersonId): Task[Unit] =
    people.update(m => m.get(id).fold(m)(p => m.updated(id, p.copy(lastLoginAt = Some(Instant.now()))))).unit

  override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]] = people.get.map(
    _.values.filter(_.clientCompanyId.contains(clientCompanyId)).toList
  )

  override def upsertDriverRow(personId: PersonId): Task[Unit] = ZIO.unit

final class InMemoryTokenRepository extends TokenRepository:
  import TestUUIDs._

  private val tokens = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        Ref.Synchronized.make(
          Map[String, UUID](
            "valid-token-1"  -> testUserId1,
            "valid-token-50" -> testUserId50,
            "valid-token-10" -> testUserId10,
            "valid-token-99" -> testUserId99
          )
        )
      )
      .getOrThrow()
  }

  override def create(token: String, userId: UUID): Task[Unit] =
    for _ <- tokens.update(_.updated(token, userId))
    yield ()

  override def findUserIdByToken(token: String): Task[Option[UUID]] =
    for tokenMap <- tokens.get
    yield tokenMap.get(token)

  override def deleteByToken(token: String): Task[Unit] =
    for _ <- tokens.update(_ - token)
    yield ()

  override def deleteByUserId(userId: UUID): Task[Unit] =
    for
      tokenMap      <- tokens.get
      tokensToDelete = tokenMap.filter(_._2 == userId).keys
      _             <- tokens.update(map => tokensToDelete.foldLeft(map)((acc, token) => acc - token))
    yield ()
