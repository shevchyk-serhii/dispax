package com.shevchyk.ride.helpers

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId, UserStatus}
import zio.*
import java.util.UUID
import scala.concurrent.duration.Duration

object TestJWT {

  def generateToken(
      userId: UUID,
      email: String = "test@example.com",
      role: PersonRole = PersonRole.Client,
      companyId: Option[UUID] = None
  ): ZIO[JwtService, Throwable, String] = {
    val person = Person(
      id = PersonId(userId),
      email = email,
      name = "Test User",
      role = role,
      passwordHash = "test-hash",
      companyId = companyId.map(CompanyId.apply),
      status = UserStatus.ACTIVE
    )
    ZIO.serviceWithZIO[JwtService](_.generateToken(person))
  }

  val testConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  val testJwtService: ZLayer[Any, Nothing, JwtService] =
    testConfig >>> JwtService.live
}
