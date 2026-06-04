package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*

object RouteHelpers:

  def authHandler[R](context: String)(
      f: (AuthenticatedUser, Request) => ZIO[R, Any, Response]
  ): Handler[R & JwtService, Response, Request, Response] = handler { (request: Request) =>
    AuthMiddleware
      .authenticateRequest(request)
      .flatMap(user => f(user, request))
      .catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => RouteErrorHandler.handleError(context)(ex)
      }
  }

  def authPathHandler[R, P](context: String)(
      f: (AuthenticatedUser, P, Request) => ZIO[R, Any, Response]
  ): Handler[R & JwtService, Response, (P, Request), Response] = handler { (param: P, request: Request) =>
    AuthMiddleware
      .authenticateRequest(request)
      .flatMap(user => f(user, param, request))
      .catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => RouteErrorHandler.handleError(context)(ex)
      }
  }
