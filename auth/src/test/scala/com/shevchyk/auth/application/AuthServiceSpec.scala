package com.shevchyk.auth.application

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.core.domain.{CompanyId, Person, PersonId, PersonRole, UserStatus}
import com.shevchyk.core.repository.{InMemorySessionRepository, PersonRepository, SessionRepository}
import com.shevchyk.auth.repository.{InMemoryPersonRepositoryWithUsers, InMemoryTokenRepository, TestLayers, TestUUIDs}
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.test.*
import java.util.UUID

object AuthServiceSpec extends ZIOSpecDefault {

  import TestUUIDs.*

  /**
   * Fresh layers per test — InMemoryPersonRepository/TokenRepository hold mutable Refs, so sharing a single instance
   * across tests would couple test outcomes to execution order. Using `def` ensures each `.provide(layers)` call gets
   * fresh repository instances.
   */
  def layers: ZLayer[Any, Nothing, AuthService] =
    (ZLayer.succeed(InMemoryPersonRepositoryWithUsers()) ++
      ZLayer.succeed(InMemoryTokenRepository()) ++
      ZLayer.succeed[SessionRepository](InMemorySessionRepository()) ++
      (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live

  // Like `layers`, but also exposes the underlying PersonRepository so a test can seed/inspect
  // rows directly (used by the tenant-scoped deleteUser tests).
  def layersWithRepo: ZLayer[Any, Nothing, AuthService & PersonRepository] = {
    val repo = ZLayer.succeed[PersonRepository](InMemoryPersonRepositoryWithUsers())
    val auth =
      (repo ++ ZLayer.succeed(InMemoryTokenRepository()) ++
        ZLayer.succeed[SessionRepository](InMemorySessionRepository()) ++
        (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live
    repo ++ auth
  }

  // Like `layers`, but also exposes the SessionRepository so a login test can assert the
  // session row created as part of the login transaction.
  def layersWithSessionRepo: ZLayer[Any, Nothing, AuthService & SessionRepository] = {
    val sessions = ZLayer.succeed[SessionRepository](InMemorySessionRepository())
    val auth     =
      (ZLayer.succeed(InMemoryPersonRepositoryWithUsers()) ++
        ZLayer.succeed(InMemoryTokenRepository()) ++ sessions ++
        (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live
    sessions ++ auth
  }

  def spec =
    suite("AuthService")(
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
        }.provide(layers),
        test("login creates an active session carrying the JWT, device info and IP") {
          for {
            service  <- ZIO.service[AuthService]
            response <- service.login("test@example.com", "Password123", Some("UA/1.0"), Some("1.2.3.4"))
            sessions <- ZIO.service[SessionRepository]
            session  <- sessions.findByToken(response.token)
          } yield assertTrue(
            session.exists(s =>
              s.isActive &&
                s.token == response.token &&
                s.deviceInfo.contains("UA/1.0") &&
                s.ipAddress.contains("1.2.3.4")
            )
          )
        }.provide(layersWithSessionRepo),
        test("login without device info stores a session with no deviceInfo/ipAddress") {
          for {
            service  <- ZIO.service[AuthService]
            response <- service.login("test@example.com", "Password123")
            sessions <- ZIO.service[SessionRepository]
            session  <- sessions.findByToken(response.token)
          } yield assertTrue(
            session.exists(s => s.deviceInfo.isEmpty && s.ipAddress.isEmpty)
          )
        }.provide(layersWithSessionRepo)
      ),
      suite("createUser")(
        test("valid request creates user with ACTIVE status") {
          for {
            service <- ZIO.service[AuthService]
            user    <- service.createUser(
                         CreateUserRequest(
                           email = "newuser@example.com",
                           name = "New User",
                           role = "CLIENT",
                           password = "Secure123"
                         )
                       )
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
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "not-an-email",
                    name = "Test",
                    role = "CLIENT",
                    password = "Secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("email", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("short password returns WeakPassword") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "weak@example.com",
                    name = "Test",
                    role = "CLIENT",
                    password = "12345"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[WeakPassword])
            case _                   => false
          })
        }.provide(layers),
        test("empty name returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "empty@example.com",
                    name = "   ",
                    role = "CLIENT",
                    password = "Secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("name", _) => true
                case _                          => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("duplicate email returns UserAlreadyExists") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "test@example.com",
                    name = "Duplicate",
                    role = "CLIENT",
                    password = "Secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserAlreadyExists])
            case _                   => false
          })
        }.provide(layers),
        test("invalid role returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "role@example.com",
                    name = "Test",
                    role = "INVALID_ROLE",
                    password = "Secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("role", _) => true
                case _                          => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("creates user with phone number") {
          for {
            service <- ZIO.service[AuthService]
            user    <- service.createUser(
                         CreateUserRequest(
                           email = "phone@example.com",
                           name = "Phone User",
                           role = "DRIVER",
                           password = "Secure123",
                           phone = Some("+1234567890")
                         )
                       )
          } yield assertTrue(
            user.phone.contains("+1234567890") &&
              user.role == "DRIVER"
          )
        }.provide(layers),
        test("invalid phone returns ValidationError(\"phone\")") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "phone2@example.com",
                    name = "Bad Phone",
                    role = "CLIENT",
                    password = "Secure123",
                    phone = Some("abc")
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("phone", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("password without uppercase returns WeakPassword") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "noupper@example.com",
                    name = "No Upper",
                    role = "CLIENT",
                    password = "secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[WeakPassword])
            case _                   => false
          })
        }.provide(layers),
        test("password without a digit returns WeakPassword") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "nodigit@example.com",
                    name = "No Digit",
                    role = "CLIENT",
                    password = "SecurePass"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[WeakPassword])
            case _                   => false
          })
        }.provide(layers),
        test("email without a dotted domain returns ValidationError(\"email\")") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "user@localhost",
                    name = "No Dot",
                    role = "CLIENT",
                    password = "Secure123"
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("email", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        // ── multi-role (dispatcher-can-drive) ──────────────────────────────
        test("createUser with roles=[DISPATCHER,DRIVER] stores both and primary is in set") {
          for {
            service <- ZIO.service[AuthService]
            user    <- service.createUser(
                         CreateUserRequest(
                           email = "dispdrv@example.com",
                           name = "Disp Driver",
                           role = "DISPATCHER",
                           password = "Secure123",
                           roles = Some(List("DISPATCHER", "DRIVER"))
                         )
                       )
          } yield assertTrue(
            user.role == "DISPATCHER",
            user.roles.contains("DISPATCHER"),
            user.roles.contains("DRIVER")
          )
        }.provide(layers),
        test("createUser with roles where primary not in roles returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "bdroles@example.com",
                    name = "Bad Roles",
                    role = "DISPATCHER",
                    password = "Secure123",
                    roles = Some(List("DRIVER")) // primary DISPATCHER missing from roles
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("roles", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("createUser with invalid role string in roles returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .createUser(
                  CreateUserRequest(
                    email = "badrole2@example.com",
                    name = "Bad Role",
                    role = "DISPATCHER",
                    password = "Secure123",
                    roles = Some(List("DISPATCHER", "FLYING_SAUCER"))
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("roles", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("createUser without roles defaults to Set(primary role)") {
          for {
            service <- ZIO.service[AuthService]
            user    <- service.createUser(
                         CreateUserRequest(
                           email = "noroles@example.com",
                           name = "No Roles",
                           role = "DISPATCHER",
                           password = "Secure123"
                           // roles not set
                         )
                       )
          } yield assertTrue(
            user.role == "DISPATCHER",
            user.roles.contains("DISPATCHER"),
            user.roles.size == 1
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
      suite("updateUser — preferredLanguage")(
        // ── per-user locale (user-language-selection) ─────────────────────
        test("valid preferredLanguage 'de' is saved and returned") {
          for {
            service <- ZIO.service[AuthService]
            updated <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("de")))
          } yield assertTrue(updated.preferredLanguage.contains("de"))
        }.provide(layers),
        test("valid preferredLanguage 'en' is saved and returned") {
          for {
            service <- ZIO.service[AuthService]
            updated <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("en")))
          } yield assertTrue(updated.preferredLanguage.contains("en"))
        }.provide(layers),
        test("valid preferredLanguage 'uk' is saved and returned") {
          for {
            service <- ZIO.service[AuthService]
            updated <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("uk")))
          } yield assertTrue(updated.preferredLanguage.contains("uk"))
        }.provide(layers),
        // Negative/mutation-critical: unsupported code must NOT be persisted —
        // any mutation that removes the supportedLanguageCodes filter would make this fail.
        test("unsupported language code 'fr' is silently ignored — previous value kept") {
          for {
            service  <- ZIO.service[AuthService]
            // Set a known-good language first so we have a baseline to check against.
            _        <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("de")))
            updated  <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("fr")))
          } yield assertTrue(
            // 'fr' must not overwrite 'de'; the unsupported code is silently dropped.
            !updated.preferredLanguage.contains("fr") &&
              updated.preferredLanguage.contains("de")
          )
        }.provide(layers),
        test("unsupported language code 'xx' is silently ignored when no prior value") {
          for {
            service <- ZIO.service[AuthService]
            // testUserId1 has no preferredLanguage in seed data → after an invalid update, it stays None.
            updated <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("xx")))
          } yield assertTrue(updated.preferredLanguage.isEmpty)
        }.provide(layers),
        test("empty string language code is silently ignored — remains None") {
          for {
            service <- ZIO.service[AuthService]
            updated <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("")))
          } yield assertTrue(updated.preferredLanguage.isEmpty)
        }.provide(layers),
        test("omitting preferredLanguage in update preserves the current value") {
          for {
            service  <- ZIO.service[AuthService]
            _        <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("uk")))
            // Second update omits preferredLanguage entirely — current value must be preserved.
            updated  <- service.updateUser(testUserId1, UpdateUserRequest(name = Some("No Lang Change")))
          } yield assertTrue(
            updated.name == "No Lang Change" &&
              updated.preferredLanguage.contains("uk")
          )
        }.provide(layers),
        // NOTE: tenant isolation for PUT /api/users/{id} lives at the ROUTE level
        // (requireSameCompany in UserApi.scala), not inside AuthService.updateUser.
        // The service itself works by user ID without a company filter — which is correct
        // because the route guard has already verified company membership before calling it.
        //
        // The cross-company negative test is therefore a BDD scenario against the real HTTP
        // layer: see api/src/test/resources/features/40_user_language_selection.feature
        // ("Tenant isolation — user from company A cannot update user from company B via id endpoint").
        //
        // What we verify here at the service unit level: that updateUser with a
        // preferredLanguage payload can update the specified user's record and returns
        // the updated person (happy-path service contract, no isolation illusion).
        test("updateUser with preferredLanguage succeeds and returns updated person") {
          for {
            service <- ZIO.service[AuthService]
            _       <- service.updateUser(testUserId1, UpdateUserRequest(preferredLanguage = Some("de")))
            // A second call with a different field must not lose the already-stored language.
            updated <- service.updateUser(testUserId1, UpdateUserRequest(name = Some("Lang Verified")))
          } yield assertTrue(
            updated.name == "Lang Verified" &&
              updated.preferredLanguage.contains("de")
          )
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
            result  <-
              service
                .updateUser(
                  UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                  UpdateUserRequest(name = Some("Test"))
                )
                .exit
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
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("email", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("invalid role in update returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <- service.updateUser(testUserId1, UpdateUserRequest(role = Some("INVALID"))).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("role", _) => true
                case _                          => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("invalid status in update returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <- service.updateUser(testUserId1, UpdateUserRequest(status = Some("INVALID"))).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("status", _) => true
                case _                            => false
              }
            case _                   => false
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
        }.provide(layers),
        // ── multi-role (dispatcher-can-drive) ──────────────────────────────
        test("updateUser adding DRIVER role to dispatcher propagates roles") {
          for {
            service <- ZIO.service[AuthService]
            // testUserId10 is a Driver; create a fresh dispatcher to update
            created <- service.createUser(
                         CreateUserRequest(
                           email = "tobedriver@example.com",
                           name = "Dispatcher To Drive",
                           role = "DISPATCHER",
                           password = "Secure123"
                         )
                       )
            updated <- service.updateUser(
                         created.id,
                         UpdateUserRequest(
                           role = Some("DISPATCHER"),
                           roles = Some(List("DISPATCHER", "DRIVER"))
                         )
                       )
          } yield assertTrue(
            updated.role == "DISPATCHER",
            updated.roles.contains("DISPATCHER"),
            updated.roles.contains("DRIVER")
          )
        }.provide(layers),
        test("updateUser with primary role not in new roles returns ValidationError") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .updateUser(
                  testUserId10,
                  UpdateUserRequest(
                    role = Some("DRIVER"),
                    roles = Some(List("DISPATCHER")) // primary DRIVER missing
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ValidationError("roles", _) => true
                case _                           => false
              }
            case _                   => false
          })
        }.provide(layers)
      ),
      suite("deleteUser")(
        test("deletes existing user in the same company") {
          val companyId = CompanyId(UUID.randomUUID())
          val person    = Person(
            id = PersonId.generate(),
            name = "To Delete",
            email = "todelete@example.com",
            role = PersonRole.Client,
            passwordHash = "hash",
            status = UserStatus.ACTIVE,
            companyId = Some(companyId),
            roles = Set(PersonRole.Client)
          )
          for {
            repo    <- ZIO.service[PersonRepository]
            _       <- repo.create(person)
            service <- ZIO.service[AuthService]
            _       <- service.deleteUser(person.id.value, companyId)
            result  <- service.getUserById(person.id.value).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
            case _                   => false
          })
        }.provide(layersWithRepo),
        // Regression for the tenant-isolation gap: a hard delete must not touch a user that
        // belongs to a different company, even when the id is known. The row must survive and
        // the call must fail with UserNotFound (the target is invisible to the other tenant).
        test("does not delete a user from another company") {
          val ownerCompany    = CompanyId(UUID.randomUUID())
          val attackerCompany = CompanyId(UUID.randomUUID())
          val person          = Person(
            id = PersonId.generate(),
            name = "Other Tenant",
            email = "victim@other.example.com",
            role = PersonRole.Client,
            passwordHash = "hash",
            status = UserStatus.ACTIVE,
            companyId = Some(ownerCompany),
            roles = Set(PersonRole.Client)
          )
          for {
            repo      <- ZIO.service[PersonRepository]
            _         <- repo.create(person)
            service   <- ZIO.service[AuthService]
            result    <- service.deleteUser(person.id.value, attackerCompany).exit
            stillHere <- repo.findById(person.id)
          } yield assertTrue(
            result.isFailure,
            stillHere.isDefined
          )
        }.provide(layersWithRepo),
        test("returns error for unknown user") {
          for {
            service <- ZIO.service[AuthService]
            result  <-
              service
                .deleteUser(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"), CompanyId(UUID.randomUUID()))
                .exit
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
            user    <- service.createUser(
                         CreateUserRequest(
                           email = "changepw@example.com",
                           name = "Change PW",
                           role = "CLIENT",
                           password = "OldPassword1"
                         )
                       )
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
            service <- ZIO.service[AuthService]
            login   <- service.login("test@example.com", "Password123")
            userDto <- service.validateToken(login.token)
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
