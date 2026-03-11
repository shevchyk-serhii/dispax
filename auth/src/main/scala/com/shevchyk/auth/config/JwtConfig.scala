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

  private val defaultDevSecret = "dev-secret-key-that-should-be-changed-in-production-must-be-at-least-256-bits"

  val live: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed {
    val secret = sys.env.getOrElse(
      "JWT_SECRET",
      if Environment.isProduction then
        throw new RuntimeException("JWT_SECRET environment variable must be set in production")
      else defaultDevSecret
    )
    JwtConfig(
      secret = secret,
      issuer = if Environment.isProduction then "oktopus" else "oktopus-dev",
      audience = "oktopus-api",
      expirationTime = Duration.fromNanos(24 * 60 * 60 * 1_000_000_000L) // 24 hours
    )
  }
