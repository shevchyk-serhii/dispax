package com.shevchyk.auth.middleware

import com.shevchyk.auth.service.{JwtService, JwtPayload}
import com.shevchyk.auth.domain.{JwtError, InvalidTokenError, ExpiredTokenError}
import zio.*
import zio.http.*
import zio.json.*

case class AuthenticatedUser(
    userId: Long,
    email: String,
    role: String
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
                role = payload.role.toString
              )
            }
          )

  private def extractTokenFromRequest(request: Request): Option[String] = request.headers
    .get(Header.Authorization.name)
    .filter(_.startsWith("Bearer "))
    .map(_.substring(7).trim)
    .filter(_.nonEmpty)

  // Helper to get authenticated user from environment
  def getAuthenticatedUser: ZIO[AuthenticatedUser, Nothing, AuthenticatedUser] = ZIO.service[AuthenticatedUser]

  // Helper to check if user has specific role
  def requireRole(role: String): ZIO[AuthenticatedUser, Response, Unit] = getAuthenticatedUser.flatMap { user =>
    if (user.role != role)
      ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Insufficient permissions"}""")))
    else
      ZIO.unit
  }

  // Helper to check if user can access resource (owns it)
  def requireOwnership(resourceUserId: Long): ZIO[AuthenticatedUser, Response, Unit] = getAuthenticatedUser.flatMap {
    user =>
      if (user.userId != resourceUserId)
        ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
      else
        ZIO.unit
  }
