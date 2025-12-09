package com.shevchyk.ride.infrastructure.http

import com.shevchyk.core.domain.RideId
import com.shevchyk.ride.application.service.{RideFacade, SimpleRideService}
import com.shevchyk.ride.domain.{RideError, CreateRideRequest, UpdateRideStatusRequest}
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {

  val routes = Routes(
    Method.GET / "api" / "v2" / "health" -> handler { (_: Request) =>
      ZIO.succeed(Response.text("Ride service is healthy"))
    }
  )
}
