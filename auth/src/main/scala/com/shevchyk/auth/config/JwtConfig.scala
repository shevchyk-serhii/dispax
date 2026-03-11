package com.shevchyk.auth.config

import com.shevchyk.config.Environment
import zio.*
import scala.concurrent.duration.Duration

final case class JwtConfig(
    secret: String,
    issuer: String,
    audience: String,
    expirationTime: Duration,
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
          throw new RuntimeException(
            "JWT_SECRET environment variable must be set. " +
              "For development, set it in your shell: export JWT_SECRET=<your-secret-at-least-256-bits>"
          )
    JwtConfig(
      secret = secret,
      issuer = if Environment.isProduction then "oktopus" else "oktopus-dev",
      audience = "oktopus-api",
      expirationTime = Duration.fromNanos(24 * 60 * 60 * 1_000_000_000L) // 24 hours
    )
  }
