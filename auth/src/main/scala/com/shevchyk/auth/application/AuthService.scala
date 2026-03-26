package com.shevchyk.auth.application

import com.shevchyk.auth.domain.*
import com.shevchyk.auth.repository.*
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.domain.{Person, PersonId, PersonRole, UserStatus}
import zio.*
import zio.json.*
import java.time.Instant
import java.util.UUID
import org.mindrot.jbcrypt.BCrypt
import com.github.f4b6a3.uuid.UuidCreator

trait AuthService:
  def login(email: String, password: String): ZIO[Any, AuthError, LoginResponse]
  def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto]
  def getUserById(id: UUID): ZIO[Any, AuthError, UserDto]
  def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto]
  def updateUser(id: UUID, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto]
  def deleteUser(id: UUID): ZIO[Any, AuthError, Unit]
  def changePassword(userId: UUID, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit]
  def validateToken(token: String): ZIO[Any, AuthError, UserDto]
  def refreshToken(token: String): ZIO[Any, AuthError, String]

  def getAllUsers(
      role: Option[PersonRole] = None,
      status: Option[UserStatus] = None
  ): ZIO[Any, AuthError, List[UserDto]]
  def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]]

class AuthServiceImpl(
    personRepository: PersonRepository,
    tokenRepository: TokenRepository,
    jwtService: JwtService
) extends AuthService:

  private def hashPassword(password: String): String = BCrypt.hashpw(password, BCrypt.gensalt(12))

  private def checkPassword(password: String, hash: String): Boolean = BCrypt.checkpw(password, hash)

  private val emailRegex = """^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$""".r

  private def validateEmail(email: String): Boolean = emailRegex.matches(email)

  private def parseRole(s: String): Either[Throwable, PersonRole] =
    val normalized = s.trim.toLowerCase.capitalize
    scala.util.Try(PersonRole.valueOf(normalized)).toEither

  private def validatePassword(password: String): Boolean =
    password.length >= 8 &&
      password.exists(_.isUpper) &&
      password.exists(_.isLower) &&
      password.exists(_.isDigit)

  override def login(email: String, password: String): ZIO[Any, AuthError, LoginResponse] =
    for
      personOpt <- personRepository.findByEmail(email).orElseFail(UserNotFound(email))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(email))
      _         <- ZIO.when(person.status != UserStatus.ACTIVE)(ZIO.fail(UserNotFound(email)))
      _         <- ZIO.when(!checkPassword(password, person.passwordHash))(ZIO.fail(InvalidCredentials(email)))
      token     <- jwtService.generateToken(person).mapError(identity)
      _         <- tokenRepository.create(token, person.id.value).orElseFail(ValidationError("token", "Failed to store token"))
      _         <- personRepository.updateLastLogin(person.id).ignore
    yield LoginResponse(UserDto.fromPerson(person), token)

  override def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      _        <- ZIO.when(!validateEmail(request.email))(ZIO.fail(ValidationError("email", "Invalid email format")))
      _        <-
        ZIO.when(!validatePassword(request.password))(
          ZIO.fail(WeakPassword("Password must be at least 8 characters with uppercase, lowercase, and digit"))
        )
      _        <- ZIO.when(request.name.trim.isEmpty)(ZIO.fail(ValidationError("name", "Name cannot be empty")))
      existing <- personRepository.findByEmail(request.email).orElseFail(ValidationError("email", "Database error"))
      _        <- ZIO.when(existing.isDefined)(ZIO.fail(UserAlreadyExists(request.email)))
      role     <- ZIO.fromEither(parseRole(request.role)).orElseFail(ValidationError("role", "Invalid role"))
      person    = Person(
                    id = PersonId.generate(),
                    name = request.name,
                    email = request.email,
                    role = role,
                    passwordHash = hashPassword(request.password),
                    phone = request.phone,
                    status = UserStatus.ACTIVE
                  )
      created  <- personRepository.create(person).orElseFail(ValidationError("user", "Failed to create user"))
    yield UserDto.fromPerson(created)

  override def getUserById(id: UUID): ZIO[Any, AuthError, UserDto] =
    for
      personOpt <- personRepository.findById(PersonId(id)).orElseFail(UserNotFound(s"ID: $id"))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(s"ID: $id"))
    yield UserDto.fromPerson(person)

  override def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto] =
    for
      personOpt <- personRepository.findByEmail(email).orElseFail(UserNotFound(email))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(email))
    yield UserDto.fromPerson(person)

  override def updateUser(id: UUID, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      existingOpt <- personRepository.findById(PersonId(id)).orElseFail(UserNotFound(s"ID: $id"))
      existing    <- ZIO.fromOption(existingOpt).orElseFail(UserNotFound(s"ID: $id"))
      _           <-
        request.email.fold(ZIO.unit)(email =>
          ZIO.when(!validateEmail(email))(ZIO.fail(ValidationError("email", "Invalid email format")))
        )
      role        <-
        request.role.fold(ZIO.succeed(existing.role))(r =>
          ZIO.fromEither(parseRole(r)).orElseFail(ValidationError("role", "Invalid role"))
        )
      status      <-
        request.status.fold(ZIO.succeed(existing.status))(s =>
          ZIO.attempt(UserStatus.valueOf(s)).orElseFail(ValidationError("status", "Invalid status"))
        )
      updated      = existing.copy(
                       email = request.email.getOrElse(existing.email),
                       name = request.name.getOrElse(existing.name),
                       role = role,
                       phone = request.phone.orElse(existing.phone),
                       status = status
                     )
      saved       <- personRepository.update(updated).orElseFail(ValidationError("user", "Failed to update user"))
    yield UserDto.fromPerson(saved)

  override def deleteUser(id: UUID): ZIO[Any, AuthError, Unit] =
    for
      personOpt <- personRepository.findById(PersonId(id)).orElseFail(UserNotFound(s"ID: $id"))
      _         <- ZIO.when(personOpt.isEmpty)(ZIO.fail(UserNotFound(s"ID: $id")))
      _         <- personRepository.delete(PersonId(id)).orElseFail(ValidationError("user", "Failed to delete user"))
      _         <- tokenRepository.deleteByUserId(id).orElseFail(ValidationError("token", "Failed to delete tokens"))
    yield ()

  override def changePassword(userId: UUID, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit] =
    for
      _         <-
        ZIO.when(!validatePassword(request.newPassword))(
          ZIO.fail(WeakPassword("Password must be at least 8 characters with uppercase, lowercase, and digit"))
        )
      personOpt <- personRepository.findById(PersonId(userId)).orElseFail(UserNotFound(s"ID: $userId"))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(s"ID: $userId"))
      _         <-
        ZIO.when(!checkPassword(request.currentPassword, person.passwordHash))(
          ZIO.fail(InvalidCredentials(person.email))
        )
      updated    = person.copy(passwordHash = hashPassword(request.newPassword))
      _         <- personRepository.update(updated).orElseFail(ValidationError("user", "Failed to update password"))
      _         <- tokenRepository.deleteByUserId(userId).orElseFail(ValidationError("token", "Failed to invalidate tokens"))
    yield ()

  override def validateToken(token: String): ZIO[Any, AuthError, UserDto] =
    for
      payload <- jwtService.validateToken(token).mapError(identity)
      user    <- getUserById(payload.userId)
      _       <- ZIO.when(user.email != payload.email)(ZIO.fail(InvalidToken(token)))
    yield user

  override def getAllUsers(role: Option[PersonRole], status: Option[UserStatus]): ZIO[Any, AuthError, List[UserDto]] =
    for
      all          <- personRepository.findAll().orElseFail(ValidationError("user", "Failed to fetch users"))
      filteredUsers = all.filter { person =>
                        role.forall(_ == person.role) && status.forall(_ == person.status)
                      }
    yield filteredUsers.map(UserDto.fromPerson)

  override def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]] =
    for matching <- personRepository
                      .searchByQuery(query)
                      .orElseFail(ValidationError("user", "Failed to search users"))
    yield matching.map(UserDto.fromPerson)

  override def refreshToken(token: String): ZIO[Any, AuthError, String] = jwtService
    .refreshToken(token)
    .mapError(identity)

object AuthService:

  val live: ZLayer[PersonRepository & TokenRepository & JwtService, Nothing, AuthService] = ZLayer
    .fromFunction(AuthServiceImpl.apply)
