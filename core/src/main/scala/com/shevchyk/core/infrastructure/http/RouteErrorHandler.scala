package com.shevchyk.core.infrastructure.http

import zio.*
import zio.http.*

object RouteErrorHandler:

  def handleError(context: String)(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"$context error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString("""{"error":"Internal server error"}""")))
