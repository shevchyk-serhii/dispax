package com.shevchyk.ride.openapi

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
 * Shared building blocks for the ride-module Tapir endpoints.
 *
 * Declares the authenticated base endpoint once (Bearer security + a `(StatusCode, ApiError)` error channel so the
 * per-error status codes from the old zio-http handlers are preserved) plus the helpers that replicate `AuthMiddleware`
 * / `UuidParser` behaviour while staying inside the `(StatusCode, ApiError)` error channel.
 */
object RideSecure:

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
            val wireRoles = payload.roles
              .map(_.map(PersonRole.toWire).toSet)
              .getOrElse(Set(PersonRole.toWire(payload.role)))
            AuthenticatedUser(
              userId = payload.userId,
              email = payload.email,
              role = PersonRole.toWire(payload.role),
              companyId = payload.companyId,
              clientCompanyId = payload.clientCompanyId,
              roles = wireRoles
            )
        )
    }

  type Err = (StatusCode, ApiError)

  // -- Role checks (mirror AuthMiddleware.checkRole / checkRoleOrOwner) -----

  def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    if user.hasAnyRole(roles*) then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))

  def checkRoleOrOwner(user: AuthenticatedUser, resourceOwnerId: UUID, roles: String*): ZIO[Any, Err, Unit] =
    if user.hasAnyRole(roles*) || user.userId == resourceOwnerId then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Access denied")))

  // -- UUID parsing (mirrors UuidParser, which fails with 400) -------------

  def parseUuid(value: String): ZIO[Any, Err, UUID] = ZIO
    .attempt(UUID.fromString(value))
    .orElseFail((StatusCode.BadRequest, ApiError("Invalid UUID format")))

  def parsePersonId(value: String): ZIO[Any, Err, PersonId] = parseUuid(value).map(PersonId(_))

  def parseRideId(value: String): ZIO[Any, Err, RideId] = parseUuid(value).map(RideId(_))

  def requireCompanyId(companyIdOpt: Option[UUID]): ZIO[Any, Err, CompanyId] = ZIO
    .fromOption(companyIdOpt)
    .map(CompanyId(_))
    .orElseFail((StatusCode.BadRequest, ApiError("User must belong to a company")))

  // Parse a wire-format role string into a PersonRole via the canonical PersonRole.fromWire, so the two multi-word
  // roles (CLIENT_SECRETARY, SUPER_ADMIN) are recognised instead of silently collapsing into Client. Unknown values
  // fall back to the least-privileged Client.
  def toPersonRole(role: String): PersonRole = PersonRole.fromWire(role).getOrElse(PersonRole.Client)

  /**
   * Map a `RideError` (or any throwable) to the same status/body as `RideRoutes.handleRideError`.
   */
  def fromRideError(ex: Throwable): Err =
    import com.shevchyk.ride.domain.RideError
    ex match
      case RideError.ValidationError(msg)              => (StatusCode.BadRequest, ApiError(s"Validation error: $msg"))
      case RideError.RideNotFound(id)                  => (StatusCode.NotFound, ApiError(s"Ride not found: ${id.value}"))
      case RideError.PersonNotFound(id)                => (StatusCode.NotFound, ApiError(s"Person not found: ${id.value}"))
      case RideError.DriverNotFound(id)                => (StatusCode.NotFound, ApiError(s"Driver not found: ${id.value}"))
      case RideError.UnauthorizedAccess(_, _)          => (StatusCode.Forbidden, ApiError("Access denied"))
      case RideError.InvalidStatusTransition(from, to) =>
        (StatusCode.Conflict, ApiError(s"Cannot transition from $from to $to"))
      case RideError.RideAlreadyAssigned(_, _)         => (StatusCode.Conflict, ApiError("Ride already assigned"))
      case RideError.ScheduleConflict(msg)             => (StatusCode.Conflict, ApiError(msg))
      case RideError.BusinessRuleViolation(_, msg)     => (StatusCode.BadRequest, ApiError(msg))
      case RideError.InvalidOperation(msg)             => (StatusCode.UnprocessableEntity, ApiError(msg))
      case RideError.DatabaseError(_)                  => (StatusCode.InternalServerError, ApiError("Internal server error"))
      case _                                           => (StatusCode.InternalServerError, ApiError("Internal server error"))
