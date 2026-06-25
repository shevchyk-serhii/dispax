package com.shevchyk.auth.infrastructure.http

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

import java.util.UUID

object AuthenticatedHandlersSpec extends ZIOSpecDefault {

  private val userId    = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val companyId = UUID.fromString("00000002-0000-0000-0000-000000000002")

  private val jwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
        issuer = "test",
        audience = "test",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def makeToken: ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(userId),
        email = "test@example.com",
        name = "Test",
        role = PersonRole.Dispatcher,
        passwordHash = "hash",
        companyId = Some(CompanyId(companyId)),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def requestWithToken(token: String): Request = Request
    .get(URL.decode("/test").toOption.get)
    .addHeader("Authorization", s"Bearer $token")

  case class TestBody(name: String) derives JsonCodec

  def spec =
    suite("AuthenticatedHandlers")(
      suite("authenticatedHandler")(
        test("executes handler when token is valid") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers.authenticatedHandler {
            (user, _) =>
              ZIO.succeed(Response.text(user.role))
          }
          for {
            token    <- makeToken
            response <- h.runZIO(requestWithToken(token))
            body     <- response.body.asString
          } yield assertTrue(response.status == Status.Ok && body == "DISPATCHER")
        }.provide(jwtLayer),
        test("returns 401 when token is missing") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers.authenticatedHandler {
            (user, _) =>
              ZIO.succeed(Response.text(user.role))
          }
          val req                                                 = Request.get(URL.decode("/test").toOption.get)
          h.runZIO(req).map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(jwtLayer),
        test("returns 500 when handler throws unexpected exception") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers.authenticatedHandler {
            (_, _) =>
              ZIO.fail(new RuntimeException("unexpected boom"))
          }
          for {
            token    <- makeToken
            response <- h.runZIO(requestWithToken(token))
          } yield assertTrue(response.status == Status.InternalServerError)
        }.provide(jwtLayer)
      ),
      suite("authenticatedJsonHandler")(
        test("parses JSON body and executes handler") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers
            .authenticatedJsonHandler[Any, TestBody] { (_, body) =>
              ZIO.succeed(Response.text(body.name))
            }
          for {
            token    <- makeToken
            request   = requestWithToken(token).copy(
                          body = Body.fromString("""{"name":"Alice"}""")
                        )
            response <- h.runZIO(request)
            body     <- response.body.asString
          } yield assertTrue(response.status == Status.Ok && body == "Alice")
        }.provide(jwtLayer),
        test("returns 400 for invalid JSON body") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers
            .authenticatedJsonHandler[Any, TestBody] { (_, body) =>
              ZIO.succeed(Response.text(body.name))
            }
          for {
            token    <- makeToken
            request   = requestWithToken(token).copy(
                          body = Body.fromString("not-json")
                        )
            response <- h.runZIO(request)
          } yield assertTrue(response.status == Status.BadRequest)
        }.provide(jwtLayer),
        test("returns 401 when token is missing") {
          val h: Handler[JwtService, Response, Request, Response] = AuthenticatedHandlers
            .authenticatedJsonHandler[Any, TestBody] { (_, body) =>
              ZIO.succeed(Response.text(body.name))
            }
          val req                                                 = Request.post(URL.decode("/test").toOption.get, Body.fromString("""{"name":"X"}"""))
          h.runZIO(req).map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(jwtLayer)
      ),
      suite("authenticatedPathHandler")(
        test("provides path param and user to handler") {
          val h: Handler[JwtService, Response, (String, Request), Response] = AuthenticatedHandlers
            .authenticatedPathHandler[Any, String] { (user, param, _) =>
              ZIO.succeed(Response.text(s"${user.role}:$param"))
            }
          for {
            token    <- makeToken
            request   = requestWithToken(token)
            response <- h.runZIO(("my-param", request))
            body     <- response.body.asString
          } yield assertTrue(response.status == Status.Ok && body == "DISPATCHER:my-param")
        }.provide(jwtLayer),
        test("returns 401 when token is missing") {
          val h: Handler[JwtService, Response, (String, Request), Response] = AuthenticatedHandlers
            .authenticatedPathHandler[Any, String] { (user, param, _) =>
              ZIO.succeed(Response.text(s"${user.role}:$param"))
            }
          val req                                                           = Request.get(URL.decode("/test").toOption.get)
          h.runZIO(("param", req)).map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(jwtLayer)
      )
    )
}
