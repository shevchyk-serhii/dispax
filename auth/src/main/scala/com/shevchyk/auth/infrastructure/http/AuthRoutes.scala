package com.shevchyk.auth.infrastructure.http

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import zio.*
import zio.http.*
import zio.json.*

object AuthRoutes:

  // Organic JSON body parsing handler
  private def jsonHandler[T: JsonDecoder](
      f: T => ZIO[AuthService, Nothing, Response]
  ): Handler[AuthService, Response, Request, Response] = handler { (req: Request) =>
    (for {
      bodyStr <- req.body.asString
      parsed  <- ZIO
                   .fromEither(bodyStr.fromJson[T])
                   .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
      result  <- f(parsed)
    } yield result).catchAll { ex =>
      ZIO.logError(s"JSON parsing error: ${ex.toString}") *>
        ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"Invalid request format"}""")))
    }
  }

  val routes: Routes[AuthService, Response] = Routes(
    Method.POST / "api" / "auth" / "login" -> jsonHandler[LoginRequest] { loginReq =>
      (for {
        _             <- ZIO.logInfo(s"Login request received")
        authService   <- ZIO.service[AuthService]
        loginResponse <- authService.login(loginReq.email, loginReq.password)
        response      <- ZIO.succeed(Response.json(loginResponse.toJson))
      } yield response).catchAll {
        case _: UserNotFound | _: InvalidCredentials =>
          ZIO.succeed(Response(Status.Unauthorized, body = Body.fromString("""{"error":"Invalid credentials"}""")))
        case ex                                      =>
          ZIO.logError(s"Login error: ${ex.toString}") *>
            ZIO.succeed(
              Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
            )
      }
    }
  )
