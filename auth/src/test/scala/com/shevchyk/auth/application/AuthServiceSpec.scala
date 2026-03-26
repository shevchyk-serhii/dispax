package com.shevchyk.auth.application

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.core.domain.{PersonRole, UserStatus}
import com.shevchyk.auth.repository.{InMemoryPersonRepositoryWithUsers, InMemoryTokenRepository, TestLayers, TestUUIDs}
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.test.*
import java.util.UUID

object AuthServiceSpec extends ZIOSpecDefault {

  import TestUUIDs.*

  /** Fresh layers per test — InMemoryPersonRepository/TokenRepository hold mutable Refs,
    * so sharing a single instance across tests would couple test outcomes to execution order.
    * Using `def` ensures each `.provide(layers)` call gets fresh repository instances.
    */
  def layers: ZLayer[Any, Nothing, AuthService] =
    (ZLayer.succeed(InMemoryPersonRepositoryWithUsers()) ++
      ZLayer.succeed(InMemoryTokenRepository()) ++
      (JwtConfig.live >>> JwtService.live)) >>> AuthService.live

  def spec = suite("AuthService")(
    suite("login")(
      test("valid credentials returns LoginResponse with JWT") {
        for {
          service  <- ZIO.service[AuthService]
          response <- service.login("test@example.com", "Password123")
        } yield assertTrue(
          response.person.email == "test@example.com" &&
          response.person.name == "Test User" &&
          response.person.role == "CLIENT" &&
          response.token.nonEmpty
        )
      }.provide(layers),

      test("unknown email returns UserNotFound") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.login("nonexistent@example.com", "Password123").exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers),

      test("wrong password returns InvalidCredentials") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.login("test@example.com", "wrongpassword").exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[InvalidCredentials])
          case _                   => false
        })
      }.provide(layers),

      test("login works for driver user") {
        for {
          service  <- ZIO.service[AuthService]
          response <- service.login("driver@example.com", "Password123")
        } yield assertTrue(
          response.person.email == "driver@example.com" &&
          response.person.role == "DRIVER"
        )
      }.provide(layers),

      test("login works for admin user") {
        for {
          service  <- ZIO.service[AuthService]
          response <- service.login("admin@example.com", "Password123")
        } yield assertTrue(
          response.person.email == "admin@example.com" &&
          response.person.role == "ADMIN"
        )
      }.provide(layers)
    ),

    suite("createUser")(
      test("valid request creates user with ACTIVE status") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.createUser(CreateUserRequest(
                       email = "newuser@example.com",
                       name = "New User",
                       role = "CLIENT",
                       password = "Secure123"
                     ))
        } yield assertTrue(
          user.email == "newuser@example.com" &&
          user.name == "New User" &&
          user.role == "CLIENT" &&
          user.status.contains("ACTIVE")
        )
      }.provide(layers),

      test("invalid email returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.createUser(CreateUserRequest(
                       email = "not-an-email",
                       name = "Test",
                       role = "CLIENT",
                       password = "Secure123"
                     )).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("email", _) => true
            case _                           => false
          }
          case _ => false
        })
      }.provide(layers),

      test("short password returns WeakPassword") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.createUser(CreateUserRequest(
                       email = "weak@example.com",
                       name = "Test",
                       role = "CLIENT",
                       password = "12345"
                     )).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[WeakPassword])
          case _                   => false
        })
      }.provide(layers),

      test("empty name returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.createUser(CreateUserRequest(
                       email = "empty@example.com",
                       name = "   ",
                       role = "CLIENT",
                       password = "Secure123"
                     )).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("name", _) => true
            case _                          => false
          }
          case _ => false
        })
      }.provide(layers),

      test("duplicate email returns UserAlreadyExists") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.createUser(CreateUserRequest(
                       email = "test@example.com",
                       name = "Duplicate",
                       role = "CLIENT",
                       password = "Secure123"
                     )).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserAlreadyExists])
          case _                   => false
        })
      }.provide(layers),

      test("invalid role returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.createUser(CreateUserRequest(
                       email = "role@example.com",
                       name = "Test",
                       role = "INVALID_ROLE",
                       password = "Secure123"
                     )).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("role", _) => true
            case _                          => false
          }
          case _ => false
        })
      }.provide(layers),

      test("creates user with phone number") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.createUser(CreateUserRequest(
                       email = "phone@example.com",
                       name = "Phone User",
                       role = "DRIVER",
                       password = "Secure123",
                       phone = Some("+1234567890")
                     ))
        } yield assertTrue(
          user.phone.contains("+1234567890") &&
          user.role == "DRIVER"
        )
      }.provide(layers)
    ),

    suite("getUserById")(
      test("returns user for valid ID") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.getUserById(testUserId1)
        } yield assertTrue(
          user.email == "test@example.com" &&
          user.name == "Test User"
        )
      }.provide(layers),

      test("returns error for unknown ID") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.getUserById(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers)
    ),

    suite("getUserByEmail")(
      test("returns user for valid email") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.getUserByEmail("driver@example.com")
        } yield assertTrue(
          user.name == "Driver User" &&
          user.role == "DRIVER"
        )
      }.provide(layers),

      test("returns error for unknown email") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.getUserByEmail("nobody@example.com").exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers)
    ),

    suite("updateUser")(
      test("partial update changes only specified fields") {
        for {
          service <- ZIO.service[AuthService]
          updated <- service.updateUser(testUserId1, UpdateUserRequest(name = Some("Updated Name")))
        } yield assertTrue(
          updated.name == "Updated Name" &&
          updated.email == "test@example.com" &&
          updated.role == "CLIENT"
        )
      }.provide(layers),

      test("returns error for unknown user") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.updateUser(
                       UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                       UpdateUserRequest(name = Some("Test"))
                     ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers),

      test("invalid email in update returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.updateUser(testUserId1, UpdateUserRequest(email = Some("bad-email"))).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("email", _) => true
            case _                           => false
          }
          case _ => false
        })
      }.provide(layers),

      test("invalid role in update returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.updateUser(testUserId1, UpdateUserRequest(role = Some("INVALID"))).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("role", _) => true
            case _                          => false
          }
          case _ => false
        })
      }.provide(layers),

      test("invalid status in update returns ValidationError") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.updateUser(testUserId1, UpdateUserRequest(status = Some("INVALID"))).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case ValidationError("status", _) => true
            case _                            => false
          }
          case _ => false
        })
      }.provide(layers),

      test("preserves unchanged fields") {
        for {
          service  <- ZIO.service[AuthService]
          original <- service.getUserById(testUserId10)
          updated  <- service.updateUser(testUserId10, UpdateUserRequest(name = Some("New Name")))
        } yield assertTrue(
          updated.name == "New Name" &&
          updated.email == original.email &&
          updated.role == original.role &&
          updated.phone == original.phone
        )
      }.provide(layers)
    ),

    suite("deleteUser")(
      test("deletes existing user") {
        for {
          service <- ZIO.service[AuthService]
          // Create a user first to delete
          user    <- service.createUser(CreateUserRequest(
                       email = "todelete@example.com",
                       name = "To Delete",
                       role = "CLIENT",
                       password = "Secure123"
                     ))
          _       <- service.deleteUser(user.id)
          result  <- service.getUserById(user.id).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers),

      test("returns error for unknown user") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.deleteUser(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers)
    ),

    suite("changePassword")(
      test("happy path with correct current password") {
        for {
          service <- ZIO.service[AuthService]
          // Create user, then change password, then login with new password
          user    <- service.createUser(CreateUserRequest(
                       email = "changepw@example.com",
                       name = "Change PW",
                       role = "CLIENT",
                       password = "OldPassword1"
                     ))
          _       <- service.changePassword(user.id, ChangePasswordRequest("OldPassword1", "NewPassword1"))
          result  <- service.login("changepw@example.com", "NewPassword1")
        } yield assertTrue(result.person.email == "changepw@example.com")
      }.provide(layers),

      test("wrong current password returns InvalidCredentials") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.changePassword(testUserId1, ChangePasswordRequest("wrongcurrent", "NewPass123")).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[InvalidCredentials])
          case _                   => false
        })
      }.provide(layers),

      test("weak new password returns WeakPassword") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.changePassword(testUserId1, ChangePasswordRequest("Password123", "short")).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[WeakPassword])
          case _                   => false
        })
      }.provide(layers)
    ),

    suite("validateToken")(
      test("valid JWT returns UserDto") {
        for {
          service  <- ZIO.service[AuthService]
          login    <- service.login("test@example.com", "Password123")
          userDto  <- service.validateToken(login.token)
        } yield assertTrue(
          userDto.email == "test@example.com" &&
          userDto.role == "CLIENT"
        )
      }.provide(layers),

      test("invalid token returns error") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.validateToken("invalid.jwt.token").exit
        } yield assertTrue(result.isFailure)
      }.provide(layers)
    ),

    suite("getAllUsers")(
      test("no filter returns all users") {
        for {
          service <- ZIO.service[AuthService]
          users   <- service.getAllUsers()
        } yield assertTrue(users.size >= 4)
      }.provide(layers),

      test("filter by role returns matching users") {
        for {
          service <- ZIO.service[AuthService]
          clients <- service.getAllUsers(role = Some(PersonRole.Client))
        } yield assertTrue(
          clients.forall(_.role == "CLIENT") &&
          clients.nonEmpty
        )
      }.provide(layers),

      test("filter by status returns matching users") {
        for {
          service     <- ZIO.service[AuthService]
          activeUsers <- service.getAllUsers(status = Some(UserStatus.ACTIVE))
        } yield assertTrue(
          activeUsers.forall(_.status.contains("ACTIVE")) &&
          activeUsers.nonEmpty
        )
      }.provide(layers),

      test("filter by role and status") {
        for {
          service <- ZIO.service[AuthService]
          result  <- service.getAllUsers(role = Some(PersonRole.Admin), status = Some(UserStatus.ACTIVE))
        } yield assertTrue(
          result.forall(u => u.role == "ADMIN" && u.status.contains("ACTIVE"))
        )
      }.provide(layers)
    ),

    suite("searchUsers")(
      test("match by name") {
        for {
          service <- ZIO.service[AuthService]
          results <- service.searchUsers("Test")
        } yield assertTrue(results.exists(_.name.contains("Test")))
      }.provide(layers),

      test("match by email") {
        for {
          service <- ZIO.service[AuthService]
          results <- service.searchUsers("driver@")
        } yield assertTrue(results.exists(_.email.contains("driver@")))
      }.provide(layers),

      test("no matches returns empty") {
        for {
          service <- ZIO.service[AuthService]
          results <- service.searchUsers("zzzznonexistent")
        } yield assertTrue(results.isEmpty)
      }.provide(layers)
    )
  )
}
