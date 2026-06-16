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

  // Default secret for development/test only — never used in production.
  private val DevSecret = "dev-jwt-secret-change-in-production-must-be-at-least-256-bits"

  /**
   * Resolves JWT_SECRET via the ZIO config/env channel instead of throwing. In production a missing JWT_SECRET fails
   * the layer (and therefore startup) rather than silently falling back to the dev default.
   */
  val live: ZLayer[Any, Config.Error, JwtConfig] = ZLayer.fromZIO {
    System
      .env("JWT_SECRET")
      .orDie
      .flatMap {
        case Some(s)                          => ZIO.succeed(s)
        case None if Environment.isProduction =>
          ZIO.fail(Config.Error.MissingData(message = "JWT_SECRET environment variable must be set in production"))
        case None                             => ZIO.succeed(DevSecret)
      }
      .map { secret =>
        JwtConfig(
          secret = secret,
          issuer = if Environment.isProduction then "dispax" else "dispax-dev",
          audience = "dispax-api",
          expirationTime = Duration.fromNanos(24 * 60 * 60 * 1_000_000_000L) // 24 hours
        )
      }
  }
