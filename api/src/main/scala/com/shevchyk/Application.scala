package com.shevchyk

import com.shevchyk.app.AppRoutes
import com.shevchyk.service.{UserService, OrderService, RideService, AuthService, FlightService}
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J
import java.net.InetSocketAddress

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("Starting the server on port 8080...") *>
      ZIO.logInfo("Server will bind to default interface") *>
      Server.serve(AppRoutes.routes @@ Middleware.addHeaders(AppRoutes.corsHeaders)))
      .provide(
        Server.default,
        UserService.live,
        OrderService.live,
        RideService.layer,
        AuthService.layer,
        FlightService.live
      )
