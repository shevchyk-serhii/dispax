package com.shevchyk.auth.application

import com.shevchyk.auth.domain.*
import zio.*
import java.time.Instant
import java.security.MessageDigest
import java.util.Base64

trait AuthService:
  def login(email: String, password: String): ZIO[Any, AuthError, LoginResponse]
  def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto]
  def getUserById(id: Long): ZIO[Any, AuthError, UserDto]
  def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto]
  def updateUser(id: Long, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto]
  def deleteUser(id: Long): ZIO[Any, AuthError, Unit]
  def changePassword(userId: Long, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit]
  def validateToken(token: String): ZIO[Any, AuthError, UserDto]
  def getAllUsers(role: Option[UserRole] = None, status: Option[UserStatus] = None): ZIO[Any, AuthError, List[UserDto]]
  def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]]

class AuthServiceImpl extends AuthService:

  // Mock data storage - in real app would use database
  private val users = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        Ref.Synchronized.make(
          Map[Long, User](
            1L  -> User(
              1L,
              "test@example.com",
              "Test User",
              UserRole.CLIENT,
              hashPassword("password123"),
              Some("+1234567890"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            50L -> User(
              50L,
              "client@example.com",
              "Client User",
              UserRole.CLIENT,
              hashPassword("password123"),
              Some("+1111111111"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            10L -> User(
              10L,
              "driver@example.com",
              "Driver User",
              UserRole.DRIVER,
              hashPassword("password123"),
              Some("+2222222222"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            99L -> User(
              99L,
              "admin@example.com",
              "Admin User",
              UserRole.ADMIN,
              hashPassword("password123"),
              Some("+3333333333"),
              UserStatus.ACTIVE,
              Instant.now()
            )
          )
        )
      )
      .getOrThrow()
  }

  private val tokens = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        Ref.Synchronized.make(
          Map[String, Long](
            "valid-token-1"  -> 1L,
            "valid-token-50" -> 50L,
            "valid-token-10" -> 10L,
            "valid-token-99" -> 99L
          )
        )
      )
      .getOrThrow()
  }

  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    val hash   = digest.digest(password.getBytes("UTF-8"))
    Base64.getEncoder.encodeToString(hash)

  private def generateToken(userId: Long): String = s"valid-token-$userId"

  private def validateEmail(email: String): Boolean = email.contains("@") && email.length > 5

  private def validatePassword(password: String): Boolean = password.length >= 6

  override def login(email: String, password: String): ZIO[Any, AuthError, LoginResponse] =
    for
      userMap <- users.get
      user    <- ZIO.fromOption(userMap.values.find(_.email == email)).orElseFail(UserNotFound(email))
      _       <- ZIO.when(user.passwordHash != hashPassword(password))(ZIO.fail(InvalidCredentials(email)))
      token    = generateToken(user.id)
      _       <- tokens.update(_.updated(token, user.id))
    yield LoginResponse(UserDto.fromDomain(user), token)

  override def createUser(request: CreateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      _       <- ZIO.when(!validateEmail(request.email))(ZIO.fail(ValidationError("email", "Invalid email format")))
      _       <-
        ZIO.when(!validatePassword(request.password))(ZIO.fail(WeakPassword("Password must be at least 6 characters")))
      _       <- ZIO.when(request.name.trim.isEmpty)(ZIO.fail(ValidationError("name", "Name cannot be empty")))
      userMap <- users.get
      _       <- ZIO.when(userMap.values.exists(_.email == request.email))(ZIO.fail(UserAlreadyExists(request.email)))
      role    <- ZIO.attempt(UserRole.valueOf(request.role)).mapError(_ => ValidationError("role", "Invalid role"))
      newId    = userMap.keys.maxOption.getOrElse(0L) + 1
      newUser  = User(
                   id = newId,
                   email = request.email,
                   name = request.name,
                   role = role,
                   passwordHash = hashPassword(request.password),
                   phone = request.phone,
                   status = UserStatus.ACTIVE,
                   createdAt = Instant.now()
                 )
      _       <- users.update(_.updated(newId, newUser))
    yield UserDto.fromDomain(newUser)

  override def getUserById(id: Long): ZIO[Any, AuthError, UserDto] =
    for
      userMap <- users.get
      user    <- ZIO.fromOption(userMap.get(id)).orElseFail(UserNotFound(s"ID: $id"))
    yield UserDto.fromDomain(user)

  override def getUserByEmail(email: String): ZIO[Any, AuthError, UserDto] =
    for
      userMap <- users.get
      user    <- ZIO.fromOption(userMap.values.find(_.email == email)).orElseFail(UserNotFound(email))
    yield UserDto.fromDomain(user)

  override def updateUser(id: Long, request: UpdateUserRequest): ZIO[Any, AuthError, UserDto] =
    for
      userMap      <- users.get
      existingUser <- ZIO.fromOption(userMap.get(id)).orElseFail(UserNotFound(s"ID: $id"))
      _            <-
        request.email.fold(ZIO.unit)(email =>
          ZIO.when(!validateEmail(email))(ZIO.fail(ValidationError("email", "Invalid email format")))
        )
      role         <-
        request.role.fold(ZIO.succeed(existingUser.role))(r =>
          ZIO.attempt(UserRole.valueOf(r)).mapError(_ => ValidationError("role", "Invalid role"))
        )
      status       <-
        request.status.fold(ZIO.succeed(existingUser.status))(s =>
          ZIO.attempt(UserStatus.valueOf(s)).mapError(_ => ValidationError("status", "Invalid status"))
        )
      updatedUser   = existingUser.copy(
                        email = request.email.getOrElse(existingUser.email),
                        name = request.name.getOrElse(existingUser.name),
                        role = role,
                        phone = request.phone.orElse(existingUser.phone),
                        status = status,
                        updatedAt = Some(Instant.now())
                      )
      _            <- users.update(_.updated(id, updatedUser))
    yield UserDto.fromDomain(updatedUser)

  override def deleteUser(id: Long): ZIO[Any, AuthError, Unit] =
    for
      userMap <- users.get
      _       <- ZIO.when(!userMap.contains(id))(ZIO.fail(UserNotFound(s"ID: $id")))
      _       <- users.update(_ - id)
      _       <- tokens.update(_.filter(_._2 != id)) // Remove all tokens for this user
    yield ()

  override def changePassword(userId: Long, request: ChangePasswordRequest): ZIO[Any, AuthError, Unit] =
    for
      _          <-
        ZIO.when(!validatePassword(request.newPassword))(
          ZIO.fail(WeakPassword("Password must be at least 6 characters"))
        )
      userMap    <- users.get
      user       <- ZIO.fromOption(userMap.get(userId)).orElseFail(UserNotFound(s"ID: $userId"))
      _          <-
        ZIO.when(user.passwordHash != hashPassword(request.currentPassword))(ZIO.fail(InvalidCredentials(user.email)))
      updatedUser = user.copy(passwordHash = hashPassword(request.newPassword), updatedAt = Some(Instant.now()))
      _          <- users.update(_.updated(userId, updatedUser))
    yield ()

  override def validateToken(token: String): ZIO[Any, AuthError, UserDto] =
    for
      tokenMap <- tokens.get
      userId   <- ZIO.fromOption(tokenMap.get(token)).orElseFail(InvalidToken(token))
      user     <- getUserById(userId)
    yield user

  override def getAllUsers(role: Option[UserRole], status: Option[UserStatus]): ZIO[Any, AuthError, List[UserDto]] =
    for
      userMap      <- users.get
      filteredUsers =
        userMap.values.filter { user =>
          role.forall(_ == user.role) && status.forall(_ == user.status)
        }.toList
    yield filteredUsers.map(UserDto.fromDomain)

  override def searchUsers(query: String): ZIO[Any, AuthError, List[UserDto]] =
    for
      userMap      <- users.get
      matchingUsers =
        userMap.values.filter { user =>
          user.name.toLowerCase.contains(query.toLowerCase) ||
          user.email.toLowerCase.contains(query.toLowerCase)
        }.toList
    yield matchingUsers.map(UserDto.fromDomain)

object AuthService:
  val live: ZLayer[Any, Nothing, AuthService] = ZLayer.succeed(AuthServiceImpl())
