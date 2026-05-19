package com.shevchyk.app.routes

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.{FcmToken, FcmTokenId}
import com.shevchyk.notification.repository.FcmTokenRepository
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{RideRepository, InMemoryRideRepository}
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object UserRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test",
      audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val dispatcherId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val clientId     = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val companyId    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private val inMemoryTokenRepo: ZLayer[Any, Nothing, TokenRepository] = ZLayer.succeed {
    new TokenRepository {
      private val store = new ConcurrentHashMap[String, UUID]()
      def create(token: String, userId: UUID): Task[Unit]             = ZIO.succeed { store.put(token, userId); () }
      def findUserIdByToken(token: String): Task[Option[UUID]]        = ZIO.succeed(Option(store.get(token)))
      def deleteByToken(token: String): Task[Unit]                    = ZIO.succeed { store.remove(token); () }
      def deleteByUserId(userId: UUID): Task[Unit]                    = ZIO.succeed {
        store.entrySet().asScala.filter(_.getValue == userId).foreach(e => store.remove(e.getKey))
      }
    }
  }

  private val inMemoryPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed {
    new PersonRepository {
      private val store = new ConcurrentHashMap[PersonId, Person]()
      def create(p: Person): Task[Person]                                                    = ZIO.succeed { store.put(p.id, p); p }
      def findById(id: PersonId): Task[Option[Person]]                                      = ZIO.succeed(Option(store.get(id)))
      def findByEmail(email: String): Task[Option[Person]]                                  = ZIO.succeed(store.values().asScala.find(_.email == email))
      def findByRole(role: PersonRole): Task[List[Person]]                                  = ZIO.succeed(store.values().asScala.filter(_.role == role).toList)
      def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]]        = ZIO.succeed(store.values().asScala.filter(p => p.role == role && p.companyId.contains(cid)).toList)
      def findByCompanyId(cid: CompanyId): Task[List[Person]]                               = ZIO.succeed(store.values().asScala.filter(_.companyId.contains(cid)).toList)
      def findAll(): Task[List[Person]]                                                      = ZIO.succeed(store.values().asScala.toList)
      def update(p: Person): Task[Person]                                                   = ZIO.succeed { store.put(p.id, p); p }
      def delete(id: PersonId): Task[Unit]                                                  = ZIO.succeed { store.remove(id); () }
      def findByStatus(status: UserStatus): Task[List[Person]]                              = ZIO.succeed(store.values().asScala.filter(_.status == status).toList)
      def searchByQuery(query: String): Task[List[Person]]                                  = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                         = ZIO.unit
      def findByClientCompany(ccId: ClientCompanyId): Task[List[Person]]                   = ZIO.succeed(Nil)
    }
  }

  private val noopFcmService: ZLayer[Any, Nothing, FcmService] = ZLayer.succeed {
    new FcmService {
      def sendNotification(token: String, title: String, body: String, data: Map[String, String]): Task[Unit] = ZIO.unit
      def registerToken(userId: PersonId, token: String, platform: String): Task[Unit]                        = ZIO.unit
      def unregisterToken(token: String): Task[Unit]                                                          = ZIO.unit
      def getTokensForUser(userId: PersonId): Task[List[String]]                                              = ZIO.succeed(Nil)
    }
  }

  private val noopRideService: ZLayer[Any, Nothing, RideService] = ZLayer.succeed {
    new RideService(
      rideRepository = new com.shevchyk.ride.repository.InMemoryRideRepository {},
      personRepository = new PersonRepository {
        def create(p: Person): Task[Person]                                             = ZIO.succeed(p)
        def findById(id: PersonId): Task[Option[Person]]                               = ZIO.succeed(None)
        def findByEmail(email: String): Task[Option[Person]]                           = ZIO.succeed(None)
        def findByRole(role: PersonRole): Task[List[Person]]                           = ZIO.succeed(Nil)
        def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
        def findByCompanyId(cid: CompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
        def findAll(): Task[List[Person]]                                               = ZIO.succeed(Nil)
        def update(p: Person): Task[Person]                                            = ZIO.succeed(p)
        def delete(id: PersonId): Task[Unit]                                           = ZIO.unit
        def findByStatus(s: UserStatus): Task[List[Person]]                            = ZIO.succeed(Nil)
        def searchByQuery(q: String): Task[List[Person]]                               = ZIO.succeed(Nil)
        def updateLastLogin(id: PersonId): Task[Unit]                                  = ZIO.unit
        def findByClientCompany(cid: ClientCompanyId): Task[List[Person]]             = ZIO.succeed(Nil)
      },
      eventHub = null,
      auditService = null,
      emailSmsService = null,
      chatMessageRepository = null,
      clientLocationRepository = null,
      rideRatingRepository = null
    )
  }

  private val noopRateLimiter: ZLayer[Any, Nothing, RateLimiter] = ZLayer.fromZIO(
    RateLimiter.make(maxRequests = 1000, windowSeconds = 60)
  )

  private val authServiceLayer: ZLayer[Any, Nothing, AuthService] =
    (inMemoryPersonRepo ++ inMemoryTokenRepo ++ testJwtService) >>> AuthService.live

  private val testLayers =
    authServiceLayer ++
    inMemoryPersonRepo ++
    testJwtService ++
    noopFcmService ++
    noopRateLimiter

  private def run(req: Request): ZIO[AuthService & PersonRepository & JwtService & FcmService & RideService & RateLimiter, Nothing, Response] =
    UserRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def token(role: PersonRole, uid: UUID = dispatcherId, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(
      Person(PersonId(uid), "test@example.com", "Test", role, "hash", cid.map(CompanyId.apply), UserStatus.ACTIVE)
    ))

  private val fullLayers = testLayers ++ noopRideService

  def spec = suite("UserRoutes")(

    suite("GET /api/users/clients")(
      test("dispatcher gets client list (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/users/clients").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("secretary gets client list (200)") {
        for {
          tok      <- token(PersonRole.Secretary)
          response <- run(Request.get(URL.decode("/api/users/clients").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/users/clients").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers),

      test("no token returns 401") {
        run(Request.get(URL.decode("/api/users/clients").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers)
    ),

    suite("GET /api/users/drivers")(
      test("dispatcher gets driver list (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/users/drivers").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/users/drivers").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("GET /api/users")(
      test("dispatcher gets all users (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/users").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/users").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("GET /api/users/:id")(
      test("dispatcher can get any user (200 or 404)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode(s"/api/users/$clientId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok || response.status == Status.NotFound)
      }.provide(fullLayers),

      test("returns 400 for invalid UUID") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/users/not-a-uuid").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.BadRequest)
      }.provide(fullLayers),

      test("client cannot get another user (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode(s"/api/users/$dispatcherId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("GET /api/users/stats")(
      test("dispatcher gets stats (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/users/stats").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/users/stats").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("POST /api/users")(
      test("dispatcher can create user (201)") {
        val body = """{"email":"new@example.com","password":"ValidPass1!","name":"New","role":"CLIENT"}"""
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.post(URL.decode("/api/users").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Created)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        val body = """{"email":"x@x.com","password":"ValidPass1!","name":"X","role":"CLIENT"}"""
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.post(URL.decode("/api/users").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers),

      test("returns 401 without token") {
        val body = """{"email":"x@x.com","password":"ValidPass1!","name":"X","role":"CLIENT"}"""
        run(Request.post(URL.decode("/api/users").toOption.get, Body.fromString(body)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers)
    ),

    suite("DELETE /api/users/:id")(
      test("dispatcher can deactivate user (204)") {
        for {
          authSvc  <- ZIO.service[AuthService]
          created  <- authSvc.createUser(CreateUserRequest("del@example.com", "ValidPass1!", "Del", "CLIENT"))
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.delete(URL.decode(s"/api/users/${created.id}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.delete(URL.decode(s"/api/users/$dispatcherId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("PUT /api/users/change-password")(
      test("returns 401 without token") {
        val body = """{"currentPassword":"old","newPassword":"NewPass1!"}"""
        run(Request.put(URL.decode("/api/users/change-password").toOption.get, Body.fromString(body)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers)
    ),

    suite("POST /api/users/fcm-token")(
      test("returns 201 for authenticated user") {
        val body = """{"token":"fcm-token-123","platform":"android"}"""
        for {
          tok      <- token(PersonRole.Driver)
          response <- run(Request.post(URL.decode("/api/users/fcm-token").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Created)
      }.provide(fullLayers),

      test("returns 401 without token") {
        val body = """{"token":"fcm-token-123","platform":"android"}"""
        run(Request.post(URL.decode("/api/users/fcm-token").toOption.get, Body.fromString(body)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers)
    ),

    suite("DELETE /api/users/fcm-token/:token")(
      test("returns 204 for authenticated user") {
        for {
          tok      <- token(PersonRole.Driver)
          response <- run(Request.delete(URL.decode("/api/users/fcm-token/some-token-abc").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(fullLayers),

      test("returns 401 without token") {
        run(Request.delete(URL.decode("/api/users/fcm-token/some-token").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers)
    ),

    suite("GET /api/stats/rides")(
      test("dispatcher gets ride stats (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/stats/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/stats/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("GET /api/stats/rides/daily")(
      test("dispatcher gets daily stats (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/stats/rides/daily?days=7").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/stats/rides/daily").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    ),

    suite("GET /api/stats/drivers")(
      test("dispatcher gets driver stats (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher)
          response <- run(Request.get(URL.decode("/api/stats/drivers").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(fullLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/stats/drivers").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(fullLayers)
    )
  )
}
