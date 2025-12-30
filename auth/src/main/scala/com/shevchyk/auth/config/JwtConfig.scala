package com.shevchyk.auth.config

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

  val development: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "dev-secret-key-that-should-be-changed-in-production-must-be-at-least-256-bits",
      issuer = "oktopus-dev",
      audience = "oktopus-api",
      expirationTime = Duration.fromNanos(24 * 60 * 60 * 1_000_000_000L) // 24 hours
    )
  )
