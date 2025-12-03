package com.shevchyk.app

import com.shevchyk.service.{UserService, OrderService, RideService, AuthService, FlightService}
import com.shevchyk.domain.{Ride, LoginRequest}
import zio.*
import zio.http.*
import zio.http.Header.*
import zio.http.codec.*
import zio.json.*

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
      handler(Response.text("Hello World!").addHeaders(corsHeaders)),

    // Auth endpoints
    Method.POST / "api" / "auth" / "login"     ->
      handler { (req: Request) =>
        (for
          body        <- req.body.asString
          loginReq    <- ZIO.fromEither(body.fromJson[LoginRequest])
          authService <- ZIO.service[AuthService]
          loginResp   <- authService.login(loginReq)
        yield loginResp match
          case Some(resp) => Response.json(resp.toJson).status(Status.Ok)
          case None       => Response.status(Status.Unauthorized)
        )
          .catchAll(_ => ZIO.succeed(Response.badRequest("Invalid login data")))
      },
    Method.GET / "api" / "auth" / "me"         ->
      handler { (req: Request) =>
        (for
          authHeader  <- ZIO
                           .fromOption(req.headers.get("Authorization"))
                           .orElse(ZIO.fail("Missing Authorization header"))
          token       <- ZIO.succeed(authHeader.stripPrefix("Bearer "))
          authService <- ZIO.service[AuthService]
          person      <- authService.validateToken(token)
        yield person match
          case Some(p) => Response.json(p.toJson).status(Status.Ok)
          case None    => Response.status(Status.Unauthorized)
        )
          .catchAll(_ => ZIO.succeed(Response.status(Status.Unauthorized)))
      },
    Method.GET / "api" / "persons"             ->
      handler {
        (for
          authService <- ZIO.service[AuthService]
          persons     <- authService.getAllPersons
        yield Response.json(persons.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "users"               ->
      handler {
        (for
          userService <- ZIO.service[UserService]
          users       <- userService.getAllUsers
        yield Response.json(users.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "users" / long("id")  ->
      handler { (id: Long, req: Request) =>
        (for
          userService <- ZIO.service[UserService]
          user        <- userService.getUserById(id)
        yield user match
          case Some(u) => Response.json(u.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "orders"              ->
      handler {
        (for
          orderService <- ZIO.service[OrderService]
          orders       <- orderService.getAllOrders
        yield Response.json(orders.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "orders" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          orderService <- ZIO.service[OrderService]
          order        <- orderService.getOrderById(id)
        yield order match
          case Some(o) => Response.json(o.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },

    // Ride endpoints
    Method.GET / "api" / "rides"                 ->
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
    Method.GET / "api" / "rides" / "all"         ->
      handler {
        (for
          rideService <- ZIO.service[RideService]
          rides       <- rideService.getAllRides
        yield Response.json(rides.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "rides" / long("id")    ->
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
    Method.POST / "api" / "rides"                ->
      handler { (req: Request) =>
        (for
          body        <- req.body.asString
          rideData    <- ZIO.fromEither(body.fromJson[Ride])
          rideService <- ZIO.service[RideService]
          newRide     <- rideService.createRide(rideData)
        yield Response.json(newRide.toJson).status(Status.Created))
          .catchAll(_ => ZIO.succeed(Response.badRequest("Invalid ride data")))
      },
    Method.PUT / "api" / "rides" / long("id")    ->
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
      },

    // Flight endpoints for Munich Airport
    Method.GET / "api" / "flights" / "munich" / "arrivals"   ->
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
