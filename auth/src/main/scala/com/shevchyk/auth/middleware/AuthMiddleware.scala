package com.shevchyk.auth.middleware

import com.shevchyk.auth.service.{JwtService, JwtPayload}
import com.shevchyk.auth.domain.{JwtError, InvalidTokenError, ExpiredTokenError}
import zio.*
import zio.http.*
import zio.json.*
import java.util.UUID

case class AuthenticatedUser(
    userId: UUID,
    email: String,
    role: String,
    companyId: Option[UUID] = None,
    clientCompanyId: Option[UUID] = None
)

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
              AuthenticatedUser(
                userId = payload.userId,
                email = payload.email,
                role = payload.role.toString,
                companyId = payload.companyId,
                clientCompanyId = payload.clientCompanyId
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
    if (user.role.toUpperCase != role.toUpperCase)
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Insufficient permissions"}""")))
    else
      ZIO.unit
  }

  def requireOwnership(resourceUserId: UUID): ZIO[AuthenticatedUser, Response, Unit] = getAuthenticatedUser.flatMap {
    user =>
      if (user.userId != resourceUserId)
        ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
      else
        ZIO.unit
  }

  /**
   * Check that the user has one of the allowed roles
   */
  def checkRole(user: AuthenticatedUser, roles: String*): IO[Response, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if (roles.exists(_.toUpperCase == userRoleUpper))
      ZIO.unit
    else
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Insufficient permissions"}""")))

  /**
   * Check that the user has one of the allowed roles OR is the resource owner
   */
  def checkRoleOrOwner(user: AuthenticatedUser, resourceOwnerId: UUID, roles: String*): IO[Response, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if (roles.exists(_.toUpperCase == userRoleUpper) || user.userId == resourceOwnerId)
      ZIO.unit
    else
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))

  /**
   * Returns true if the user is a platform SuperAdmin (role = SUPER_ADMIN). Pure Boolean helper for non-Tapir code
   * paths (WebSocket, DevRoutes) that may need this check.
   *
   * Compares case-insensitively and ignores underscores so that both the Scala enum `.toString` form ("SuperAdmin") and
   * the JSON-encoder form ("SUPER_ADMIN") are recognised as valid.
   */
  def isSuperAdmin(user: AuthenticatedUser): Boolean = user.role.toUpperCase.replace("_", "") == "SUPERADMIN"
