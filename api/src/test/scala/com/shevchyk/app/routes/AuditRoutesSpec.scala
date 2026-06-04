package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, InMemoryAuditService}
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.util.UUID

object AuditRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val dispatcherId  = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val clientId      = UUID.fromString("00000000-0000-0000-0000-000000000002")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )) >>> JwtService.live

  private def generateToken(
      userId: UUID,
      role: PersonRole = PersonRole.Dispatcher,
      companyId: Option[UUID] = Some(taxiCompanyId)
  ): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(Person(
      id = PersonId(userId),
      email = s"$userId@test.com",
      name = "Test User",
      role = role,
      passwordHash = "hash",
      companyId = companyId.map(CompanyId.apply),
      status = UserStatus.ACTIVE
    )))

  private def runRequest(req: Request): ZIO[AuditService & JwtService, Nothing, Response] =
    AuditRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makeEntry(companyId: UUID = taxiCompanyId, entityType: String = "ride"): AuditLogEntry =
    AuditLogEntry(
      id = AuditLogId.generate(),
      companyId = CompanyId(companyId),
      actorId = PersonId(dispatcherId),
      action = AuditAction.RideCreated,
      entityType = entityType,
      entityId = UUID.randomUUID()
    )

  private val layers = AuditService.inMemory ++ testJwtLayer

  def spec = suite("AuditRoutes")(

    suite("GET /api/audit")(
      test("dispatcher gets entries by entity") {
        for {
          service <- ZIO.service[AuditService]
          entry    = makeEntry(entityType = "ride")
          _       <- service.log(entry)
          token   <- generateToken(dispatcherId)
          request  = Request.get(
                       URL.decode(s"/api/audit?entityType=ride&entityId=${entry.entityId}").toOption.get
                     ).addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[AuditLogEntry]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 1, list.head.entityType == "ride")
      },

      test("returns 401 without token") {
        for {
          resp <- runRequest(Request.get(URL.decode("/api/audit?entityType=ride&entityId=" + UUID.randomUUID()).toOption.get))
        } yield assertTrue(resp.status == Status.Unauthorized)
      },

      test("returns 403 for client role") {
        for {
          token <- generateToken(clientId, role = PersonRole.Client)
          resp  <- runRequest(
                     Request.get(URL.decode(s"/api/audit?entityType=ride&entityId=${UUID.randomUUID()}").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status == Status.Forbidden)
      },

      test("returns error when entityType param is missing") {
        for {
          token <- generateToken(dispatcherId)
          resp  <- runRequest(
                     Request.get(URL.decode(s"/api/audit?entityId=${UUID.randomUUID()}").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status != Status.Ok)
      }
    ),

    suite("GET /api/audit/recent")(
      test("dispatcher gets recent entries for own company") {
        for {
          service <- ZIO.service[AuditService]
          _       <- service.log(makeEntry())
          _       <- service.log(makeEntry())
          token   <- generateToken(dispatcherId)
          request  = Request.get(URL.decode("/api/audit/recent?limit=10").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[AuditLogEntry]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 2)
      },

      test("returns 401 without token") {
        for {
          resp <- runRequest(Request.get(URL.decode("/api/audit/recent").toOption.get))
        } yield assertTrue(resp.status == Status.Unauthorized)
      },

      test("returns 403 for driver role") {
        for {
          token <- generateToken(dispatcherId, role = PersonRole.Driver)
          resp  <- runRequest(
                     Request.get(URL.decode("/api/audit/recent").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status == Status.Forbidden)
      },

      test("respects limit parameter") {
        for {
          service <- ZIO.service[AuditService]
          _       <- ZIO.foreach(1 to 5)(_ => service.log(makeEntry()))
          token   <- generateToken(dispatcherId)
          request  = Request.get(URL.decode("/api/audit/recent?limit=2").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[AuditLogEntry]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length <= 2)
      }
    )

  ).provide(layers) @@ TestAspect.sequential
}
