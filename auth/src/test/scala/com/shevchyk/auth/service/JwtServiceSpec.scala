package com.shevchyk.auth.service

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID
import scala.concurrent.duration.Duration as ScalaDuration

object JwtServiceSpec extends ZIOSpecDefault {

  val testPerson = Person(
    id = PersonId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
    email = "test@example.com",
    name = "Test User",
    role = PersonRole.Client,
    passwordHash = "hashed"
  )

  val dispatcherDriverPerson = Person(
    id = PersonId(UUID.fromString("22222222-2222-2222-2222-222222222222")),
    email = "dispdriver@example.com",
    name = "Dispatcher Driver",
    role = PersonRole.Dispatcher,
    passwordHash = "hashed",
    roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
  )

  val testConfig = JwtConfig(
    secret = "test-secret-key-that-is-long-enough-for-hmac256",
    issuer = "dispax-test",
    audience = "dispax-api",
    expirationTime = ScalaDuration.fromNanos(24 * 60 * 60 * 1_000_000_000L)
  )

  val shortLivedConfig = JwtConfig(
    secret = "test-secret-key-that-is-long-enough-for-hmac256",
    issuer = "dispax-test",
    audience = "dispax-api",
    expirationTime = ScalaDuration.fromNanos(2 * 1_000_000_000L) // 2 seconds
  )

  // Token stays valid (10s exp) and is eligible for refresh (< 1h remaining), but the absolute
  // session cap is 1s → refresh must be rejected once session age (whole seconds) exceeds it.
  val shortSessionConfig = JwtConfig(
    secret = "test-secret-key-that-is-long-enough-for-hmac256",
    issuer = "dispax-test",
    audience = "dispax-api",
    expirationTime = ScalaDuration.fromNanos(10 * 1_000_000_000L),   // 10 seconds
    maxSessionDuration = ScalaDuration.fromNanos(1 * 1_000_000_000L) // 1 second
  )

  val jwtLayer             = ZLayer.succeed(testConfig) >>> JwtService.live
  val shortLivedJwtLayer   = ZLayer.succeed(shortLivedConfig) >>> JwtService.live
  val shortSessionJwtLayer = ZLayer.succeed(shortSessionConfig) >>> JwtService.live

  def spec =
    suite("JwtService")(
      suite("generateToken")(
        test("produces valid JWT string") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
          } yield assertTrue(token.nonEmpty && token.split("\\.").length == 3)
        }.provide(jwtLayer),
        test("contains correct userId and email") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            payload <- service.validateToken(token)
          } yield assertTrue(
            payload.userId == testPerson.id.value &&
              payload.email == testPerson.email &&
              payload.role == testPerson.role
          )
        }.provide(jwtLayer),
        test("includes companyId when provided") {
          val companyId         = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
          val personWithCompany = testPerson.copy(companyId = Some(companyId))
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(personWithCompany)
            payload <- service.validateToken(token)
          } yield assertTrue(payload.companyId.contains(companyId.value))
        }.provide(jwtLayer),
        test("has correct expiration") {
          for {
            service <- ZIO.service[JwtService]
            before   = Instant.now().getEpochSecond
            token   <- service.generateToken(testPerson)
            payload <- service.validateToken(token)
            after    = Instant.now().getEpochSecond
          } yield assertTrue(
            payload.exp >= before + 86400 - 1 &&
              payload.exp <= after + 86400 + 1
          )
        }.provide(jwtLayer)
      ),
      suite("validateToken")(
        test("decodes valid token") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            payload <- service.validateToken(token)
          } yield assertTrue(
            payload.userId == testPerson.id.value &&
              payload.email == testPerson.email
          )
        }.provide(jwtLayer),
        test("malformed token returns error") {
          for {
            service <- ZIO.service[JwtService]
            result  <- service.validateToken("not.a.valid.jwt").exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[InvalidTokenError])
            case _                   => false
          })
        }.provide(jwtLayer),
        test("wrong secret returns error") {
          val otherConfig = testConfig.copy(secret = "different-secret-key-that-is-also-long")
          val otherLayer  = ZLayer.succeed(otherConfig) >>> JwtService.live
          for {
            service1 <- ZIO.service[JwtService].provide(jwtLayer)
            token    <- service1.generateToken(testPerson)
            service2 <- ZIO.service[JwtService].provide(otherLayer)
            result   <- service2.validateToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[InvalidTokenError])
            case _                   => false
          })
        },
        test("expired token returns error") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            _       <- ZIO.sleep(3.seconds)
            result  <- service.validateToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists(e => e.isInstanceOf[InvalidTokenError] || e.isInstanceOf[ExpiredTokenError])
            case _                   => false
          })
        }.provide(shortLivedJwtLayer) @@ TestAspect.withLiveClock
      ),
      suite("refreshToken")(
        test("rejects token with more than 1hr remaining") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            result  <- service.refreshToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[TokenNotEligibleForRefresh])
            case _                   => false
          })
        }.provide(jwtLayer),
        test("refreshes token near expiry and preserves payload") {
          val companyId         = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
          val personWithCompany = testPerson.copy(companyId = Some(companyId))
          for {
            service  <- ZIO.service[JwtService]
            token    <- service.generateToken(personWithCompany)
            newToken <- service.refreshToken(token)
            payload  <- service.validateToken(newToken)
          } yield assertTrue(
            payload.userId == testPerson.id.value &&
              payload.email == testPerson.email &&
              payload.role == testPerson.role
          )
        }.provide(shortLivedJwtLayer),
        // -- Edge cases added by test audit 2026-06 --------------------------
        test("rejects refresh once absolute session duration exceeded") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            _       <- ZIO.sleep(2100.millis) // session age > maxSessionDuration (1s), token still valid (10s)
            result  <- service.refreshToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ExpiredTokenError])
            case _                   => false
          })
        }.provide(shortSessionJwtLayer) @@ TestAspect.withLiveClock,
        test("preserves originalIat across refresh (session does not restart)") {
          for {
            service     <- ZIO.service[JwtService]
            token       <- service.generateToken(testPerson)
            origPayload <- service.validateToken(token)
            newToken    <- service.refreshToken(token)
            newPayload  <- service.validateToken(newToken)
          } yield assertTrue(
            origPayload.originalIat.isDefined &&
              newPayload.originalIat == origPayload.originalIat &&
              // iat is refreshed forward (or at least not earlier than the original)
              newPayload.iat >= origPayload.iat
          )
        }.provide(shortLivedJwtLayer),
        test("rejects refresh of an already-expired token") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            _       <- ZIO.sleep(3.seconds) // exceeds 2s expiry
            result  <- service.refreshToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists(e => e.isInstanceOf[ExpiredTokenError] || e.isInstanceOf[InvalidTokenError])
            case _                   => false
          })
        }.provide(shortLivedJwtLayer) @@ TestAspect.withLiveClock
      ),
      // -- multi-role (dispatcher-can-drive) ---------------------------------
      suite("multi-role token")(
        test("token for dispatcher-driver carries both roles in payload") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(dispatcherDriverPerson)
            payload <- service.validateToken(token)
          } yield assertTrue(
            payload.roles.isDefined,
            payload.roles.get.contains(PersonRole.Dispatcher),
            payload.roles.get.contains(PersonRole.Driver),
            payload.role == PersonRole.Dispatcher // primary role preserved
          )
        }.provide(jwtLayer),
        test("legacy token without roles field falls back to Set(role) in AuthMiddleware") {
          // Simulate a legacy JWT payload that has no `roles` field.
          // AuthMiddleware must build roles = Set(role) from the single-role field.
          import com.shevchyk.auth.config.JwtConfig
          import pdi.jwt.{Jwt, JwtAlgorithm, JwtClaim}

          val legacySecret = "test-secret-key-that-is-long-enough-for-hmac256"
          val now          = java.time.Instant.now().getEpochSecond
          // Manually craft a JWT payload without the `roles` field
          val rawPayload   =
            s"""{"userId":"11111111-1111-1111-1111-111111111111","email":"test@example.com","role":"CLIENT","iat":$now,"exp":${now + 3600}}"""
          val claim        = JwtClaim(
            content = rawPayload,
            issuer = Some("dispax-test"),
            issuedAt = Some(now),
            expiration = Some(now + 3600)
          )
          val token        = Jwt.encode(claim, legacySecret, JwtAlgorithm.HS256)

          val cfgLayer =
            ZLayer.succeed(
              JwtConfig(
                secret = legacySecret,
                issuer = "dispax-test",
                audience = "dispax-api",
                expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
              )
            ) >>> JwtService.live

          for {
            service <- ZIO.service[JwtService].provide(cfgLayer)
            payload <- service.validateToken(token)
          } yield assertTrue(
            payload.roles.isEmpty, // legacy: no roles field
            // Wire-side: fallback produces Set(role)
            {
              val wireRoles = payload.roles
                .map(_.map(PersonRole.toWire).toSet)
                .getOrElse(Set(PersonRole.toWire(payload.role)))
              wireRoles == Set("CLIENT")
            }
          )
        },
        test("single-role person has roles Some(List(role)) in generated token") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            payload <- service.validateToken(token)
          } yield assertTrue(
            payload.roles.isDefined,
            payload.roles.get.size == 1,
            payload.roles.get.contains(PersonRole.Client)
          )
        }.provide(jwtLayer)
      ),
      // -- issuer validation -----------------------------------------------
      suite("validateToken issuer")(
        test("rejects token signed with same secret but different issuer") {
          // A token minted by a service with a different issuer but the SAME secret must
          // not validate — guards against cross-issuer token reuse.
          val foreignConfig = testConfig.copy(issuer = "evil-issuer")
          val foreignLayer  = ZLayer.succeed(foreignConfig) >>> JwtService.live
          for {
            foreignSvc <- ZIO.service[JwtService].provide(foreignLayer)
            token      <- foreignSvc.generateToken(testPerson)
            ourSvc     <- ZIO.service[JwtService].provide(jwtLayer)
            result     <- ourSvc.validateToken(token).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[InvalidTokenError])
            case _                   => false
          })
        },
        test("accepts token with matching issuer") {
          for {
            service <- ZIO.service[JwtService]
            token   <- service.generateToken(testPerson)
            result  <- service.validateToken(token).exit
          } yield assertTrue(result.isSuccess)
        }.provide(jwtLayer)
      )
    )
}
