package com.shevchyk.auth.application

import com.shevchyk.auth.domain.*
import com.shevchyk.auth.repository.*
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.json.*
import java.time.Instant
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID
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
  def getAllUsers(role: Option[UserRole] = None, status: Option[UserStatus] = None): ZIO[Any, AuthError, List[UserDto]]
  def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]]

class AuthServiceImpl(userRepository: UserRepository, tokenRepository: TokenRepository, jwtService: JwtService)
    extends AuthService:

  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    val hash   = digest.digest(password.getBytes("UTF-8"))
    Base64.getEncoder.encodeToString(hash)

  private def validateEmail(email: String): Boolean = email.contains("@") && email.length > 5

  private def validatePassword(password: String): Boolean = password.length >= 6

  override def login(email: String, password: String): ZIO[Any, AuthError, LoginResponse] =
    for
      userOpt <- userRepository.findByEmail(email).orElseFail(UserNotFound(email))
      user    <- ZIO.fromOption(userOpt).orElseFail(UserNotFound(email))
      _       <- ZIO.when(user.passwordHash != hashPassword(password))(ZIO.fail(InvalidCredentials(email)))
      token   <- jwtService.generateToken(user).mapError(identity)
      _       <- tokenRepository.create(token, user.id).orElseFail(ValidationError("token", "Failed to store token"))
    yield LoginResponse(UserDto.fromDomain(user), token)

  override def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      _           <- ZIO.when(!validateEmail(request.email))(ZIO.fail(ValidationError("email", "Invalid email format")))
      _           <-
        ZIO.when(!validatePassword(request.password))(ZIO.fail(WeakPassword("Password must be at least 6 characters")))
      _           <- ZIO.when(request.name.trim.isEmpty)(ZIO.fail(ValidationError("name", "Name cannot be empty")))
      existing    <- userRepository.findByEmail(request.email).orElseFail(ValidationError("email", "Database error"))
      _           <- ZIO.when(existing.isDefined)(ZIO.fail(UserAlreadyExists(request.email)))
      role        <- ZIO.attempt(UserRole.valueOf(request.role)).orElseFail(ValidationError("role", "Invalid role"))
      newUser      = User(
                       id = UuidCreator.getTimeOrderedEpoch(),
                       email = request.email,
                       name = request.name,
                       role = role,
                       passwordHash = hashPassword(request.password),
                       phone = request.phone,
                       status = UserStatus.ACTIVE,
                       createdAt = Instant.now()
                     )
      createdUser <- userRepository.create(newUser).orElseFail(ValidationError("user", "Failed to create user"))
    yield UserDto.fromDomain(createdUser)

  override def getUserById(id: UUID): ZIO[Any, AuthError, UserDto] =
    for
      userOpt <- userRepository.findById(id).orElseFail(UserNotFound(s"ID: $id"))
      user    <- ZIO.fromOption(userOpt).orElseFail(UserNotFound(s"ID: $id"))
    yield UserDto.fromDomain(user)

  override def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto] =
    for
      userOpt <- userRepository.findByEmail(email).orElseFail(UserNotFound(email))
      user    <- ZIO.fromOption(userOpt).orElseFail(UserNotFound(email))
    yield UserDto.fromDomain(user)

  override def updateUser(id: UUID, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      existingUserOpt <- userRepository.findById(id).orElseFail(UserNotFound(s"ID: $id"))
      existingUser    <- ZIO.fromOption(existingUserOpt).orElseFail(UserNotFound(s"ID: $id"))
      _               <-
        request.email.fold(ZIO.unit)(email =>
          ZIO.when(!validateEmail(email))(ZIO.fail(ValidationError("email", "Invalid email format")))
        )
      role            <-
        request.role.fold(ZIO.succeed(existingUser.role))(r =>
          ZIO.attempt(UserRole.valueOf(r)).orElseFail(ValidationError("role", "Invalid role"))
        )
      status          <-
        request.status.fold(ZIO.succeed(existingUser.status))(s =>
          ZIO.attempt(UserStatus.valueOf(s)).orElseFail(ValidationError("status", "Invalid status"))
        )
      updatedUser      = existingUser.copy(
                           email = request.email.getOrElse(existingUser.email),
                           name = request.name.getOrElse(existingUser.name),
                           role = role,
                           phone = request.phone.orElse(existingUser.phone),
                           status = status,
                           updatedAt = Some(Instant.now())
                         )
      saved           <- userRepository.update(updatedUser).orElseFail(ValidationError("user", "Failed to update user"))
    yield UserDto.fromDomain(saved)

  override def deleteUser(id: UUID): ZIO[Any, AuthError, Unit] =
    for
      userOpt <- userRepository.findById(id).orElseFail(UserNotFound(s"ID: $id"))
      _       <- ZIO.when(userOpt.isEmpty)(ZIO.fail(UserNotFound(s"ID: $id")))
      _       <- userRepository.delete(id).orElseFail(ValidationError("user", "Failed to delete user"))
      _       <- tokenRepository.deleteByUserId(id).orElseFail(ValidationError("token", "Failed to delete tokens"))
    yield ()

  override def changePassword(userId: UUID, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit] =
    for
      _          <-
        ZIO.when(!validatePassword(request.newPassword))(
          ZIO.fail(WeakPassword("Password must be at least 6 characters"))
        )
      userOpt    <- userRepository.findById(userId).orElseFail(UserNotFound(s"ID: $userId"))
      user       <- ZIO.fromOption(userOpt).orElseFail(UserNotFound(s"ID: $userId"))
      _          <-
        ZIO.when(user.passwordHash != hashPassword(request.currentPassword))(ZIO.fail(InvalidCredentials(user.email)))
      updatedUser = user.copy(passwordHash = hashPassword(request.newPassword), updatedAt = Some(Instant.now()))
      _          <- userRepository.update(updatedUser).orElseFail(ValidationError("user", "Failed to update password"))
    yield ()

  override def validateToken(token: String): ZIO[Any, AuthError, UserDto] =
    for
      payload <- jwtService.validateToken(token).mapError(identity)
      user    <- getUserById(payload.userId)
      // Verify that the user still exists and matches the token
      _       <- ZIO.when(user.email != payload.email)(ZIO.fail(InvalidToken(token)))
    yield user

  override def getAllUsers(role: Option[UserRole], status: Option[UserStatus]): ZIO[Any, AuthError, List[UserDto]] =
    for
      allUsers     <- userRepository.findAll().orElseFail(ValidationError("user", "Failed to fetch users"))
      filteredUsers = allUsers.filter { user =>
                        role.forall(_ == user.role) && status.forall(_ == user.status)
                      }
    yield filteredUsers.map(UserDto.fromDomain)

  override def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]] =
    for matchingUsers <- userRepository
                           .searchByQuery(query)
                           .orElseFail(ValidationError("user", "Failed to search users"))
    yield matchingUsers.map(UserDto.fromDomain)

  override def refreshToken(token: String): ZIO[Any, AuthError, String] = jwtService
    .refreshToken(token)
    .mapError(identity)

object AuthService:

  val live: ZLayer[UserRepository & TokenRepository & JwtService, Nothing, AuthService] = ZLayer.fromFunction(
    AuthServiceImpl.apply
  )
