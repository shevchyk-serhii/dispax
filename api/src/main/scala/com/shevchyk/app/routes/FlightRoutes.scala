package com.shevchyk.app.routes

import com.shevchyk.service.FlightService
import zio.*
import zio.http.*
import zio.http.Header.*
import zio.json.*

object FlightRoutes {
  
  // CORS headers для flight endpoints
  val corsHeaders = Headers(
    Header.AccessControlAllowOrigin.All,
    Header.AccessControlAllowMethods(Method.GET, Method.POST, Method.PUT, Method.DELETE, Method.OPTIONS),
    Header.AccessControlAllowHeaders("Authorization", "Content-Type", "Accept"),
    Header.Custom("Access-Control-Allow-Credentials", "true")
  )
  
  val routes = Routes(
    // Flight endpoints for Munich Airport
    Method.GET / "api" / "flights" / "munich" / "arrivals" ->
      handler { (req: Request) =>
        val beginTime = req.url.queryParams
          .getAll("begin")
          .headOption
          .map(_.toLong)
          .getOrElse(java.lang.System.currentTimeMillis() / 1000 - 3600)
        val endTime   = req.url.queryParams
          .getAll("end")
          .headOption
          .map(_.toLong)
          .getOrElse(java.lang.System.currentTimeMillis() / 1000)
        (for
          flightService <- ZIO.service[FlightService]
          flights       <- flightService.getMunichArrivals(beginTime, endTime)
        yield Response.json(flights.toJson).addHeaders(corsHeaders))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "flights" / "munich" / "departures" ->
      handler { (req: Request) =>
        val beginTime = req.url.queryParams
          .getAll("begin")
          .headOption
          .map(_.toLong)
          .getOrElse(java.lang.System.currentTimeMillis() / 1000 - 3600)
        val endTime   = req.url.queryParams
          .getAll("end")
          .headOption
          .map(_.toLong)
          .getOrElse(java.lang.System.currentTimeMillis() / 1000)
        (for
          flightService <- ZIO.service[FlightService]
          flights       <- flightService.getMunichDepartures(beginTime, endTime)
        yield Response.json(flights.toJson).addHeaders(corsHeaders))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      }
  )
}