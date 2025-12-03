package com.shevchyk.app

import com.shevchyk.app.routes.{AuthRoutes, UserRoutes, RideRoutes, FlightRoutes}
import zio.http.*
import zio.http.Header.*

object AppRoutes {

  // CORS headers
  val corsHeaders = Headers(
    Header.AccessControlAllowOrigin.All,
    Header.AccessControlAllowMethods(Method.GET, Method.POST, Method.PUT, Method.DELETE, Method.OPTIONS),
    Header.AccessControlAllowHeaders("Authorization", "Content-Type", "Accept"),
    Header.Custom("Access-Control-Allow-Credentials", "true")
  )

  val routes = Routes(
    Method.OPTIONS / trailing ->
      handler(Response.status(Status.Ok).addHeaders(corsHeaders)),
    Method.GET / "hello"      ->
      handler(Response.text("Hello World!").addHeaders(corsHeaders))
  ) ++ AuthRoutes.routes ++ UserRoutes.routes ++ RideRoutes.routes ++ FlightRoutes.routes
}
