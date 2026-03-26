package com.shevchyk.auth.service

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId, UserStatus}
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

  val testConfig = JwtConfig(
    secret = "test-secret-key-that-is-long-enough-for-hmac256",
    issuer = "oktopus-test",
    audience = "oktopus-api",
    expirationTime = ScalaDuration.fromNanos(24 * 60 * 60 * 1_000_000_000L)
  )

  val shortLivedConfig = JwtConfig(
    secret = "test-secret-key-that-is-long-enough-for-hmac256",
    issuer = "oktopus-test",
    audience = "oktopus-api",
    expirationTime = ScalaDuration.fromNanos(2 * 1_000_000_000L) // 2 seconds
  )

  val jwtLayer = ZLayer.succeed(testConfig) >>> JwtService.live
  val shortLivedJwtLayer = ZLayer.succeed(shortLivedConfig) >>> JwtService.live

  def spec = suite("JwtService")(
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
        val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
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
          case Exit.Failure(cause) => cause.failureOption.exists(e =>
            e.isInstanceOf[InvalidTokenError] || e.isInstanceOf[ExpiredTokenError]
          )
          case _ => false
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
        val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
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
      }.provide(shortLivedJwtLayer)
    )
  )
}
