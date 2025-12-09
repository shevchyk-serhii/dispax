package com.shevchyk.app.routes

import com.shevchyk.service.FlightService
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.http.Header.*
import zio.json.*

object FlightRoutes {

  
  val corsHeaders = Headers(
    Header.AccessControlAllowOrigin.All,
    Header.AccessControlAllowMethods(Method.GET, Method.POST, Method.PUT, Method.DELETE, Method.OPTIONS),
    Header.AccessControlAllowHeaders("Authorization", "Content-Type", "Accept"),
    Header.Custom("Access-Control-Allow-Credentials", "true")
  )

  val routes = Routes(
    
    Method.GET / "api" / "flights" / "munich" / "arrivals"   ->
      safeEndpoint { req =>
        val beginTime = getQueryParamAsLong(req, "begin", java.lang.System.currentTimeMillis() / 1000 - 3600)
        val endTime   = getQueryParamAsLong(req, "end", java.lang.System.currentTimeMillis() / 1000)
        for
          flightService <- ZIO.service[FlightService]
          flights       <- flightService.getMunichArrivals(beginTime, endTime)
        yield jsonResponse(flights).addHeaders(corsHeaders)
      },
    Method.GET / "api" / "flights" / "munich" / "departures" ->
      safeEndpoint { req =>
        val beginTime = getQueryParamAsLong(req, "begin", java.lang.System.currentTimeMillis() / 1000 - 3600)
        val endTime   = getQueryParamAsLong(req, "end", java.lang.System.currentTimeMillis() / 1000)
        for
          flightService <- ZIO.service[FlightService]
          flights       <- flightService.getMunichDepartures(beginTime, endTime)
        yield jsonResponse(flights).addHeaders(corsHeaders)
      }
  )
}
