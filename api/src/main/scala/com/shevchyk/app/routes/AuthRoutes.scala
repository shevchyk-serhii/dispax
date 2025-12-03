package com.shevchyk.app.routes

import com.shevchyk.service.AuthService
import com.shevchyk.domain.LoginRequest
import zio.*
import zio.http.*
import zio.json.*

object AuthRoutes {
  
  val routes = Routes(
    // Auth endpoints
    Method.POST / "api" / "auth" / "login" ->
      handler { (req: Request) =>
        (for
          body        <- req.body.asString
          loginReq    <- ZIO.fromEither(body.fromJson[LoginRequest])
          authService <- ZIO.service[AuthService]
          loginResp   <- authService.login(loginReq)
        yield loginResp match
          case Some(resp) => Response.json(resp.toJson).status(Status.Ok)
          case None       => Response.status(Status.Unauthorized)
        )
          .catchAll(_ => ZIO.succeed(Response.badRequest("Invalid login data")))
      },
    Method.GET / "api" / "auth" / "me" ->
      handler { (req: Request) =>
        (for
          authHeader  <- ZIO
                           .fromOption(req.headers.get("Authorization"))
                           .orElse(ZIO.fail("Missing Authorization header"))
          token       <- ZIO.succeed(authHeader.stripPrefix("Bearer "))
          authService <- ZIO.service[AuthService]
          person      <- authService.validateToken(token)
        yield person match
          case Some(p) => Response.json(p.toJson).status(Status.Ok)
          case None    => Response.status(Status.Unauthorized)
        )
          .catchAll(_ => ZIO.succeed(Response.status(Status.Unauthorized)))
      },
    Method.GET / "api" / "persons" ->
      handler {
        (for
          authService <- ZIO.service[AuthService]
          persons     <- authService.getAllPersons
        yield Response.json(persons.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      }
  )
}