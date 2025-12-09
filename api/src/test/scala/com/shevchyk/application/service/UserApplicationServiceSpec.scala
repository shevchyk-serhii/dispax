package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import zio.*
import zio.test.*
import zio.test.Assertion.*

object UserApplicationServiceSpec extends ZIOSpecDefault:

  def spec = suite("UserApplicationService")(
    suite("getAllUsers")(
      test("should return all users") {
        for
          service <- ZIO.service[UserApplicationService]
          result <- service.getAllUsers
        yield assertTrue(
          result.nonEmpty,
          result.length == 3,
          result.exists(_.email == "john@test.com"),
          result.exists(_.email == "jane@test.com"),
          result.exists(_.email == "admin@test.com")
        )
      }
    ),

    suite("getUserById")(
      test("should return user when exists") {
        for
          service <- ZIO.service[UserApplicationService]
          result <- service.getUserById(PersonId(1))
        yield assertTrue(
          result.name == "John Doe",
          result.email == "john@test.com",
          result.role == PersonRole.driver
        )
      },

      test("should fail when user not found") {
        for
          service <- ZIO.service[UserApplicationService]
          result <- service.getUserById(PersonId(999)).exit
        yield assert(result)(fails(isSubtype[UserError.PersonNotFound](anything)))
      }
    ),

    suite("createUser")(
      test("should successfully create new user") {
        for
          service <- ZIO.service[UserApplicationService]
          newUser = Person(
            id = PersonId(0),
            name = "Alice Cooper",
            email = "alice@test.com",
            role = PersonRole.client,
            companyId = Some(CompanyId(1)),
            phone = Some("+1234567890")
          )
          result <- service.createUser(newUser)
        yield assertTrue(
          result.name == "Alice Cooper",
          result.email == "alice@test.com",
          result.role == PersonRole.client,
          result.id.value > 0
        )
      },

      test("should fail when email already exists") {
        for
          service <- ZIO.service[UserApplicationService]
          existingUser = Person(
            id = PersonId(0),
            name = "Another John",
            email = "john@test.com",
            role = PersonRole.client
          )
          result <- service.createUser(existingUser).exit
        yield assert(result)(fails(isSubtype[UserError.EmailAlreadyExists](anything)))
      },

      test("should fail with empty name") {
        for
          service <- ZIO.service[UserApplicationService]
          invalidUser = Person(
            id = PersonId(0),
            name = "",
            email = "empty@test.com",
            role = PersonRole.client
          )
          result <- service.createUser(invalidUser).exit
        yield assert(result)(fails(isSubtype[UserError.InvalidInput](anything)))
      },

      test("should fail with invalid email") {
        for
          service <- ZIO.service[UserApplicationService]
          invalidUser = Person(
            id = PersonId(0),
            name = "Valid Name",
            email = "invalid-email",
            role = PersonRole.client
          )
          result <- service.createUser(invalidUser).exit
        yield assert(result)(fails(isSubtype[UserError.InvalidInput](anything)))
      }
    ),

    suite("updateUser")(
      test("should successfully update existing user") {
        for
          service <- ZIO.service[UserApplicationService]
          updatedUser = Person(
            id = PersonId(1),
            name = "John Updated",
            email = "john.updated@test.com",
            role = PersonRole.driver,
            companyId = Some(CompanyId(2))
          )
          result <- service.updateUser(PersonId(1), updatedUser)
        yield assertTrue(
          result.name == "John Updated",
          result.email == "john.updated@test.com",
          result.companyId.contains(CompanyId(2))
        )
      },

      test("should fail when user not found") {
        for
          service <- ZIO.service[UserApplicationService]
          nonExistentUser = Person(
            id = PersonId(999),
            name = "Non Existent",
            email = "nonexistent@test.com",
            role = PersonRole.client
          )
          result <- service.updateUser(PersonId(999), nonExistentUser).exit
        yield assert(result)(fails(isSubtype[UserError.PersonNotFound](anything)))
      }
    ),

    suite("deleteUser")(
      test("should successfully delete existing user") {
        for
          service <- ZIO.service[UserApplicationService]
          result <- service.deleteUser(PersonId(1))
        yield assertTrue(result == true)
      },

      test("should fail when user not found") {
        for
          service <- ZIO.service[UserApplicationService]
          result <- service.deleteUser(PersonId(999)).exit
        yield assert(result)(fails(isSubtype[UserError.PersonNotFound](anything)))
      }
    )
  ).provide(
    UserApplicationService.layer,
    UserMockPersonRepository.layer
  )

case class UserMockPersonRepository() extends PersonRepository:
  private val users = scala.collection.mutable.Map(
    PersonId(1) -> Person(
      id = PersonId(1),
      name = "John Doe",
      email = "john@test.com",
      role = PersonRole.driver,
      companyId = Some(CompanyId(1)),
      licenseNumber = Some("DL123456"),
      phone = Some("+1234567890")
    ),
    PersonId(2) -> Person(
      id = PersonId(2),
      name = "Jane Smith",
      email = "jane@test.com",
      role = PersonRole.client,
      companyId = Some(CompanyId(1)),
      phone = Some("+0987654321")
    ),
    PersonId(3) -> Person(
      id = PersonId(3),
      name = "Admin User",
      email = "admin@test.com",
      role = PersonRole.dispatcher,
      companyId = Some(CompanyId(1))
    )
  )

  def findById(id: PersonId): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(users.get(id))

  def findByEmail(email: String): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(users.values.find(_.email == email))

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] = 
    ZIO.succeed(users.values.filter(_.companyId.contains(companyId)).toList)

  def findAll(): IO[RepositoryError, List[Person]] =
    ZIO.succeed(users.values.toList)

  def save(person: Person): IO[RepositoryError, Person] = 
    val newId = if person.id.value == 0 then PersonId(users.size + 1) else person.id
    val savedPerson = person.copy(id = newId)
    users += newId -> savedPerson
    ZIO.succeed(savedPerson)

  def update(person: Person): IO[RepositoryError, Option[Person]] =
    if users.contains(person.id) then
      users += person.id -> person
      ZIO.succeed(Some(person))
    else
      ZIO.succeed(None)

  def delete(id: PersonId): IO[RepositoryError, Boolean] =
    val existed = users.contains(id)
    users.remove(id)
    ZIO.succeed(existed)

object UserMockPersonRepository:
  val layer: ZLayer[Any, Nothing, PersonRepository] = 
    ZLayer.succeed(UserMockPersonRepository())