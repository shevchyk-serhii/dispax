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

  private val baseLayers =
    TestLayers.inMemoryPersonRepository ++
    TestLayers.inMemoryTokenRepository ++
    (testJwtConfig >>> JwtService.live) >>>
    AuthService.live

  private val fullLayers = baseLayers ++ noopRateLimiter

  private def run(request: Request): ZIO[AuthService & RateLimiter, Nothing, Response] =
    AuthRoutes.routes.run(request).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val validLoginJson   = """{"email":"test@example.com","password":"ValidPass1!"}"""
  private val invalidLoginJson = """{"email":"nobody@example.com","password":"wrong"}"""

  def spec = suite("AuthRoutes")(

    suite("POST /api/auth/login")(
      test("returns 401 for unknown user") {
        val request = Request.post(
          URL.decode("/api/auth/login").toOption.get,
          Body.fromString(invalidLoginJson)
        )
        run(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(fullLayers),

      test("returns 400 for invalid JSON") {
        val request = Request.post(
          URL.decode("/api/auth/login").toOption.get,
          Body.fromString("not-json")
        )
        run(request).map(r => assertTrue(r.status == Status.BadRequest))
      }.provide(fullLayers),

      test("returns 200 with token for valid credentials") {
        for {
          authService <- ZIO.service[AuthService]
          _           <- authService.createUser(CreateUserRequest(
                           email = "test@example.com",
                           password = "ValidPass1!",
                           name = "Test",
                           role = "CLIENT"
                         ))
          request      = Request.post(
                           URL.decode("/api/auth/login").toOption.get,
                           Body.fromString(validLoginJson)
                         )
          response    <- run(request)
          body        <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok,
          body.contains("token")
        )
      }.provide(fullLayers),

      test("returns 429 when rate limit exceeded") {
        val strictLimiter: ZLayer[Any, Nothing, RateLimiter] = ZLayer.fromZIO(
          RateLimiter.make(maxRequests = 0, windowSeconds = 60)
        )
        val layers = baseLayers ++ strictLimiter
        val request = Request.post(
          URL.decode("/api/auth/login").toOption.get,
          Body.fromString(validLoginJson)
        )
        run(request).map(r => assertTrue(r.status == Status.TooManyRequests))
      }.provide(
        TestLayers.inMemoryPersonRepository ++
        TestLayers.inMemoryTokenRepository ++
        (testJwtConfig >>> JwtService.live) >>>
        AuthService.live,
        ZLayer.fromZIO(RateLimiter.make(maxRequests = 0, windowSeconds = 60))
      )
    )
  )
}
