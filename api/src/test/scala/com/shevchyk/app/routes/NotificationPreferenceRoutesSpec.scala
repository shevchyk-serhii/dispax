package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{NotificationPreferenceRepository, InMemoryNotificationPreferenceRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.util.UUID

object NotificationPreferenceRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val userId        = UUID.fromString("00000000-0000-0000-0000-000000000001")

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
      id: UUID = userId,
      role: PersonRole = PersonRole.Client
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(id),
        email = s"$id@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = Some(CompanyId(taxiCompanyId)),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(req: Request): ZIO[NotificationPreferenceRepository & JwtService, Nothing, Response] =
    NotificationPreferenceRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val layers =
    ZLayer.succeed(new InMemoryNotificationPreferenceRepository) ++
      testJwtLayer

  def spec =
    suite("NotificationPreferenceRoutes")(
      suite("GET /api/notification-preferences")(
        test("returns default preferences when none saved") {
          for {
            token   <- generateToken()
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/notification-preferences").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            pref    <- ZIO.fromEither(bodyStr.fromJson[NotificationPreference]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            pref.personId == PersonId(userId),
            pref.rideUpdates == true
          )
        },
        test("returns saved preferences") {
          for {
            repo    <- ZIO.service[NotificationPreferenceRepository]
            saved    = NotificationPreference(
                         id = NotificationPreferenceId.generate(),
                         personId = PersonId(userId),
                         rideUpdates = false,
                         emailNotifications = false
                       )
            _       <- repo.upsert(saved)
            token   <- generateToken()
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/notification-preferences").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            pref    <- ZIO.fromEither(bodyStr.fromJson[NotificationPreference]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            pref.rideUpdates == false,
            pref.emailNotifications == false
          )
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/notification-preferences").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("PUT /api/notification-preferences")(
        test("updates preferences for authenticated user") {
          for {
            token   <- generateToken()
            body     = """{"rideUpdates":false,"smsNotifications":false,"quietHoursStart":"22:00"}"""
            request  = Request
                         .put(URL.decode("/api/notification-preferences").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            pref    <- ZIO.fromEither(bodyStr.fromJson[NotificationPreference]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            pref.rideUpdates == false,
            pref.smsNotifications == false,
            pref.quietHoursStart.contains("22:00")
          )
        },
        test("driver can update preferences") {
          for {
            token  <- generateToken(role = PersonRole.Driver)
            body    = """{"geofenceAlerts":true}"""
            request = Request
                        .put(URL.decode("/api/notification-preferences").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(
                      Request.put(URL.decode("/api/notification-preferences").toOption.get, Body.fromString("{}"))
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
