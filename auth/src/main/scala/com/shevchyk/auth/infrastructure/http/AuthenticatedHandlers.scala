package com.shevchyk.auth.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.http.*
import zio.json.*

/**
 * Helper utilities for creating authenticated HTTP handlers. These handlers automatically extract and validate JWT
 * tokens from requests.
 */
/**
 * Sentinel exception used to distinguish a malformed request body from an unexpected server-side error, so we can
 * return 400 instead of 500.
 */
final private class InvalidJsonBodyError(msg: String) extends RuntimeException(msg)

object AuthenticatedHandlers {

  /**
   * Creates an authenticated handler that extracts the user from JWT token.
   *
   * @param f
   *   Business logic function that receives AuthenticatedUser and Request
   * @tparam R
   *   Environment required by the business logic (will be combined with JwtService)
   * @return
   *   Handler that handles authentication and executes business logic
   *
   * @example
   *   {{{
   * Method.GET / "api" / "profile" -> authenticatedHandler { (user, request) =>
   *   for {
   *     service <- ZIO.service[UserService]
   *     profile <- service.getProfile(user.userId)
   *   } yield Response.json(profile.toJson)
   * }
   *   }}}
   */
  def authenticatedHandler[R](
      f: (AuthenticatedUser, Request) => ZIO[R, Throwable, Response]
  ): Handler[R & JwtService, Response, Request, Response] = handler { (request: Request) =>
    (for {
      user   <- AuthMiddleware.authenticateRequest(request)
      result <- f(user, request)
    } yield result).catchAll {
      case response: Response => ZIO.succeed(response) // Auth errors return Response directly
      case ex: Throwable      =>
        ZIO
          .logError(s"Unhandled error: ${ex.getMessage}")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )
    }
  }

  /**
   * Creates an authenticated handler with automatic JSON body parsing.
   *
   * @param f
   *   Business logic function that receives AuthenticatedUser and parsed JSON object
   * @tparam R
   *   Environment required by the business logic (will be combined with JwtService)
   * @tparam T
   *   Type of JSON body to parse
   * @return
   *   Handler that handles authentication, JSON parsing, and executes business logic
   *
   * @example
   *   {{{
   * Method.POST / "api" / "orders" -> authenticatedJsonHandler[CreateOrderRequest] { (user, orderReq) =>
   *   for {
   *     service <- ZIO.service[OrderService]
   *     order   <- service.createOrder(user.userId, orderReq)
   *   } yield Response(Status.Created, body = Body.fromString(order.toJson))
   * }
   *   }}}
   */
  def authenticatedJsonHandler[R, T: JsonDecoder](
      f: (AuthenticatedUser, T) => ZIO[R, Throwable, Response]
  ): Handler[R & JwtService, Response, Request, Response] = handler { (request: Request) =>
    (for {
      user    <- AuthMiddleware.authenticateRequest(request)
      bodyStr <- request.body.asString
      parsed  <- ZIO
                   .fromEither(bodyStr.fromJson[T])
                   .mapError(err => InvalidJsonBodyError(s"Invalid JSON format: $err"))
      result  <- f(user, parsed)
    } yield result).catchAll {
      case response: Response      => ZIO.succeed(response) // Auth errors return Response directly
      case e: InvalidJsonBodyError =>
        ZIO
          .logWarning(s"Invalid JSON body: ${e.getMessage}")
          .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"Invalid JSON format"}""")))
      case ex: Throwable           =>
        ZIO
          .logError(s"Unhandled error: ${ex.getMessage}")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )
    }
  }

  /**
   * Creates an authenticated handler for path parameters with automatic extraction.
   *
   * @param f
   *   Business logic function that receives AuthenticatedUser, path parameter, and Request
   * @tparam R
   *   Environment required by the business logic
   * @tparam P
   *   Type of path parameter
   * @return
   *   Handler that handles authentication and path parameter extraction
   *
   * @example
   *   {{{
   * Method.GET / "api" / "orders" / string("orderId") -> authenticatedPathHandler { (user, orderId, request) =>
   *   for {
   *     service <- ZIO.service[OrderService]
   *     order   <- service.getOrder(user.userId, orderId)
   *   } yield Response.json(order.toJson)
   * }
   *   }}}
   */
  def authenticatedPathHandler[R, P](
      f: (AuthenticatedUser, P, Request) => ZIO[R, Throwable, Response]
  ): Handler[R & JwtService, Response, (P, Request), Response] = handler { (param: P, request: Request) =>
    (for {
      user   <- AuthMiddleware.authenticateRequest(request)
      result <- f(user, param, request)
    } yield result).catchAll {
      case response: Response => ZIO.succeed(response)
      case ex: Throwable      =>
        ZIO
          .logError(s"Unhandled error: ${ex.getMessage}")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )
    }
  }
}
