package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

case class LoginRequest(email: String, password: String) derives zio.json.JsonCodec

case class LoginResponse(person: PersonPublic, token: String) derives zio.json.JsonCodec

case class PersonPublic(
    id: PersonId,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives zio.json.JsonCodec

case class AuthToken(
    token: String,
    personId: PersonId,
    expiresAt: Long
)

enum AuthError extends Exception:
  case InvalidCredentials
  case TokenExpired
  case TokenNotFound
  case PersonNotFound(id: PersonId)
  case EmailAlreadyExists(email: String)
  case DatabaseError(cause: RepositoryError)

  def message: String =
    this match
      case InvalidCredentials        => "Invalid email or password"
      case TokenExpired              => "Token has expired"
      case TokenNotFound             => "Token not found"
      case PersonNotFound(id)        => s"Person not found: $id"
      case EmailAlreadyExists(email) => s"Email already exists: $email"
      case DatabaseError(cause)      => s"Database error: ${cause.message}"

case class AuthApplicationService(
    personRepo: PersonRepository,
    tokenStorage: TokenStorage = InMemoryTokenStorage()
):

  def login(request: LoginRequest): IO[AuthError, LoginResponse] =
    for
      person <- personRepo
                  .findByEmail(request.email)
                  .mapError(AuthError.DatabaseError.apply)
                  .someOrFail(AuthError.InvalidCredentials)

      _ <-
        ZIO.when(!verifyPassword(request.password, person.passwordHash.getOrElse(""))) {
          ZIO.fail(AuthError.InvalidCredentials)
        }

      token    <- generateToken()
      authToken = AuthToken(
                    token = token,
                    personId = person.id,
                    expiresAt = java.lang.System.currentTimeMillis() + (24 * 60 * 60 * 1000)
                  )

      _ <- tokenStorage.store(token, authToken)

      publicPerson = PersonPublic(
                       id = person.id,
                       name = person.name,
                       email = person.email,
                       role = person.role,
                       companyId = person.companyId,
                       licenseNumber = person.licenseNumber,
                       phone = person.phone
                     )
    yield LoginResponse(publicPerson, token)

  def validateToken(token: String): IO[AuthError, PersonPublic] =
    for
      authToken <- tokenStorage
                     .get(token)
                     .someOrFail(AuthError.TokenNotFound)

      _ <-
        ZIO.when(authToken.expiresAt <= java.lang.System.currentTimeMillis()) {
          tokenStorage.remove(token) *> ZIO.fail(AuthError.TokenExpired)
        }

      person <- personRepo
                  .findById(authToken.personId)
                  .mapError(AuthError.DatabaseError.apply)
                  .someOrFail(AuthError.PersonNotFound(authToken.personId))

      publicPerson = PersonPublic(
                       id = person.id,
                       name = person.name,
                       email = person.email,
                       role = person.role,
                       companyId = person.companyId,
                       licenseNumber = person.licenseNumber,
                       phone = person.phone
                     )
    yield publicPerson

  def createPerson(createRequest: CreatePersonRequest): IO[AuthError, PersonPublic] =
    for
      existingPerson <- personRepo
                          .findByEmail(createRequest.email)
                          .mapError(AuthError.DatabaseError.apply)

      _ <-
        ZIO.when(existingPerson.isDefined) {
          ZIO.fail(AuthError.EmailAlreadyExists(createRequest.email))
        }

      hashedPassword = hashPassword(createRequest.password)
      person         = Person(
                         id = PersonId(0),
                         name = createRequest.name,
                         email = createRequest.email,
                         role = createRequest.role,
                         companyId = createRequest.companyId,
                         passwordHash = Some(hashedPassword),
                         licenseNumber = createRequest.licenseNumber,
                         phone = createRequest.phone
                       )

      savedPerson <- personRepo
                       .save(person)
                       .mapError(AuthError.DatabaseError.apply)

      publicPerson = PersonPublic(
                       id = savedPerson.id,
                       name = savedPerson.name,
                       email = savedPerson.email,
                       role = savedPerson.role,
                       companyId = savedPerson.companyId,
                       licenseNumber = savedPerson.licenseNumber,
                       phone = savedPerson.phone
                     )
    yield publicPerson

  def getAllPersons: IO[AuthError, List[PersonPublic]] =
    for
      persons <- personRepo
                   .findAll()
                   .mapError(AuthError.DatabaseError.apply)

      publicPersons = persons.map(person =>
                        PersonPublic(
                          id = person.id,
                          name = person.name,
                          email = person.email,
                          role = person.role,
                          companyId = person.companyId,
                          licenseNumber = person.licenseNumber,
                          phone = person.phone
                        )
                      )
    yield publicPersons

  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    digest.digest(password.getBytes("UTF-8")).map("%02x".format(_)).mkString

  private def verifyPassword(password: String, hash: String): Boolean = hashPassword(password) == hash

  private def generateToken(): UIO[String] = ZIO.succeed(UUID.randomUUID().toString)

case class CreatePersonRequest(
    name: String,
    email: String,
    password: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives zio.json.JsonCodec

trait TokenStorage:
  def store(token: String, authToken: AuthToken): UIO[Unit]
  def get(token: String): UIO[Option[AuthToken]]
  def remove(token: String): UIO[Unit]

case class InMemoryTokenStorage() extends TokenStorage:
  private val tokens = ConcurrentHashMap[String, AuthToken]()

  def store(token: String, authToken: AuthToken): UIO[Unit] = ZIO.succeed(tokens.put(token, authToken))

  def get(token: String): UIO[Option[AuthToken]] = ZIO.succeed(Option(tokens.get(token)))

  def remove(token: String): UIO[Unit] = ZIO.succeed(tokens.remove(token))

object AuthApplicationService:

  val layer: ZLayer[PersonRepository, Nothing, AuthApplicationService] = ZLayer {
    for
      personRepo  <- ZIO.service[PersonRepository]
      tokenStorage = InMemoryTokenStorage()
    yield AuthApplicationService(personRepo, tokenStorage)
  }
