package com.shevchyk.app.routes

import com.shevchyk.service.{AuthService, RideService}
import com.shevchyk.domain.Ride
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {
  
  val routes = Routes(
    // Ride endpoints
    Method.GET / "api" / "rides" ->
      handler { (req: Request) =>
        (for
          authHeader  <- ZIO
                           .fromOption(req.headers.get("Authorization"))
                           .orElse(ZIO.fail("Missing Authorization header"))
          token       <- ZIO.succeed(authHeader.stripPrefix("Bearer "))
          authService <- ZIO.service[AuthService]
          user        <- authService.validateToken(token).flatMap {
                           case Some(u) => ZIO.succeed(u)
                           case None    => ZIO.fail("Invalid token")
                         }
          rideService <- ZIO.service[RideService]
          rides       <- rideService.getRidesForUser(user)
        yield Response.json(rides.toJson))
          .catchAll(_ => ZIO.succeed(Response.status(Status.Unauthorized)))
      },
    Method.GET / "api" / "rides" / "all" ->
      handler {
        (for
          rideService <- ZIO.service[RideService]
          rides       <- rideService.getAllRides
        yield Response.json(rides.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "rides" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          rideService <- ZIO.service[RideService]
          ride        <- rideService.getRideById(id)
        yield ride match
          case Some(r) => Response.json(r.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.POST / "api" / "rides" ->
      handler { (req: Request) =>
        (for
          body        <- req.body.asString
          rideData    <- ZIO.fromEither(body.fromJson[Ride])
          rideService <- ZIO.service[RideService]
          newRide     <- rideService.createRide(rideData)
        yield Response.json(newRide.toJson).status(Status.Created))
          .catchAll(_ => ZIO.succeed(Response.badRequest("Invalid ride data")))
      },
    Method.PUT / "api" / "rides" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          body        <- req.body.asString
          rideData    <- ZIO.fromEither(body.fromJson[Ride])
          rideService <- ZIO.service[RideService]
          updatedRide <- rideService.updateRide(id, rideData)
        yield updatedRide match
          case Some(r) => Response.json(r.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.badRequest("Invalid ride data")))
      },
    Method.DELETE / "api" / "rides" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          rideService <- ZIO.service[RideService]
          deleted     <- rideService.deleteRide(id)
        yield
          if (deleted)
            Response.status(Status.NoContent)
          else
            Response.status(Status.NotFound))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      }
  )
}