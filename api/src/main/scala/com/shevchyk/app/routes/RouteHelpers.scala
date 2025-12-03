package com.shevchyk.app.routes

import zio.*
import zio.http.*
import zio.json.*

object RouteHelpers {

  // Обработка ошибок для разных типов операций
  def handleInternalError: Any => UIO[Response] = _ => ZIO.succeed(Response.internalServerError)

  def handleBadRequest(message: String): Any => UIO[Response] = _ => ZIO.succeed(Response.badRequest(message))

  def handleUnauthorized: Any => UIO[Response] = _ => ZIO.succeed(Response.status(Status.Unauthorized))

  // Helper для обработки Optional результатов
  def handleOptionalResult[T: JsonEncoder](result: Option[T]): Response =
    result match
      case Some(value) => Response.json(value.toJson)
      case None        => Response.status(Status.NotFound)

  // Helper для JSON ответов с коллекциями
  def jsonResponse[T: JsonEncoder](data: T): Response = Response.json(data.toJson)

  def jsonResponseWithStatus[T: JsonEncoder](data: T, status: Status): Response = Response
    .json(data.toJson)
    .status(status)

  // Helper для извлечения Authorization token
  def extractAuthToken(req: Request): IO[String, String] =
    for
      authHeader <- ZIO
                      .fromOption(req.headers.get("Authorization"))
                      .orElse(ZIO.fail("Missing Authorization header"))
      token      <- ZIO.succeed(authHeader.stripPrefix("Bearer "))
    yield token

  // Helper для query параметров
  def getQueryParam(req: Request, param: String): Option[String] = req.url.queryParams.getAll(param).headOption

  def getQueryParamAsLong(req: Request, param: String, default: Long): Long = getQueryParam(req, param)
    .map(_.toLong)
    .getOrElse(default)

  // Универсальные endpoint builders
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

  // Для основных app роутов
  def appEndpoint[R](
      logic: ZIO[R, Any, Response]
  ): Handler[R, Nothing, Request, Response] = safeEndpoint(logic)

  def endpointWithParams[T, R](
      logic: (T, Request) => ZIO[R, Any, Response]
  ): Handler[R, Nothing, (T, Request), Response] = handler { (params: T, req: Request) =>
    logic(params, req).catchAll(handleInternalError)
  }

  // Специализированные endpoint builders
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
