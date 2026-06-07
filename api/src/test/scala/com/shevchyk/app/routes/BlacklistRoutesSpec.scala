package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, InMemoryAuditService}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{BlacklistRepository, InMemoryBlacklistRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.util.UUID

object BlacklistRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val dispatcherId  = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val secretaryId   = UUID.fromString("00000000-0000-0000-0000-000000000002")
  private val driverId      = UUID.fromString("00000000-0000-0000-0000-000000000003")
  private val clientUserId  = UUID.fromString("00000000-0000-0000-0000-000000000004")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
        issuer = "test-issuer",
        audience = "test-audience",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def generateToken(
      userId: UUID,
      role: PersonRole = PersonRole.Dispatcher,
      companyId: Option[UUID] = Some(taxiCompanyId)
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(userId),
        email = s"$userId@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = companyId.map(CompanyId.apply),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(req: Request): ZIO[BlacklistRepository & AuditService & JwtService, Nothing, Response] =
    BlacklistRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val layers =
    ZLayer.succeed(new InMemoryBlacklistRepository) ++
      AuditService.inMemory ++
      testJwtLayer

  def spec =
    suite("BlacklistRoutes")(
      suite("GET /api/blacklist")(
        test("dispatcher lists entries for own company") {
          for {
            repo    <- ZIO.service[BlacklistRepository]
            entry    = BlacklistEntry(
                         id = BlacklistEntryId.generate(),
                         companyId = CompanyId(taxiCompanyId),
                         clientId = PersonId(clientUserId),
                         driverId = PersonId(driverId),
                         createdBy = PersonId(dispatcherId)
                       )
            _       <- repo.create(entry)
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/blacklist").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            list    <- ZIO.fromEither(bodyStr.fromJson[List[BlacklistEntry]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, list.length == 1)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/blacklist").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 403 for client role") {
          for {
            token <- generateToken(clientUserId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/blacklist").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("POST /api/blacklist")(
        test("dispatcher creates blacklist entry") {
          for {
            token   <- generateToken(dispatcherId)
            body     = s"""{"clientId":"$clientUserId","driverId":"$driverId","reason":"Bad behavior"}"""
            request  = Request
                         .post(URL.decode("/api/blacklist").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            entry   <- ZIO.fromEither(bodyStr.fromJson[BlacklistEntry]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Created,
            entry.clientId == PersonId(clientUserId),
            entry.driverId == PersonId(driverId)
          )
        },
        test("returns 403 for secretary role") {
          for {
            token  <- generateToken(secretaryId, role = PersonRole.Secretary)
            body    = s"""{"clientId":"$clientUserId","driverId":"$driverId"}"""
            request = Request
                        .post(URL.decode("/api/blacklist").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("returns 401 without token") {
          for {
            body <- ZIO.succeed(s"""{"clientId":"$clientUserId","driverId":"$driverId"}""")
            resp <- runRequest(
                      Request.post(URL.decode("/api/blacklist").toOption.get, Body.fromString(body))
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("GET /api/blacklist/check")(
        test("returns blacklisted true for existing pair") {
          for {
            repo    <- ZIO.service[BlacklistRepository]
            _       <- repo.create(
                         BlacklistEntry(
                           id = BlacklistEntryId.generate(),
                           companyId = CompanyId(taxiCompanyId),
                           clientId = PersonId(clientUserId),
                           driverId = PersonId(driverId),
                           createdBy = PersonId(dispatcherId)
                         )
                       )
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode(s"/api/blacklist/check?clientId=$clientUserId&driverId=$driverId").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Ok, bodyStr.contains("true"))
        },
        test("returns blacklisted false for unknown pair") {
          for {
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(
                             URL
                               .decode(s"/api/blacklist/check?clientId=${UUID.randomUUID()}&driverId=${UUID.randomUUID()}")
                               .toOption
                               .get
                           )
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Ok, bodyStr.contains("false"))
        },
        test("secretary can check blacklist") {
          for {
            token <- generateToken(secretaryId, role = PersonRole.Secretary)
            resp  <- runRequest(
                       Request
                         .get(
                           URL.decode(s"/api/blacklist/check?clientId=$clientUserId&driverId=$driverId").toOption.get
                         )
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns 403 for client role") {
          for {
            token <- generateToken(clientUserId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(
                           URL.decode(s"/api/blacklist/check?clientId=$clientUserId&driverId=$driverId").toOption.get
                         )
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("DELETE /api/blacklist/:id")(
        test("dispatcher deactivates entry successfully") {
          for {
            repo  <- ZIO.service[BlacklistRepository]
            entry  = BlacklistEntry(
                       id = BlacklistEntryId.generate(),
                       companyId = CompanyId(taxiCompanyId),
                       clientId = PersonId(clientUserId),
                       driverId = PersonId(driverId),
                       createdBy = PersonId(dispatcherId)
                     )
            _     <- repo.create(entry)
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .delete(URL.decode(s"/api/blacklist/${entry.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NoContent)
        },
        test("returns 404 for unknown entry") {
          for {
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .delete(URL.decode(s"/api/blacklist/${UUID.randomUUID()}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("returns 403 for secretary role") {
          for {
            token <- generateToken(secretaryId, role = PersonRole.Secretary)
            resp  <- runRequest(
                       Request
                         .delete(URL.decode(s"/api/blacklist/${UUID.randomUUID()}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
