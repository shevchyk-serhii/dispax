package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import zio.*
import zio.test.*
import zio.test.Assertion.*

object AuthApplicationServiceSpec extends ZIOSpecDefault:

  def spec = suite("AuthApplicationService")(
    suite("login")(
      test("should successfully login with valid credentials") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = LoginRequest("john@test.com", "password123")
          result <- service.login(request)
        yield assertTrue(
          result.person.email == "john@test.com",
          result.person.name == "John Doe",
          result.token.nonEmpty
        )
      },

      test("should fail login with invalid email") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = LoginRequest("nonexistent@test.com", "password123")
          result <- service.login(request).exit
        yield assert(result)(fails(isSubtype[AuthError.InvalidCredentials.type](anything)))
      },

      test("should fail login with invalid password") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = LoginRequest("john@test.com", "wrongpassword")
          result <- service.login(request).exit
        yield assert(result)(fails(isSubtype[AuthError.InvalidCredentials.type](anything)))
      },

      test("should fail login when person has no password hash") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = LoginRequest("nohash@test.com", "password123")
          result <- service.login(request).exit
        yield assert(result)(fails(isSubtype[AuthError.InvalidCredentials.type](anything)))
      }
    ),

    suite("validateToken")(
      test("should successfully validate valid token") {
        for
          service <- ZIO.service[AuthApplicationService]
          loginRequest = LoginRequest("john@test.com", "password123")
          loginResult <- service.login(loginRequest)
          validateResult <- service.validateToken(loginResult.token)
        yield assertTrue(
          validateResult.email == "john@test.com",
          validateResult.name == "John Doe"
        )
      },

      test("should fail validation with invalid token") {
        for
          service <- ZIO.service[AuthApplicationService]
          result <- service.validateToken("invalid-token").exit
        yield assert(result)(fails(isSubtype[AuthError.TokenNotFound.type](anything)))
      },

      test("should fail validation with expired token") {
        for
          service <- ZIO.service[AuthApplicationService]
          expiredToken = "expired-token-12345"
          result <- service.validateToken(expiredToken).exit
        yield assert(result)(fails(isSubtype[AuthError.TokenNotFound.type](anything)))
      }
    ),

    suite("createPerson")(
      test("should successfully create new person") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = CreatePersonRequest(
            name = "Alice Smith",
            email = "alice@test.com",
            password = "securepass",
            role = PersonRole.client,
            companyId = Some(CompanyId(1)),
            licenseNumber = None,
            phone = Some("+1234567890")
          )
          result <- service.createPerson(request)
        yield assertTrue(
          result.name == "Alice Smith",
          result.email == "alice@test.com",
          result.role == PersonRole.client,
          result.companyId.contains(CompanyId(1)),
          result.phone.contains("+1234567890")
        )
      },

      test("should fail when email already exists") {
        for
          service <- ZIO.service[AuthApplicationService]
          request = CreatePersonRequest(
            name = "Another John",
            email = "john@test.com",
            password = "password123",
            role = PersonRole.client
          )
          result <- service.createPerson(request).exit
        yield assert(result)(fails(isSubtype[AuthError.EmailAlreadyExists](anything)))
      }
    ),

    suite("getAllPersons")(
      test("should return all persons") {
        for
          service <- ZIO.service[AuthApplicationService]
          result <- service.getAllPersons
        yield assertTrue(
          result.nonEmpty,
          result.exists(_.email == "john@test.com"),
          result.exists(_.email == "jane@test.com")
        )
      }
    )
  ).provide(
    AuthApplicationService.layer,
    AuthMockPersonRepository.layer
  )

case class AuthMockPersonRepository() extends PersonRepository:
  private val people = Map(
    PersonId(1) -> Person(
      id = PersonId(1),
      name = "John Doe",
      email = "john@test.com",
      role = PersonRole.driver,
      companyId = Some(CompanyId(1)),
      passwordHash = Some("ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f"),
      licenseNumber = Some("DL123456"),
      phone = Some("+1234567890")
    ),
    PersonId(2) -> Person(
      id = PersonId(2),
      name = "Jane Smith",
      email = "jane@test.com",
      role = PersonRole.client,
      companyId = Some(CompanyId(1)),
      passwordHash = Some("ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f"),
      phone = Some("+0987654321")
    ),
    PersonId(3) -> Person(
      id = PersonId(3),
      name = "No Hash User",
      email = "nohash@test.com",
      role = PersonRole.client,
      companyId = Some(CompanyId(1)),
      passwordHash = None
    )
  )

  def findById(id: PersonId): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(people.get(id))

  def findByEmail(email: String): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(people.values.find(_.email == email))

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] = 
    ZIO.succeed(people.values.filter(_.companyId.contains(companyId)).toList)

  def findAll(): IO[RepositoryError, List[Person]] =
    ZIO.succeed(people.values.toList)

  def save(person: Person): IO[RepositoryError, Person] = 
    val newId = if person.id.value == 0 then PersonId(people.size + 1) else person.id
    ZIO.succeed(person.copy(id = newId))

  def update(person: Person): IO[RepositoryError, Option[Person]] =
    if people.contains(person.id) then
      ZIO.succeed(Some(person))
    else
      ZIO.succeed(None)

  def delete(id: PersonId): IO[RepositoryError, Boolean] =
    ZIO.succeed(people.contains(id))

object AuthMockPersonRepository:
  val layer: ZLayer[Any, Nothing, PersonRepository] = 
    ZLayer.succeed(AuthMockPersonRepository())