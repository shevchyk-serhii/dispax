package com.shevchyk

import com.shevchyk.ride.infrastructure.http.MockRideRoutes
import com.shevchyk.app.routes.UserRoutes
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.infrastructure.http.AuthRoutes
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.config.ServerConfig
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J
import java.time.Instant
import java.util.UUID
import org.mindrot.jbcrypt.BCrypt

object TestApplication extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private def hashPassword(password: String): String =
    BCrypt.hashpw(password, BCrypt.gensalt(12))

  private val testPersonId1 = PersonId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
  private val testPersonId50 = PersonId(UUID.fromString("50505050-5050-5050-5050-505050505050"))
  private val testPersonId10 = PersonId(UUID.fromString("10101010-1010-1010-1010-101010101010"))
  private val testPersonId99 = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
  private val testCompanyId1 = CompanyId(UUID.fromString("10101010-1010-1010-1010-101010101010"))

  private val mockPersonRepository: PersonRepository = new PersonRepository {
    private val people = Map[PersonId, Person](
      testPersonId1  -> Person(testPersonId1, "Test User", "test@example.com", PersonRole.Client, passwordHash = hashPassword("Password123"), phone = Some("+1234567890")),
      testPersonId50 -> Person(testPersonId50, "Client User", "client@example.com", PersonRole.Client, passwordHash = hashPassword("Password123"), phone = Some("+1111111111")),
      testPersonId10 -> Person(testPersonId10, "Driver User", "driver@example.com", PersonRole.Driver, passwordHash = hashPassword("Password123"), phone = Some("+2222222222")),
      testPersonId99 -> Person(testPersonId99, "Admin User", "admin@example.com", PersonRole.Admin, passwordHash = hashPassword("Password123"), phone = Some("+3333333333"))
    )

    def create(person: Person): Task[Person] = ZIO.succeed(person)
    def findById(id: PersonId): Task[Option[Person]] = ZIO.succeed(people.get(id))
    def findByEmail(email: String): Task[Option[Person]] = ZIO.succeed(people.values.find(_.email == email))
    def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(people.values.filter(_.role == role).toList)
    def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      people.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList
    )
    def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      people.values.filter(_.companyId.contains(companyId)).toList
    )
    def findAll(): Task[List[Person]] = ZIO.succeed(people.values.toList)
    def update(person: Person): Task[Person] = ZIO.succeed(person)
    def delete(id: PersonId): Task[Unit] = ZIO.unit
    def findByStatus(status: UserStatus): Task[List[Person]] = ZIO.succeed(people.values.filter(_.status == status).toList)
    def searchByQuery(query: String): Task[List[Person]] = ZIO.succeed(
      people.values.filter(p => p.name.toLowerCase.contains(query.toLowerCase) || p.email.toLowerCase.contains(query.toLowerCase)).toList
    )
    def updateLastLogin(id: PersonId): Task[Unit] = ZIO.unit
  }

  private val mockTokenRepository: TokenRepository = new TokenRepository {
    private val tokens = Map[String, UUID](
      "valid-token-1"  -> testPersonId1.value,
      "valid-token-50" -> testPersonId50.value,
      "valid-token-10" -> testPersonId10.value,
      "valid-token-99" -> testPersonId99.value
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
      MockRideRoutes.routes

  def run: ZIO[ZIOAppArgs, Any, Any] =
    ZIO.serviceWithZIO[ServerConfig] { serverConfig =>
      ZIO.logInfo("Starting Der Oktopus API Server (Test - In-Memory)...") *>
      Server.serve(
        allRoutes.handleError(err => Response(Status.InternalServerError, body = Body.fromString(err.toString)))
      )
    }.provide(
        ZLayer.service[ServerConfig] >>> ZLayer.fromFunction((config: ServerConfig) =>
          Server.Config.default.binding(config.host, config.port)
        ) >>> Server.live,
        ServerConfig.defaultLayer,
        ZLayer.succeed[PersonRepository](mockPersonRepository),
        ZLayer.succeed[TokenRepository](mockTokenRepository),
        JwtConfig.live,
        JwtService.live,
        AuthService.live,
        RateLimiter.layer,
      )
