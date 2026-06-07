package com.shevchyk.auth.infrastructure.http

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.repository.TestLayers
import com.shevchyk.auth.service.JwtService
import com.shevchyk.auth.config.JwtConfig
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object AuthRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test",
      audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )

  private val noopRateLimiter: ZLayer[Any, Nothing, RateLimiter] = ZLayer.fromZIO(
    RateLimiter.make(maxRequests = 1000, windowSeconds = 60)
  )

  private val jwtServiceLayer: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val baseLayers =
    TestLayers.inMemoryPersonRepository ++
      TestLayers.inMemoryTokenRepository ++
      jwtServiceLayer >>>
      AuthService.live

  private val fullLayers = baseLayers ++ noopRateLimiter ++ jwtServiceLayer

  private def run(request: Request): ZIO[AuthService & RateLimiter & JwtService, Nothing, Response] = AuthRoutes.routes
    .run(request)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // InMemoryPersonRepositoryWithUsers already has test@example.com with password "Password123"
  private val validLoginJson   = """{"email":"test@example.com","password":"Password123"}"""
  private val invalidLoginJson = """{"email":"nobody@example.com","password":"wrong"}"""

  def spec =
    suite("AuthRoutes")(
      suite("POST /api/auth/login")(
        test("returns 401 for unknown user") {
          val request = Request.post(
            URL.decode("/api/auth/login").toOption.get,
            Body.fromString(invalidLoginJson)
          )
          run(request).map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(fullLayers),
        test("returns 500 or 400 for invalid JSON") {
          val request = Request.post(
            URL.decode("/api/auth/login").toOption.get,
            Body.fromString("not-json")
          )
          run(request).map(r => assertTrue(r.status == Status.BadRequest || r.status == Status.InternalServerError))
        }.provide(fullLayers),
        test("returns 200 with token for valid credentials (user pre-seeded)") {
          val request = Request.post(
            URL.decode("/api/auth/login").toOption.get,
            Body.fromString(validLoginJson)
          )
          for {
            response <- run(request)
            body     <- response.body.asString
          } yield assertTrue(response.status == Status.Ok, body.contains("token"))
        }.provide(fullLayers),
        test("returns 429 when rate limit exceeded") {
          val request = Request.post(
            URL.decode("/api/auth/login").toOption.get,
            Body.fromString(validLoginJson)
          )
          run(request).map(r => assertTrue(r.status == Status.TooManyRequests))
        }.provide(
          TestLayers.inMemoryPersonRepository ++
            TestLayers.inMemoryTokenRepository ++
            jwtServiceLayer >>>
            AuthService.live,
          jwtServiceLayer,
          ZLayer.fromZIO(RateLimiter.make(maxRequests = 0, windowSeconds = 60))
        )
      )
    )
}
