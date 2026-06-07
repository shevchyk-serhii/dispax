package com.shevchyk.auth.middleware

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*
import java.util.UUID

object AuthMiddlewareSpec extends ZIOSpecDefault {

  private val companyId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val userId    = UUID.fromString("00000002-0000-0000-0000-000000000002")

  private val jwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
        issuer = "test",
        audience = "test",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def makeToken(role: PersonRole, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(userId),
          email = "test@example.com",
          name = "Test",
          role = role,
          passwordHash = "hash",
          companyId = cid.map(CompanyId.apply),
          status = UserStatus.ACTIVE
        )
      )
    )

  private def requestWithBearer(token: String): Request = Request
    .get(URL.decode("/test").toOption.get)
    .addHeader("Authorization", s"Bearer $token")

  def spec =
    suite("AuthMiddleware")(
      suite("authenticateRequest")(
        test("succeeds with valid Bearer token") {
          for {
            token <- makeToken(PersonRole.Dispatcher)
            user  <- AuthMiddleware.authenticateRequest(requestWithBearer(token))
          } yield assertTrue(user.role == "Dispatcher" && user.userId == userId)
        }.provide(jwtLayer),
        test("fails with 401 when Authorization header is missing") {
          val req = Request.get(URL.decode("/test").toOption.get)
          AuthMiddleware.authenticateRequest(req).flip.map { resp =>
            assertTrue(resp.status == Status.Unauthorized)
          }
        }.provide(jwtLayer),
        test("fails with 401 when token is not Bearer") {
          val req = Request.get(URL.decode("/test").toOption.get).addHeader("Authorization", "Basic abc123")
          AuthMiddleware.authenticateRequest(req).flip.map { resp =>
            assertTrue(resp.status == Status.Unauthorized)
          }
        }.provide(jwtLayer),
        test("fails with 401 when Bearer token is empty") {
          val req = Request.get(URL.decode("/test").toOption.get).addHeader("Authorization", "Bearer ")
          AuthMiddleware.authenticateRequest(req).flip.map { resp =>
            assertTrue(resp.status == Status.Unauthorized)
          }
        }.provide(jwtLayer),
        test("fails with 401 for invalid token") {
          val req = requestWithBearer("not.a.valid.jwt.token")
          AuthMiddleware.authenticateRequest(req).flip.map { resp =>
            assertTrue(resp.status == Status.Unauthorized)
          }
        }.provide(jwtLayer),
        test("maps companyId from token payload") {
          for {
            token <- makeToken(PersonRole.Driver, cid = Some(companyId))
            user  <- AuthMiddleware.authenticateRequest(requestWithBearer(token))
          } yield assertTrue(user.companyId.contains(companyId))
        }.provide(jwtLayer),
        test("companyId is None when user has no company") {
          for {
            token <- makeToken(PersonRole.Client, cid = None)
            user  <- AuthMiddleware.authenticateRequest(requestWithBearer(token))
          } yield assertTrue(user.companyId.isEmpty)
        }.provide(jwtLayer)
      ),
      suite("checkRole")(
        test("succeeds when role matches (case-insensitive)") {
          val user = AuthenticatedUser(userId, "e@e.com", "dispatcher")
          AuthMiddleware.checkRole(user, "DISPATCHER").map(_ => assertCompletes)
        },
        test("succeeds when role matches one of multiple allowed") {
          val user = AuthenticatedUser(userId, "e@e.com", "DRIVER")
          AuthMiddleware.checkRole(user, "DISPATCHER", "DRIVER", "ADMIN").map(_ => assertCompletes)
        },
        test("fails with 403 when role does not match") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT")
          AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN").flip.map { resp =>
            assertTrue(resp.status == Status.Forbidden)
          }
        },
        test("is case-insensitive for user role") {
          val user = AuthenticatedUser(userId, "e@e.com", "Admin")
          AuthMiddleware.checkRole(user, "admin").map(_ => assertCompletes)
        }
      ),
      suite("checkRoleOrOwner")(
        test("succeeds when user has allowed role") {
          val user    = AuthenticatedUser(userId, "e@e.com", "DISPATCHER")
          val otherId = UUID.randomUUID()
          AuthMiddleware.checkRoleOrOwner(user, otherId, "DISPATCHER").map(_ => assertCompletes)
        },
        test("succeeds when user is the resource owner") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT")
          AuthMiddleware.checkRoleOrOwner(user, userId, "DISPATCHER").map(_ => assertCompletes)
        },
        test("fails when user has wrong role AND is not owner") {
          val user    = AuthenticatedUser(userId, "e@e.com", "CLIENT")
          val otherId = UUID.randomUUID()
          AuthMiddleware.checkRoleOrOwner(user, otherId, "DISPATCHER").flip.map { resp =>
            assertTrue(resp.status == Status.Forbidden)
          }
        }
      )
    )
}
