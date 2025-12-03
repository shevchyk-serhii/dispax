package com.shevchyk.app

import com.shevchyk.app.routes.{AuthRoutes, UserRoutes, RideRoutes, FlightRoutes, RouteHelpers}
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.http.Header.*

object AppRoutes {

  val corsHeaders = Headers(
    Header.AccessControlAllowOrigin.All,
    Header.AccessControlAllowMethods(Method.GET, Method.POST, Method.PUT, Method.DELETE, Method.OPTIONS),
    Header.AccessControlAllowHeaders("Authorization", "Content-Type", "Accept"),
    Header.Custom("Access-Control-Allow-Credentials", "true")
  )

  val routes =
    Routes(
      Method.OPTIONS / trailing ->
        appEndpoint(ZIO.succeed(Response.status(Status.Ok).addHeaders(corsHeaders))),
      Method.GET / "hello"      ->
        appEndpoint(ZIO.succeed(Response.text("Hello World!").addHeaders(corsHeaders)))
    ) ++ AuthRoutes.routes ++ UserRoutes.routes ++ RideRoutes.routes ++ FlightRoutes.routes
}
