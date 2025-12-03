package com.shevchyk.app.routes

import com.shevchyk.service.{AuthService, RideService}
import com.shevchyk.domain.Ride
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {

  val routes = Routes(
    // Ride endpoints
    Method.GET / "api" / "rides"                 ->
      authEndpoint { req =>
        for
          token       <- extractAuthToken(req)
          authService <- ZIO.service[AuthService]
          user        <- authService.validateToken(token).flatMap {
                           case Some(u) => ZIO.succeed(u)
                           case None    => ZIO.fail("Invalid token")
                         }
          rideService <- ZIO.service[RideService]
          rides       <- rideService.getRidesForUser(user)
        yield jsonResponse(rides)
      },
    Method.GET / "api" / "rides" / "all"         ->
      safeEndpoint {
        for
          rideService <- ZIO.service[RideService]
          rides       <- rideService.getAllRides
        yield jsonResponse(rides)
      },
    Method.GET / "api" / "rides" / long("id")    ->
      endpointWithParams { (id: Long, req: Request) =>
        for
          rideService <- ZIO.service[RideService]
          ride        <- rideService.getRideById(id)
        yield handleOptionalResult(ride)
      },
    Method.POST / "api" / "rides"                ->
      badRequestEndpoint("Invalid ride data") { req =>
        for
          body        <- req.body.asString
          rideData    <- ZIO.fromEither(body.fromJson[Ride])
          rideService <- ZIO.service[RideService]
          newRide     <- rideService.createRide(rideData)
        yield jsonResponseWithStatus(newRide, Status.Created)
      },
    Method.PUT / "api" / "rides" / long("id")    ->
      badRequestEndpointWithParams("Invalid ride data") { (id: Long, req: Request) =>
        for
          body        <- req.body.asString
          rideData    <- ZIO.fromEither(body.fromJson[Ride])
          rideService <- ZIO.service[RideService]
          updatedRide <- rideService.updateRide(id, rideData)
        yield handleOptionalResult(updatedRide)
      },
    Method.DELETE / "api" / "rides" / long("id") ->
      endpointWithParams { (id: Long, req: Request) =>
        for
          rideService <- ZIO.service[RideService]
          deleted     <- rideService.deleteRide(id)
        yield
          if (deleted)
            Response.status(Status.NoContent)
          else
            Response.status(Status.NotFound)
      }
  )
}
