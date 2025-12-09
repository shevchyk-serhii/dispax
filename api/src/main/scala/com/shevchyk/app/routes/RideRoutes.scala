package com.shevchyk.app.routes

import com.shevchyk.service.{AuthService, RideService}
import com.shevchyk.domain.Ride
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {

  val routes = Routes(
    Method.GET / "api" / "rides"                 ->
      authEndpoint { req =>
        for
          token         <- extractAuthToken(req)
          authService   <- ZIO.service[AuthService]
          user          <- authService.validateToken(token).flatMap {
                             case Some(u) => ZIO.succeed(u)
                             case None    => ZIO.fail("Invalid token")
                           }
          rideService   <- ZIO.service[RideService]
          rides         <- rideService.getRidesForUser(user)
          enrichedRides <- ZIO.foreach(rides)(rideService.enrichWithFlightInfo)
        yield jsonResponse(enrichedRides)
      },
    Method.GET / "api" / "rides" / "all"         ->
      safeEndpoint {
        for
          rideService   <- ZIO.service[RideService]
          rides         <- rideService.getAllRides
          enrichedRides <- ZIO.foreach(rides)(rideService.enrichWithFlightInfo)
        yield jsonResponse(enrichedRides)
      },
    Method.GET / "api" / "rides" / long("id")    ->
      endpointWithParams { (id: Long, req: Request) =>
        for
          rideService  <- ZIO.service[RideService]
          ride         <- rideService.getRideById(id)
          enrichedRide <-
            ride match {
              case Some(r) => rideService.enrichWithFlightInfo(r).map(Some(_))
              case None    => ZIO.succeed(None)
            }
        yield handleOptionalResult(enrichedRide)
      },
    Method.POST / "api" / "rides"                ->
      badRequestEndpoint("Invalid ride data") { req =>
        for
          body         <- req.body.asString
          rideData     <- ZIO.fromEither(body.fromJson[Ride])
          rideService  <- ZIO.service[RideService]
          newRide      <- rideService.createRide(rideData)
          enrichedRide <- rideService.enrichWithFlightInfo(newRide)
        yield jsonResponseWithStatus(enrichedRide, Status.Created)
      },
    Method.PUT / "api" / "rides" / long("id")    ->
      badRequestEndpointWithParams("Invalid ride data") { (id: Long, req: Request) =>
        for
          body         <- req.body.asString
          rideData     <- ZIO.fromEither(body.fromJson[Ride])
          rideService  <- ZIO.service[RideService]
          updatedRide  <- rideService.updateRide(id, rideData)
          enrichedRide <-
            updatedRide match {
              case Some(r) => rideService.enrichWithFlightInfo(r).map(Some(_))
              case None    => ZIO.succeed(None)
            }
        yield handleOptionalResult(enrichedRide)
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
