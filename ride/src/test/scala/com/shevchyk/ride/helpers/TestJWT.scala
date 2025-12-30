package com.shevchyk.ride.helpers

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.auth.domain.{User, UserRole}
import zio.*
import java.util.UUID
import scala.concurrent.duration.Duration

object TestJWT {

  /**
   * Generates a valid JWT token for testing
   */
  def generateToken(
      userId: UUID,
      email: String = "test@example.com",
      role: UserRole = UserRole.CLIENT,
      companyId: Option[UUID] = None
  ): ZIO[JwtService, Throwable, String] = {
    val user = User(
      id = userId,
      email = email,
      name = "Test User",
      role = role,
      passwordHash = "test-hash",
      phone = None,
      status = com.shevchyk.auth.domain.UserStatus.ACTIVE,
      createdAt = java.time.Instant.now(),
      updatedAt = None
    )
    ZIO.serviceWithZIO[JwtService](_.generateToken(user, companyId))
  }

  /**
   * Test JWT configuration with predictable secret
   */
  val testConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L) // 24 hours
    )
  )

  /**
   * Test JWT service layer
   */
  val testJwtService: ZLayer[Any, Nothing, JwtService] =
    testConfig >>> JwtService.live
}
