package com.shevchyk.app.openapi

import java.util.UUID

import zio.{ZIO, ZLayer}

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, Person, PersonId, PersonRole, UserStatus}

/**
 * Shared JWT test wiring for the api route specs: a deterministic [[JwtService]] layer plus a helper that mints a
 * bearer token for a given role/company. Mirrors the inline setup `RideAssignIsolationSpec` grew, lifted here so the
 * checkpoint specs reuse it instead of copying it.
 */
object TestJwt:

  private val config: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  val serviceLayer: ZLayer[Any, Nothing, JwtService] = config >>> JwtService.live

  def generateToken(role: PersonRole, companyId: CompanyId): ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = s"${role.toString.toLowerCase}@test.de",
          name = s"${role.toString} User",
          role = role,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )
