package com.shevchyk.auth.infrastructure.http

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.RateLimiter
import zio.*
import zio.http.*
import zio.json.*

object AuthRoutes:

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
      ZIO
        .logError(s"JSON parsing error: ${ex.toString}")
        .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"Invalid request format"}""")))
    }
  }

  val routes: Routes[AuthService & RateLimiter, Response] = Routes(
    Method.POST / "api" / "auth" / "login" -> handler { (req: Request) =>
      (for {
        rateLimiter   <- ZIO.service[RateLimiter]
        // Prefer remoteAddress to prevent X-Forwarded-For spoofing
        ip             = req.remoteAddress
                           .map(_.toString)
                           .getOrElse("unknown")
        allowed       <- rateLimiter.checkRate(ip)
        _             <-
          ZIO.when(!allowed)(
            ZIO.fail(
              Response(
                Status.TooManyRequests,
                body = Body.fromString("""{"error":"Too many requests. Please try again later."}""")
              )
            )
          )
        bodyStr       <- req.body.asString
        loginReq      <- ZIO
                           .fromEither(bodyStr.fromJson[LoginRequest])
                           .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        _             <- ZIO.logInfo(s"Login request received")
        authService   <- ZIO.service[AuthService]
        loginResponse <- authService.login(loginReq.email, loginReq.password)
      } yield Response.json(loginResponse.toJson)).catchAllCause { cause =>
        cause.failureOrCause match
          case Left(response: Response)                      => ZIO.succeed(response)
          case Left(_: UserNotFound | _: InvalidCredentials) =>
            ZIO.succeed(Response(Status.Unauthorized, body = Body.fromString("""{"error":"Invalid credentials"}""")))
          case Left(ex: Throwable)                           =>
            ZIO
              .logError(s"Login error: ${ex.getClass.getName}: ${ex.getMessage}")
              .as(
                Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
              )
          case Right(cause)                                  =>
            ZIO
              .logError(s"Login defect: ${cause.prettyPrint}")
              .as(
                Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
              )
      }
    }
  )
