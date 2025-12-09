package com.shevchyk.app.routes

import zio.*
import zio.http.*
import zio.json.*

object RouteHelpers {

  
  def handleInternalError: Any => UIO[Response] = _ => ZIO.succeed(Response.internalServerError)

  def handleBadRequest(message: String): Any => UIO[Response] = _ => ZIO.succeed(Response.badRequest(message))

  def handleUnauthorized: Any => UIO[Response] = _ => ZIO.succeed(Response.status(Status.Unauthorized))

  
  def handleOptionalResult[T: JsonEncoder](result: Option[T]): Response =
    result match
      case Some(value) => Response.json(value.toJson)
      case None        => Response.status(Status.NotFound)

  
  def jsonResponse[T: JsonEncoder](data: T): Response = Response.json(data.toJson)

  def jsonResponseWithStatus[T: JsonEncoder](data: T, status: Status): Response = Response
    .json(data.toJson)
    .status(status)

  
  def extractAuthToken(req: Request): IO[String, String] =
    for
      authHeader <- ZIO
                      .fromOption(req.headers.get("Authorization"))
                      .orElse(ZIO.fail("Missing Authorization header"))
      token      <- ZIO.succeed(authHeader.stripPrefix("Bearer "))
    yield token

  
  def getQueryParam(req: Request, param: String): Option[String] = req.url.queryParams.getAll(param).headOption

  def getQueryParamAsLong(req: Request, param: String, default: Long): Long = getQueryParam(req, param)
    .map(_.toLong)
    .getOrElse(default)

  
  def safeEndpoint[R](
      logic: ZIO[R, Any, Response],
      errorHandler: Any => UIO[Response] = handleInternalError
  ): Handler[R, Nothing, Request, Response] = handler { (_: Request) =>
    logic.catchAll(errorHandler)
  }

  def safeEndpoint[R](
      logic: Request => ZIO[R, Any, Response]
  ): Handler[R, Nothing, Request, Response] = handler { (req: Request) =>
    logic(req).catchAll(handleInternalError)
  }

  
  def appEndpoint[R](
      logic: ZIO[R, Any, Response]
  ): Handler[R, Nothing, Request, Response] = safeEndpoint(logic)

  def endpointWithParams[T, R](
      logic: (T, Request) => ZIO[R, Any, Response]
  ): Handler[R, Nothing, (T, Request), Response] = handler { (params: T, req: Request) =>
    logic(params, req).catchAll(handleInternalError)
  }

  
  def authEndpoint[R](logic: Request => ZIO[R, Any, Response]): Handler[R, Nothing, Request, Response] = handler {
    (req: Request) =>
      logic(req).catchAll(handleUnauthorized)
  }

  def badRequestEndpoint[R](
      message: String
  )(logic: Request => ZIO[R, Any, Response]): Handler[R, Nothing, Request, Response] = handler { (req: Request) =>
    logic(req).catchAll(handleBadRequest(message))
  }

  def badRequestEndpointWithParams[T, R](message: String)(
      logic: (T, Request) => ZIO[R, Any, Response]
  ): Handler[R, Nothing, (T, Request), Response] = handler { (params: T, req: Request) =>
    logic(params, req).catchAll(handleBadRequest(message))
  }
}
