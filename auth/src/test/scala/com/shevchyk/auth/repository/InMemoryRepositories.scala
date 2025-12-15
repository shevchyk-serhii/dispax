package com.shevchyk.auth.repository

import com.shevchyk.auth.domain.*
import zio.*
import java.time.Instant
import java.security.MessageDigest
import java.util.Base64

final class InMemoryUserRepository extends UserRepository:

  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    val hash   = digest.digest(password.getBytes("UTF-8"))
    Base64.getEncoder.encodeToString(hash)

  // Mock data storage - for testing only
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

  override def create(user: User): Task[User] =
    for
      userMap <- users.get
      newId    = userMap.keys.maxOption.getOrElse(0L) + 1
      newUser  = user.copy(id = newId, createdAt = Instant.now())
      _       <- users.update(_.updated(newId, newUser))
    yield newUser

  override def findById(id: Long): Task[Option[User]] =
    for
      userMap <- users.get
    yield userMap.get(id)

  override def findByEmail(email: String): Task[Option[User]] =
    for
      userMap <- users.get
    yield userMap.values.find(_.email == email)

  override def findAll(): Task[List[User]] =
    for
      userMap <- users.get
    yield userMap.values.toList.sortBy(_.id)

  override def findByRole(role: UserRole): Task[List[User]] =
    for
      userMap <- users.get
    yield userMap.values.filter(_.role == role).toList.sortBy(_.id)

  override def findByStatus(status: UserStatus): Task[List[User]] =
    for
      userMap <- users.get
    yield userMap.values.filter(_.status == status).toList.sortBy(_.id)

  override def update(user: User): Task[User] =
    for
      updatedUser <- ZIO.succeed(user.copy(updatedAt = Some(Instant.now())))
      _          <- users.update(_.updated(user.id, updatedUser))
    yield updatedUser

  override def delete(id: Long): Task[Unit] =
    for
      _ <- users.update(_ - id)
    yield ()

  override def searchByQuery(query: String): Task[List[User]] =
    for
      userMap <- users.get
      matchingUsers =
        userMap.values.filter { user =>
          user.name.toLowerCase.contains(query.toLowerCase) ||
          user.email.toLowerCase.contains(query.toLowerCase)
        }.toList.sortBy(_.id)
    yield matchingUsers

final class InMemoryTokenRepository extends TokenRepository:

  // Mock tokens storage - for testing only
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

  override def create(token: String, userId: Long): Task[Unit] =
    for
      _ <- tokens.update(_.updated(token, userId))
    yield ()

  override def findUserIdByToken(token: String): Task[Option[Long]] =
    for
      tokenMap <- tokens.get
    yield tokenMap.get(token)

  override def deleteByToken(token: String): Task[Unit] =
    for
      _ <- tokens.update(_ - token)
    yield ()

  override def deleteByUserId(userId: Long): Task[Unit] =
    for
      tokenMap <- tokens.get
      tokensToDelete = tokenMap.filter(_._2 == userId).keys
      _ <- tokens.update(map => tokensToDelete.foldLeft(map)((acc, token) => acc - token))
    yield ()