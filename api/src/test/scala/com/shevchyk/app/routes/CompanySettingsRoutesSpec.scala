package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{CompanySettingsRepository, InMemoryCompanySettingsRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.util.UUID

object CompanySettingsRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val dispatcherId  = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val driverId      = UUID.fromString("00000000-0000-0000-0000-000000000002")
  private val clientUserId  = UUID.fromString("00000000-0000-0000-0000-000000000003")

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

  private def runRequest(req: Request): ZIO[CompanySettingsRepository & JwtService, Nothing, Response] =
    CompanySettingsRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val layers =
    ZLayer.succeed(new InMemoryCompanySettingsRepository) ++
      testJwtLayer

  def spec =
    suite("CompanySettingsRoutes")(
      suite("GET /api/company/settings")(
        test("dispatcher gets settings, returns defaults when none exist") {
          for {
            token    <- generateToken(dispatcherId)
            resp     <- runRequest(
                          Request
                            .get(URL.decode("/api/company/settings").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            bodyStr  <- resp.body.asString.orDie
            settings <- ZIO.fromEither(bodyStr.fromJson[CompanySettings]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            settings.companyId == CompanyId(taxiCompanyId)
          )
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/company/settings").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 403 for driver role") {
          for {
            token <- generateToken(driverId, role = PersonRole.Driver)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/company/settings").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("PUT /api/company/settings")(
        test("dispatcher updates settings") {
          for {
            token    <- generateToken(dispatcherId)
            body      = """{"defaultCurrency":"EUR","autoAssignEnabled":false}"""
            request   = Request
                          .put(URL.decode("/api/company/settings").toOption.get, Body.fromString(body))
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- runRequest(request)
            bodyStr  <- resp.body.asString.orDie
            settings <- ZIO.fromEither(bodyStr.fromJson[CompanySettings]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            settings.defaultCurrency == "EUR",
            settings.autoAssignEnabled == false
          )
        },
        test("returns 403 for client role") {
          for {
            token  <- generateToken(clientUserId, role = PersonRole.Client)
            body    = """{"defaultCurrency":"EUR"}"""
            request = Request
                        .put(URL.decode("/api/company/settings").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/company/tariff")(
        test("dispatcher gets tariff") {
          for {
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/company/tariff").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Ok, bodyStr.contains("commissionRate"))
        },
        test("driver gets tariff") {
          for {
            token <- generateToken(driverId, role = PersonRole.Driver)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/company/tariff").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("client gets tariff") {
          for {
            token <- generateToken(clientUserId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/company/tariff").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/company/tariff").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("PUT /api/company/tariff")(
        test("dispatcher updates tariff fields") {
          for {
            token    <- generateToken(dispatcherId)
            body      = """{"commissionRate":0.15,"defaultCurrency":"GBP"}"""
            request   = Request
                          .put(URL.decode("/api/company/tariff").toOption.get, Body.fromString(body))
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- runRequest(request)
            bodyStr  <- resp.body.asString.orDie
            settings <- ZIO.fromEither(bodyStr.fromJson[CompanySettings]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            settings.defaultCurrency == "GBP"
          )
        },
        test("returns 403 for driver role") {
          for {
            token  <- generateToken(driverId, role = PersonRole.Driver)
            body    = """{"commissionRate":0.5}"""
            request = Request
                        .put(URL.decode("/api/company/tariff").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
