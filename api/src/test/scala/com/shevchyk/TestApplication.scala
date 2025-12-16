package com.shevchyk

import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.app.routes.UserRoutes
import com.shevchyk.repository.PersonRepository
import com.shevchyk.auth.repository.{UserRepository, TokenRepository}
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.infrastructure.http.AuthRoutes
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J
import java.time.Instant
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID

object TestApplication extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  // Simple mock implementations for testing
  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    val hash = digest.digest(password.getBytes("UTF-8"))
    Base64.getEncoder.encodeToString(hash)

  // Predefined test UUIDs for consistent testing
  private val testPersonId1 = PersonId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
  private val testCompanyId1 = CompanyId(UUID.fromString("10101010-1010-1010-1010-101010101010"))

  private val mockPersonRepository: PersonRepository = new PersonRepository {
    def create(person: Person): Task[Person] = ZIO.succeed(person)
    def findById(id: PersonId): Task[Option[Person]] = ZIO.some(
      Person(id, "Mock User", "mock@example.com", PersonRole.Client)
    )
    def findByEmail(email: String): Task[Option[Person]] = ZIO.some(
      Person(testPersonId1, "Mock User", email, PersonRole.Client)
    )
    def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(
      List(Person(testPersonId1, "Mock User", "mock@example.com", role))
    )
    def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      List(Person(testPersonId1, "Mock User", "mock@example.com", PersonRole.Client, Some(companyId)))
    )
    def findAll(): Task[List[Person]] = ZIO.succeed(
      List(Person(testPersonId1, "Mock User", "mock@example.com", PersonRole.Client))
    )
    def update(person: Person): Task[Person] = ZIO.succeed(person)
    def delete(id: PersonId): Task[Unit] = ZIO.unit
  }

  // Predefined test UUIDs for consistent testing
  private val testUserId1 = UUID.fromString("11111111-1111-1111-1111-111111111111")
  private val testUserId50 = UUID.fromString("50505050-5050-5050-5050-505050505050")
  private val testUserId10 = UUID.fromString("10101010-1010-1010-1010-101010101010")
  private val testUserId99 = UUID.fromString("99999999-9999-9999-9999-999999999999")

  private val mockUserRepository: UserRepository = new UserRepository {
    private val users = Map[UUID, User](
      testUserId1  -> User(testUserId1, "test@example.com", "Test User", UserRole.CLIENT, hashPassword("password123"), Some("+1234567890"), UserStatus.ACTIVE, Instant.now()),
      testUserId50 -> User(testUserId50, "client@example.com", "Client User", UserRole.CLIENT, hashPassword("password123"), Some("+1111111111"), UserStatus.ACTIVE, Instant.now()),
      testUserId10 -> User(testUserId10, "driver@example.com", "Driver User", UserRole.DRIVER, hashPassword("password123"), Some("+2222222222"), UserStatus.ACTIVE, Instant.now()),
      testUserId99 -> User(testUserId99, "admin@example.com", "Admin User", UserRole.ADMIN, hashPassword("password123"), Some("+3333333333"), UserStatus.ACTIVE, Instant.now())
    )

    def create(user: User): Task[User] = ZIO.succeed(user.copy(id = UUID.randomUUID()))
    def findById(id: UUID): Task[Option[User]] = ZIO.succeed(users.get(id))
    def findByEmail(email: String): Task[Option[User]] = ZIO.succeed(users.values.find(_.email == email))
    def findAll(): Task[List[User]] = ZIO.succeed(users.values.toList)
    def findByRole(role: UserRole): Task[List[User]] = ZIO.succeed(users.values.filter(_.role == role).toList)
    def findByStatus(status: UserStatus): Task[List[User]] = ZIO.succeed(users.values.filter(_.status == status).toList)
    def update(user: User): Task[User] = ZIO.succeed(user)
    def delete(id: UUID): Task[Unit] = ZIO.unit
    def searchByQuery(query: String): Task[List[User]] = ZIO.succeed(
      users.values.filter(u => u.name.toLowerCase.contains(query.toLowerCase) || u.email.toLowerCase.contains(query.toLowerCase)).toList
    )
  }

  private val mockTokenRepository: TokenRepository = new TokenRepository {
    private val tokens = Map[String, UUID](
      "valid-token-1"  -> testUserId1,
      "valid-token-50" -> testUserId50,
      "valid-token-10" -> testUserId10,
      "valid-token-99" -> testUserId99
    )

    def create(token: String, userId: UUID): Task[Unit] = ZIO.unit
    def findUserIdByToken(token: String): Task[Option[UUID]] = ZIO.succeed(tokens.get(token))
    def deleteByToken(token: String): Task[Unit] = ZIO.unit
    def deleteByUserId(userId: UUID): Task[Unit] = ZIO.unit
  }

  private val allRoutes =
    Routes(
      Method.GET / "health" -> handler(Response.text("Der Oktopus Modular API - OK"))
    ) ++
      AuthRoutes.routes ++
      UserRoutes.routes ++
      RideRoutes.routes

  def run: ZIO[ZIOAppArgs, Any, Any] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server (Test - In-Memory)...") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🔍 /health - Health check") *>
      ZIO.logInfo("  🔐 /api/auth/login - Simple login endpoint") *>
      ZIO.logInfo("  👥 /api/users - User management endpoints") *>
      ZIO.logInfo("  🚗 /api/rides - Rich ride data (Mock)") *>
      ZIO.logInfo("🏗️  Modules: auth + ride + in-memory repositories (TESTING)") *>
      ZIO.logInfo("🌐 Server running on http://localhost:8080") *>
      Server.serve(
        allRoutes.handleError(err => Response(Status.InternalServerError, body = Body.fromString(err.toString)))
      ))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080)),
        ZLayer.succeed[PersonRepository](mockPersonRepository),
        ZLayer.succeed[UserRepository](mockUserRepository),
        ZLayer.succeed[TokenRepository](mockTokenRepository),
        JwtConfig.development,
        JwtService.live,
        AuthService.live,
      )