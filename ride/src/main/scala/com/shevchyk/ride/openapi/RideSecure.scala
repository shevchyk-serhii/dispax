package com.shevchyk.ride.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.core.openapi.{ApiError, ScheduleConflictDetails}
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

  /**
   * Participation guard for per-ride resources (e.g. the ride chat): only the ride's client, its assigned driver, or
   * company staff (dispatcher/secretary/admin) may access them. Any other user of the same company gets 403 — the same
   * mapping `RideError.UnauthorizedAccess` uses. Callers must have verified company isolation first.
   */
  def checkRideParticipant(user: AuthenticatedUser, ride: com.shevchyk.ride.domain.Ride): ZIO[Any, Err, Unit] =
    val isParticipant = ride.clientId.value == user.userId || ride.driverId.exists(_.value == user.userId)
    if isParticipant || user.hasAnyRole("DISPATCHER", "SECRETARY", "ADMIN") then ZIO.unit
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
      case RideError.ValidationError(msg)                                        => (StatusCode.BadRequest, ApiError(s"Validation error: $msg"))
      case RideError.RideNotFound(id)                                            => (StatusCode.NotFound, ApiError(s"Ride not found: ${id.value}"))
      case RideError.PersonNotFound(id)                                          => (StatusCode.NotFound, ApiError(s"Person not found: ${id.value}"))
      case RideError.DriverNotFound(id)                                          => (StatusCode.NotFound, ApiError(s"Driver not found: ${id.value}"))
      case RideError.UnauthorizedAccess(_, _)                                    => (StatusCode.Forbidden, ApiError("Access denied"))
      case RideError.InvalidStatusTransition(from, to)                           =>
        (StatusCode.Conflict, ApiError(s"Cannot transition from $from to $to"))
      case RideError.RideAlreadyAssigned(_, _)                                   => (StatusCode.Conflict, ApiError("Ride already assigned"))
      case RideError.ScheduleConflict(msg, rideId, clientId, from, to, pickupAt) =>
        val details =
          if rideId.isEmpty && from.isEmpty then None
          else
            Some(
              ScheduleConflictDetails(
                rideId = rideId.map(_.value.toString),
                clientId = clientId.map(_.value.toString),
                from = from,
                to = to,
                pickupAt = pickupAt.map(_.toString)
              )
            )
        (StatusCode.Conflict, ApiError(msg, scheduleConflict = details))
      case RideError.BusinessRuleViolation(_, msg)                               => (StatusCode.BadRequest, ApiError(msg))
      case RideError.InvalidOperation(msg)                                       => (StatusCode.UnprocessableEntity, ApiError(msg))
      case RideError.ExternalDriverNotFound(id)                                  =>
        (StatusCode.NotFound, ApiError(s"External driver not found: ${id.value}"))
      case RideError.PartnerCompanyNotFound(id)                                  =>
        (StatusCode.NotFound, ApiError(s"Partner company not found: ${id.value}"))
      case RideError.DatabaseError(_)                                            => (StatusCode.InternalServerError, ApiError("Internal server error"))
      case _                                                                     => (StatusCode.InternalServerError, ApiError("Internal server error"))

  /**
   * Map a `ChatError` to HTTP, following the same conventions as [[fromRideError]] (404 for a missing ride, 400 for
   * validation/business-rule failures, 500 for storage failures — never leaking internals).
   */
  def fromChatError(error: com.shevchyk.ride.domain.ChatError): Err =
    import com.shevchyk.ride.domain.ChatError
    error match
      case ChatError.RideNotFound(id)    => (StatusCode.NotFound, ApiError(s"Ride not found: ${id.value}"))
      case ChatError.ChatNotAvailable(_) => (StatusCode.BadRequest, ApiError("Chat is only available for active rides"))
      case ChatError.EmptyMessage        => (StatusCode.BadRequest, ApiError("Chat message must not be empty"))
      case ChatError.MessageTooLong(max) =>
        (StatusCode.BadRequest, ApiError(s"Chat message must be at most $max characters"))
      case ChatError.StorageError(_)     => (StatusCode.InternalServerError, ApiError("Internal server error"))
