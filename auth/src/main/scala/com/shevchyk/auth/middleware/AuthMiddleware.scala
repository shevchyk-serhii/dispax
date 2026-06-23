package com.shevchyk.auth.middleware

import com.shevchyk.auth.service.{JwtService, JwtPayload}
import com.shevchyk.auth.domain.{JwtError, InvalidTokenError, ExpiredTokenError}
import com.shevchyk.core.domain.PersonRole
import zio.*
import zio.http.*
import zio.json.*
import java.util.UUID

case class AuthenticatedUser(
    userId: UUID,
    email: String,
    // primaryRole: the single role used for dashboard routing and display.
    // `role` is kept as the field name for backward compatibility with existing call sites
    // that read `user.role` for display purposes.
    role: String,
    companyId: Option[UUID] = None,
    clientCompanyId: Option[UUID] = None,
    // roles: the full set of wire-format role strings; always non-empty.
    // Legacy tokens that lack the `roles` payload field fall back to Set(role).
    roles: Set[String] = Set.empty
):
  /**
   * The canonical primary-role string (same as `role`).
   */
  def primaryRole: String = role

  /**
   * The effective set of wire-format role strings the user carries. Uses the full `roles` set when present (multi-role
   * users such as a dispatcher who can also drive) and falls back to the primary `role` for legacy tokens that lack the
   * `roles` payload field. Single source of truth for every Tapir secure layer's role check.
   */
  def effectiveRoles: Set[String] = if roles.nonEmpty then roles else Set(role)

  /**
   * True when any of the user's effective roles matches one of the allowed roles (case-insensitive).
   */
  def hasAnyRole(allowedRoles: String*): Boolean =
    val userRoles = effectiveRoles
    allowedRoles.exists(r => userRoles.exists(_.toUpperCase == r.toUpperCase))

object AuthenticatedUser:
  implicit val encoder: JsonEncoder[AuthenticatedUser] = DeriveJsonEncoder.gen[AuthenticatedUser]

object AuthMiddleware:

  def authenticateRequest(request: Request): ZIO[JwtService, Response, AuthenticatedUser] =
    extractTokenFromRequest(request) match
      case None =>
        ZIO.fail(Response(Status.Unauthorized, body = Body.fromString("""{"error":"Missing Authorization header"}""")))

      case Some(token) =>
        ZIO
          .serviceWithZIO[JwtService](_.validateToken(token))
          .mapBoth(
            {
              case _: InvalidTokenError | _: ExpiredTokenError =>
                Response(Status.Unauthorized, body = Body.fromString("""{"error":"Invalid or expired token"}"""))
              case _: JwtError                                 =>
                Response(Status.Unauthorized, body = Body.fromString("""{"error":"Authentication failed"}"""))
              case _                                           =>
                Response(Status.InternalServerError, body = Body.fromString("""{"error":"Internal server error"}"""))
            },
            { payload =>
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
            }
          )

  private def extractTokenFromRequest(request: Request): Option[String] = request.headers
    .get(Header.Authorization.name)
    .filter(_.startsWith("Bearer "))
    .map(_.substring(7).trim)
    .filter(_.nonEmpty)

  def getAuthenticatedUser: ZIO[AuthenticatedUser, Nothing, AuthenticatedUser] = ZIO.service[AuthenticatedUser]

  def requireRole(role: String): ZIO[AuthenticatedUser, Response, Unit] = getAuthenticatedUser.flatMap { user =>
    // A user may carry multiple roles; the check passes when any role matches.
    val effectiveRoles = if user.roles.nonEmpty then user.roles else Set(user.role)
    if (effectiveRoles.exists(_.toUpperCase == role.toUpperCase))
      ZIO.unit
    else
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Insufficient permissions"}""")))
  }

  def requireOwnership(resourceUserId: UUID): ZIO[AuthenticatedUser, Response, Unit] = getAuthenticatedUser.flatMap {
    user =>
      if (user.userId != resourceUserId)
        ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
      else
        ZIO.unit
  }

  /**
   * Check that the user has one of the allowed roles (intersection of user.roles and the provided set).
   */
  def checkRole(user: AuthenticatedUser, allowedRoles: String*): IO[Response, Unit] =
    val effectiveRoles = if user.roles.nonEmpty then user.roles else Set(user.role)
    if (allowedRoles.exists(r => effectiveRoles.exists(_.toUpperCase == r.toUpperCase)))
      ZIO.unit
    else
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Insufficient permissions"}""")))

  /**
   * Check that the user has one of the allowed roles OR is the resource owner.
   */
  def checkRoleOrOwner(user: AuthenticatedUser, resourceOwnerId: UUID, allowedRoles: String*): IO[Response, Unit] =
    val effectiveRoles = if user.roles.nonEmpty then user.roles else Set(user.role)
    if (
        allowedRoles
          .exists(r => effectiveRoles.exists(_.toUpperCase == r.toUpperCase)) || user.userId == resourceOwnerId
    )
      ZIO.unit
    else
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))

  /**
   * Returns true if the user is a platform SuperAdmin (any role in the set = SUPER_ADMIN). Pure Boolean helper for
   * non-Tapir code paths (WebSocket, DevRoutes) that may need this check.
   *
   * Compares case-insensitively and ignores underscores so that both the Scala enum `.toString` form ("SuperAdmin") and
   * the JSON-encoder form ("SUPER_ADMIN") are recognised as valid.
   */
  def isSuperAdmin(user: AuthenticatedUser): Boolean =
    val effectiveRoles = if user.roles.nonEmpty then user.roles else Set(user.role)
    effectiveRoles.exists(_.toUpperCase.replace("_", "") == "SUPERADMIN")
