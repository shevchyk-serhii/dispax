package com.shevchyk.auth.config

import com.shevchyk.core.config.Environment
import zio.*
import scala.concurrent.duration.Duration

final case class JwtConfig(
    secret: String,
    issuer: String,
    audience: String,
    expirationTime: Duration,
    maxSessionDuration: Duration = Duration.fromNanos(90L * 24 * 60 * 60 * 1_000_000_000L), // 90 days
    algorithm: String = "HS256"
)

object JwtConfig:

  val live: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed {
    val secret =
      sys.env.get("JWT_SECRET") match
        case Some(s)                          => s
        case None if Environment.isProduction =>
          throw new RuntimeException("JWT_SECRET environment variable must be set in production")
        case None                             =>
          // Use a default secret for development/test only
          "dev-jwt-secret-change-in-production-must-be-at-least-256-bits"
    JwtConfig(
      secret = secret,
      issuer = if Environment.isProduction then "dispax" else "dispax-dev",
      audience = "dispax-api",
      expirationTime = Duration.fromNanos(24 * 60 * 60 * 1_000_000_000L) // 24 hours
    )
  }
