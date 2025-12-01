package com.shevchyk

import com.shevchyk.app.AppRoutes
import com.shevchyk.service.{UserService, OrderService}
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = 
    Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  def run: ZIO[Any, Throwable, Nothing] = 
    (ZIO.logInfo("Starting the server...") *>
    ZIO.logInfo("Server started") *>
    Server.serve(AppRoutes.routes))
      .provide(
        Server.default,
        UserService.live,
        OrderService.live
      )
