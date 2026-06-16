package com.shevchyk.app.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.util.UUID

/**
 * Shared building blocks for the api-module Tapir endpoints (package `com.shevchyk.app.openapi`).
 *
 * Declares the authenticated base endpoint once (Bearer security + a `(StatusCode, ApiError)` error channel) plus the
 * helpers that replicate `AuthMiddleware` / `UuidParser` behaviour while staying inside the `(StatusCode, ApiError)`
 * error channel. Mirrors `ride.openapi.RideSecure`.
 */
object AppSecure:

  type Err = (StatusCode, ApiError)

  // -- Authenticated base endpoint (mirrors AuthMiddleware.authenticateRequest) --
  val secureEndpoint = endpoint
    .securityIn(auth.bearer[String]())
    .errorOut(statusCode.and(jsonBody[ApiError]))
    .zServerSecurityLogic[JwtService, AuthenticatedUser] { token =>
      ZIO
        .serviceWithZIO[JwtService](_.validateToken(token))
        .mapBoth(
          {
            case _: InvalidTokenError | _: ExpiredTokenError =>
              (StatusCode.Unauthorized, ApiError("Invalid or expired token"))
            case _: JwtError                                 => (StatusCode.Unauthorized, ApiError("Authentication failed"))
            case _                                           => (StatusCode.InternalServerError, ApiError("Internal server error"))
          },
          payload =>
            AuthenticatedUser(
              userId = payload.userId,
              email = payload.email,
              role = payload.role.toString,
              companyId = payload.companyId,
              clientCompanyId = payload.clientCompanyId
            )
        )
    }

  // -- Role checks (mirror AuthMiddleware.checkRole / checkRoleOrOwner) -----

  def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    ZIO
      .fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))
      .unless(roles.exists(_.toUpperCase == userRoleUpper))
      .unit

  def checkRoleOrOwner(user: AuthenticatedUser, resourceOwnerId: UUID, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    ZIO
      .fail((StatusCode.Forbidden, ApiError("Access denied")))
      .unless(roles.exists(_.toUpperCase == userRoleUpper) || user.userId == resourceOwnerId)
      .unit

  // -- UUID parsing (mirrors UuidParser, which fails with 400) -------------

  def parseUuid(value: String): ZIO[Any, Err, UUID] = ZIO
    .attempt(UUID.fromString(value))
    .orElseFail((StatusCode.BadRequest, ApiError("Invalid UUID format")))

  def parsePersonId(value: String): ZIO[Any, Err, PersonId] = parseUuid(value).map(PersonId(_))

  def parseRideId(value: String): ZIO[Any, Err, RideId] = parseUuid(value).map(RideId(_))

  def requireCompanyId(companyIdOpt: Option[UUID]): ZIO[Any, Err, CompanyId] = ZIO
    .fromOption(companyIdOpt)
    .mapBoth(_ => (StatusCode.BadRequest, ApiError("User must belong to a company")), CompanyId(_))

  // -- SuperAdmin escape-hatch (used ONLY in SuperAdminApi) -----------------
  // These helpers are intentionally narrow: requireSuperAdmin is the ONLY
  // mechanism that bypasses tenant isolation. It must never be called from
  // any of the 24 existing API files — those files continue to call
  // requireCompanyId as before.

  // Compares case-insensitively and ignores underscores so that both the Scala enum `.toString` form
  // ("SuperAdmin") and the JSON-encoder form ("SUPER_ADMIN") are recognised as valid SuperAdmin roles.
  //
  // Collision audit — the seven current PersonRole values and their normalised forms:
  //   Driver          → DRIVER
  //   Client          → CLIENT
  //   Secretary       → SECRETARY
  //   Dispatcher      → DISPATCHER
  //   Admin           → ADMIN
  //   ClientSecretary → CLIENTSECRETARY
  //   SuperAdmin      → SUPERADMIN   ← the only role that matches
  // None of the non-SuperAdmin roles collapses to "SUPERADMIN" under toUpperCase.replace("_",""),
  // so the gate is collision-free today. Any new PersonRole must be re-checked here before merging.
  def isSuperAdmin(user: AuthenticatedUser): Boolean = user.role.toUpperCase.replace("_", "") == "SUPERADMIN"

  def requireSuperAdmin(user: AuthenticatedUser): ZIO[Any, Err, Unit] =
    if isSuperAdmin(user) then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("SuperAdmin access required")))

  /**
   * Generic mapping of any throwable to a 500 ("Internal server error"). The hand-written api-module handlers funnel
   * every non-`Response` failure (missing query params, JSON parse errors, "not found", RuntimeExceptions, etc.)
   * through `RouteErrorHandler.handleError`, which always produces a 500 with this body. Preserve that behaviour.
   */
  def internal(t: Throwable): Err = (StatusCode.InternalServerError, ApiError("Internal server error"))
