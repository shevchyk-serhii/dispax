package com.shevchyk.auth.repository

import com.shevchyk.auth.domain.*
import zio.*
import java.time.Instant
import java.util.UUID
import org.mindrot.jbcrypt.BCrypt

object TestUUIDs:
  val testUserId1 = UUID.fromString("11111111-1111-1111-1111-111111111111")
  val testUserId50 = UUID.fromString("50505050-5050-5050-5050-505050505050")
  val testUserId10 = UUID.fromString("10101010-1010-1010-1010-101010101010")
  val testUserId99 = UUID.fromString("99999999-9999-9999-9999-999999999999")

final class InMemoryUserRepository extends UserRepository:
  import TestUUIDs._

  private def hashPassword(password: String): String =
    BCrypt.hashpw(password, BCrypt.gensalt(12))

  private val users = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        Ref.Synchronized.make(
          Map[UUID, User](
            testUserId1  -> User(
              testUserId1,
              "test@example.com",
              "Test User",
              UserRole.CLIENT,
              hashPassword("password123"),
              Some("+1234567890"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            testUserId50 -> User(
              testUserId50,
              "client@example.com",
              "Client User",
              UserRole.CLIENT,
              hashPassword("password123"),
              Some("+1111111111"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            testUserId10 -> User(
              testUserId10,
              "driver@example.com",
              "Driver User",
              UserRole.DRIVER,
              hashPassword("password123"),
              Some("+2222222222"),
              UserStatus.ACTIVE,
              Instant.now()
            ),
            testUserId99 -> User(
              testUserId99,
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
      newId    = UUID.randomUUID()
      newUser  = user.copy(id = newId, createdAt = Instant.now())
      _       <- users.update(_.updated(newId, newUser))
    yield newUser

  override def findById(id: UUID): Task[Option[User]] =
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
    yield userMap.values.toList.sortBy(_.id.toString)

  override def findByRole(role: UserRole): Task[List[User]] =
    for
      userMap <- users.get
    yield userMap.values.filter(_.role == role).toList.sortBy(_.id.toString)

  override def findByStatus(status: UserStatus): Task[List[User]] =
    for
      userMap <- users.get
    yield userMap.values.filter(_.status == status).toList.sortBy(_.id.toString)

  override def update(user: User): Task[User] =
    for
      updatedUser <- ZIO.succeed(user.copy(updatedAt = Some(Instant.now())))
      _          <- users.update(_.updated(user.id, updatedUser))
    yield updatedUser

  override def delete(id: UUID): Task[Unit] =
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
        }.toList.sortBy(_.id.toString)
    yield matchingUsers

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
    for
      _ <- tokens.update(_.updated(token, userId))
    yield ()

  override def findUserIdByToken(token: String): Task[Option[UUID]] =
    for
      tokenMap <- tokens.get
    yield tokenMap.get(token)

  override def deleteByToken(token: String): Task[Unit] =
    for
      _ <- tokens.update(_ - token)
    yield ()

  override def deleteByUserId(userId: UUID): Task[Unit] =
    for
      tokenMap <- tokens.get
      tokensToDelete = tokenMap.filter(_._2 == userId).keys
      _ <- tokens.update(map => tokensToDelete.foldLeft(map)((acc, token) => acc - token))
    yield ()