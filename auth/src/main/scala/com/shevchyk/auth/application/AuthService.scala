package com.shevchyk.auth.application

import com.shevchyk.auth.domain.*
import com.shevchyk.auth.repository.*
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.repository.{PersonRepository, SessionRepository}
import com.shevchyk.core.domain.{CompanyId, Person, PersonId, PersonRole, Session, SessionId, UserStatus}
import zio.*
import java.time.Instant
import java.util.UUID
import org.mindrot.jbcrypt.BCrypt

trait AuthService:

  /**
   * Authenticates a user and, as part of the same login transaction, records an active session row so the "Active
   * sessions" screen can list this device. `deviceInfo` (User-Agent) and `ipAddress` come from the HTTP layer; both are
   * optional so non-HTTP callers and tests can omit them.
   */
  def login(
      email: String,
      password: String,
      deviceInfo: Option[String] = None,
      ipAddress: Option[String] = None
  ): ZIO[Any, AuthError, LoginResponse]
  def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto]
  def getUserById(id: UUID): ZIO[Any, AuthError, UserDto]
  def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto]

  /**
   * Updates a user by id, scoped to `companyId`: the row is read and updated only when it belongs to that company, so a
   * caller cannot read or mutate another tenant's user even with a guessed id. Closes a TOCTOU/existence-leak gap where
   * the preceding read used `findById` (no company) while the SQL update was already company-guarded.
   */
  def updateUser(id: UUID, companyId: CompanyId, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto]

  /**
   * Hard-deletes a user by id, scoped to `companyId`: the row is only removed when it belongs to that company, so a
   * caller cannot delete another tenant's user even with a guessed id. The HTTP layer does not expose a hard delete —
   * `UserApi.deleteUserServer` performs a soft delete guarded by `requireSameCompany`; this method is used by tests and
   * any future hard-delete path.
   */
  def deleteUser(id: UUID, companyId: CompanyId): ZIO[Any, AuthError, Unit]

  /**
   * Changes a user's password, scoped to `companyId`: the row is read only when it belongs to that company, so a caller
   * cannot probe the existence of (or mutate) another tenant's user even with a guessed id.
   */
  def changePassword(userId: UUID, companyId: CompanyId, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit]
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
    sessionRepository: SessionRepository,
    jwtService: JwtService
) extends AuthService:

  // BCrypt is deliberately CPU-intensive (~100-200ms). Run it on the blocking pool so concurrent
  // logins/registrations don't starve the main ZIO worker threads.
  private def hashPassword(password: String): Task[String] = ZIO.attemptBlocking(
    BCrypt.hashpw(password, BCrypt.gensalt(12))
  )

  private def checkPassword(password: String, hash: String): Task[Boolean] = ZIO.attemptBlocking(
    BCrypt.checkpw(password, hash)
  )

  private val emailRegex = """^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$""".r
  // Accepts international phone numbers: optional +, then 6–15 digits (with optional spaces/dashes).
  private val phoneRegex = """^\+?[0-9][0-9 \-]{4,14}[0-9]$""".r

  private def validateEmail(email: String): Boolean = emailRegex.matches(email)
  private def validatePhone(phone: String): Boolean = phoneRegex.matches(phone.trim)

  private def parseRole(s: String): Either[Throwable, PersonRole] =
    val normalized = s.trim.toLowerCase.capitalize
    scala.util.Try(PersonRole.valueOf(normalized)).toEither

  private def validatePassword(password: String): Boolean =
    password.length >= 8 &&
      password.exists(_.isUpper) &&
      password.exists(_.isLower) &&
      password.exists(_.isDigit)

  override def login(
      email: String,
      password: String,
      deviceInfo: Option[String],
      ipAddress: Option[String]
  ): ZIO[Any, AuthError, LoginResponse] =
    for
      personOpt <- personRepository.findByEmail(email).orElseFail(UserNotFound(email))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(email))
      _         <- ZIO.when(person.status != UserStatus.ACTIVE)(ZIO.fail(UserNotFound(email)))
      pwMatch   <- checkPassword(password, person.passwordHash).orElseFail(InvalidCredentials(email))
      _         <- ZIO.when(!pwMatch)(ZIO.fail(InvalidCredentials(email)))
      token     <- jwtService.generateToken(person).mapError(identity)
      _         <- tokenRepository.create(token, person.id.value).orElseFail(ValidationError("token", "Failed to store token"))
      // Record an active session for the "Active sessions" screen. A storage hiccup here must not block the login —
      // the JWT is already issued — so this is best-effort (`.ignore`), mirroring updateLastLogin below.
      now        = Instant.now()
      _         <-
        sessionRepository
          .create(
            Session(
              id = SessionId.generate(),
              userId = person.id,
              token = token,
              deviceInfo = deviceInfo,
              ipAddress = ipAddress,
              createdAt = now,
              lastActiveAt = now
            )
          )
          .ignore
      _         <- personRepository.updateLastLogin(person.id).ignore
    yield LoginResponse(UserDto.fromPerson(person), token)

  private def parseRoles(rawRoles: List[String]): Either[String, Set[PersonRole]] =
    val parsed = rawRoles.map(r => parseRole(r).left.map(_ => r))
    val errors = parsed.collect { case Left(r) => r }
    if errors.nonEmpty then Left(s"Invalid roles: ${errors.mkString(", ")}")
    else Right(parsed.collect { case Right(r) => r }.toSet)

  override def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      _        <- ZIO.when(!validateEmail(request.email))(ZIO.fail(ValidationError("email", "Invalid email format")))
      _        <-
        ZIO.when(request.phone.exists(p => !validatePhone(p)))(
          ZIO.fail(ValidationError("phone", "Invalid phone number format"))
        )
      _        <-
        ZIO.when(!validatePassword(request.password))(
          ZIO.fail(WeakPassword("Password must be at least 8 characters with uppercase, lowercase, and digit"))
        )
      _        <- ZIO.when(request.name.trim.isEmpty)(ZIO.fail(ValidationError("name", "Name cannot be empty")))
      existing <- personRepository.findByEmail(request.email).orElseFail(ValidationError("email", "Database error"))
      _        <- ZIO.when(existing.isDefined)(ZIO.fail(UserAlreadyExists(request.email)))
      role     <- ZIO.fromEither(parseRole(request.role)).orElseFail(ValidationError("role", "Invalid role"))
      // roles: if provided, validate them; otherwise default to Set(role)
      rolesSet <-
        request.roles match
          case None       => ZIO.succeed(Set(role))
          case Some(raws) =>
            ZIO.fromEither(parseRoles(raws)).orElseFail(ValidationError("roles", "One or more invalid roles"))
      // Enforce invariant: primary role must be in the roles set
      _        <-
        ZIO
          .when(!rolesSet.contains(role))(
            ZIO.fail(ValidationError("roles", "Primary role must be included in roles"))
          )
      _        <- ZIO.when(rolesSet.isEmpty)(ZIO.fail(ValidationError("roles", "Roles must not be empty")))
      pwHash   <- hashPassword(request.password).orElseFail(ValidationError("password", "Failed to hash password"))
      person    = Person(
                    id = PersonId.generate(),
                    name = request.name,
                    email = request.email,
                    role = role,
                    passwordHash = pwHash,
                    phone = request.phone,
                    status = UserStatus.ACTIVE,
                    roles = rolesSet
                  )
      created  <- personRepository.create(person).orElseFail(ValidationError("user", "Failed to create user"))
      // If the new person has the Driver role, ensure a drivers row exists for location/status tracking
      _        <-
        ZIO
          .when(created.canDrive)(
            personRepository
              .upsertDriverRow(created.id)
              .orElseFail(ValidationError("user", "Failed to create driver row"))
          )
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

  override def updateUser(id: UUID, companyId: CompanyId, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      existingOpt <- personRepository.findByIdAndCompany(PersonId(id), companyId).orElseFail(UserNotFound(s"ID: $id"))
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
      // Resolve the new roles set: if provided, validate and use it; otherwise preserve existing
      rolesSet    <-
        request.roles match
          case None       => ZIO.succeed(existing.effectiveRoles)
          case Some(raws) =>
            ZIO.fromEither(parseRoles(raws)).orElseFail(ValidationError("roles", "One or more invalid roles"))
      // Enforce invariant: primary role must be in the roles set
      _           <-
        ZIO
          .when(!rolesSet.contains(role))(
            ZIO.fail(ValidationError("roles", "Primary role must be included in roles"))
          )
      _           <- ZIO.when(rolesSet.isEmpty)(ZIO.fail(ValidationError("roles", "Roles must not be empty")))
      updated      = request.applyTo(existing, role, status, rolesSet)
      saved       <- personRepository.update(updated).orElseFail(ValidationError("user", "Failed to update user"))
      // If Driver role was added (wasn't present before), ensure a drivers row exists
      driverAdded  = saved.canDrive && !existing.canDrive
      _           <-
        ZIO
          .when(driverAdded)(
            personRepository
              .upsertDriverRow(saved.id)
              .orElseFail(ValidationError("user", "Failed to create driver row"))
          )
    yield UserDto.fromPerson(saved)

  override def deleteUser(id: UUID, companyId: CompanyId): ZIO[Any, AuthError, Unit] =
    for
      personOpt <- personRepository.findByIdAndCompany(PersonId(id), companyId).orElseFail(UserNotFound(s"ID: $id"))
      _         <- ZIO.when(personOpt.isEmpty)(ZIO.fail(UserNotFound(s"ID: $id")))
      _         <- personRepository
                     .deleteInCompany(PersonId(id), companyId)
                     .orElseFail(ValidationError("user", "Failed to delete user"))
      _         <- tokenRepository.deleteByUserId(id).orElseFail(ValidationError("token", "Failed to delete tokens"))
    yield ()

  override def changePassword(
      userId: UUID,
      companyId: CompanyId,
      request: ChangePasswordRequest
  ): ZIO[Any, AuthError, Unit] =
    for
      _         <-
        ZIO.when(!validatePassword(request.newPassword))(
          ZIO.fail(WeakPassword("Password must be at least 8 characters with uppercase, lowercase, and digit"))
        )
      personOpt <- personRepository
                     .findByIdAndCompany(PersonId(userId), companyId)
                     .orElseFail(UserNotFound(s"ID: $userId"))
      person    <- ZIO.fromOption(personOpt).orElseFail(UserNotFound(s"ID: $userId"))
      pwMatch   <- checkPassword(request.currentPassword, person.passwordHash).orElseFail(
                     InvalidCredentials(person.email)
                   )
      _         <- ZIO.when(!pwMatch)(ZIO.fail(InvalidCredentials(person.email)))
      newHash   <- hashPassword(request.newPassword).orElseFail(ValidationError("password", "Failed to hash password"))
      updated    = person.copy(passwordHash = newHash)
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

  val live: ZLayer[PersonRepository & TokenRepository & SessionRepository & JwtService, Nothing, AuthService] = ZLayer
    .fromFunction(AuthServiceImpl.apply)
