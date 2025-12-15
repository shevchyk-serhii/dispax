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

object TestApplication extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  // Simple mock implementations for testing
  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    val hash = digest.digest(password.getBytes("UTF-8"))
    Base64.getEncoder.encodeToString(hash)

  private val mockPersonRepository: PersonRepository = new PersonRepository {
    def create(person: Person): Task[Person] = ZIO.succeed(person)
    def findById(id: PersonId): Task[Option[Person]] = ZIO.some(
      Person(id, "Mock User", "mock@example.com", PersonRole.Client)
    )
    def findByEmail(email: String): Task[Option[Person]] = ZIO.some(
      Person(PersonId(1), "Mock User", email, PersonRole.Client)
    )
    def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(
      List(Person(PersonId(1), "Mock User", "mock@example.com", role))
    )
    def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      List(Person(PersonId(1), "Mock User", "mock@example.com", PersonRole.Client, Some(companyId)))
    )
    def findAll(): Task[List[Person]] = ZIO.succeed(
      List(Person(PersonId(1), "Mock User", "mock@example.com", PersonRole.Client))
    )
    def update(person: Person): Task[Person] = ZIO.succeed(person)
    def delete(id: PersonId): Task[Unit] = ZIO.unit
  }

  private val mockUserRepository: UserRepository = new UserRepository {
    private val users = Map[Long, User](
      1L  -> User(1L, "test@example.com", "Test User", UserRole.CLIENT, hashPassword("password123"), Some("+1234567890"), UserStatus.ACTIVE, Instant.now()),
      50L -> User(50L, "client@example.com", "Client User", UserRole.CLIENT, hashPassword("password123"), Some("+1111111111"), UserStatus.ACTIVE, Instant.now()),
      10L -> User(10L, "driver@example.com", "Driver User", UserRole.DRIVER, hashPassword("password123"), Some("+2222222222"), UserStatus.ACTIVE, Instant.now()),
      99L -> User(99L, "admin@example.com", "Admin User", UserRole.ADMIN, hashPassword("password123"), Some("+3333333333"), UserStatus.ACTIVE, Instant.now())
    )

    def create(user: User): Task[User] = ZIO.succeed(user.copy(id = users.keys.max + 1))
    def findById(id: Long): Task[Option[User]] = ZIO.succeed(users.get(id))
    def findByEmail(email: String): Task[Option[User]] = ZIO.succeed(users.values.find(_.email == email))
    def findAll(): Task[List[User]] = ZIO.succeed(users.values.toList)
    def findByRole(role: UserRole): Task[List[User]] = ZIO.succeed(users.values.filter(_.role == role).toList)
    def findByStatus(status: UserStatus): Task[List[User]] = ZIO.succeed(users.values.filter(_.status == status).toList)
    def update(user: User): Task[User] = ZIO.succeed(user)
    def delete(id: Long): Task[Unit] = ZIO.unit
    def searchByQuery(query: String): Task[List[User]] = ZIO.succeed(
      users.values.filter(u => u.name.toLowerCase.contains(query.toLowerCase) || u.email.toLowerCase.contains(query.toLowerCase)).toList
    )
  }

  private val mockTokenRepository: TokenRepository = new TokenRepository {
    private val tokens = Map[String, Long](
      "valid-token-1"  -> 1L,
      "valid-token-50" -> 50L,
      "valid-token-10" -> 10L,
      "valid-token-99" -> 99L
    )

    def create(token: String, userId: Long): Task[Unit] = ZIO.unit
    def findUserIdByToken(token: String): Task[Option[Long]] = ZIO.succeed(tokens.get(token))
    def deleteByToken(token: String): Task[Unit] = ZIO.unit
    def deleteByUserId(userId: Long): Task[Unit] = ZIO.unit
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