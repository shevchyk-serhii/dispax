package com.shevchyk.app.routes

import com.shevchyk.application.service.{RideApplicationService, CreateRideRequest}
import com.shevchyk.application.errors.RideError
import com.shevchyk.domain.model.*
import com.shevchyk.service.AuthService
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object SimpleRideRoutes {

  val routes = Routes(
    Method.GET / "api" / "v2" / "rides"                            ->
      authEndpoint { req =>
        (for
          token         <- extractAuthToken(req)
          authService   <- ZIO.service[AuthService]
          user          <- authService.validateToken(token).flatMap {
                             case Some(u) => ZIO.succeed(u)
                             case None    => ZIO.fail("Invalid token")
                           }
          rideService   <- ZIO.service[RideApplicationService]
          rides         <- rideService.getRidesForUser(PersonId(user.id))
          enrichedRides <- ZIO.foreach(rides)(rideService.enrichRideWithFlightInfo)
        yield jsonResponse(enrichedRides))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.GET / "api" / "v2" / "rides" / long("id")               ->
      endpointWithParams { (id: Long, req: Request) =>
        (for
          rideService  <- ZIO.service[RideApplicationService]
          ride         <- rideService.getRideById(RideId(id))
          enrichedRide <- rideService.enrichRideWithFlightInfo(ride)
        yield jsonResponse(enrichedRide))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.POST / "api" / "v2" / "rides"                           ->
      authEndpoint { req =>
        (for
          token         <- extractAuthToken(req)
          authService   <- ZIO.service[AuthService]
          user          <- authService.validateToken(token).flatMap {
                             case Some(u) => ZIO.succeed(u)
                             case None    => ZIO.fail("Invalid token")
                           }
          body          <- req.body.asString
          createRequest <- ZIO
                             .fromEither(body.fromJson[CreateRideRequest])
                             .mapError(err => RideError.ValidationError(s"Invalid request format: $err"))
          rideService   <- ZIO.service[RideApplicationService]
          newRide       <- rideService.createRide(createRequest)
          enrichedRide  <- rideService.enrichRideWithFlightInfo(newRide)
        yield jsonResponseWithStatus(enrichedRide, Status.Created))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.POST / "api" / "v2" / "rides" / long("id") / "assign"   ->
      endpointWithParams { (id: Long, req: Request) =>
        (for
          rideId       <- ZIO.succeed(RideId(id))
          token        <- extractAuthToken(req)
          authService  <- ZIO.service[AuthService]
          user         <- authService.validateToken(token).flatMap {
                            case Some(u) => ZIO.succeed(u)
                            case None    => ZIO.fail("Invalid token")
                          }
          rideService  <- ZIO.service[RideApplicationService]
          assignedRide <- rideService.assignDriverToRide(rideId, PersonId(user.id))
        yield jsonResponse(assignedRide))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.POST / "api" / "v2" / "rides" / long("id") / "start"    ->
      endpointWithParams { (id: Long, req: Request) =>
        (for
          rideId      <- ZIO.succeed(RideId(id))
          token       <- extractAuthToken(req)
          authService <- ZIO.service[AuthService]
          user        <- authService.validateToken(token).flatMap {
                           case Some(u) => ZIO.succeed(u)
                           case None    => ZIO.fail("Invalid token")
                         }
          rideService <- ZIO.service[RideApplicationService]
          startedRide <- rideService.startRide(rideId, PersonId(user.id))
        yield jsonResponse(startedRide))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.POST / "api" / "v2" / "rides" / long("id") / "complete" ->
      endpointWithParams { (id: Long, req: Request) =>
        (for
          rideId        <- ZIO.succeed(RideId(id))
          token         <- extractAuthToken(req)
          authService   <- ZIO.service[AuthService]
          user          <- authService.validateToken(token).flatMap {
                             case Some(u) => ZIO.succeed(u)
                             case None    => ZIO.fail("Invalid token")
                           }
          rideService   <- ZIO.service[RideApplicationService]
          completedRide <- rideService.completeRide(rideId, PersonId(user.id))
        yield jsonResponse(completedRide))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      }
  )

  private def errorResponse(error: Throwable): Response =
    error match {
      case RideError.ValidationError(message) => Response.json(s"""{"error": "$message"}""").status(Status.BadRequest)

      case RideError.NoDriversAvailable(location) =>
        Response.json(s"""{"error": "No available drivers near $location"}""").status(Status.ServiceUnavailable)

      case RideError.RideNotFound(_) | RideError.PersonNotFound(_) | RideError.DriverNotFound(_) =>
        Response.json(s"""{"error": "Resource not found"}""").status(Status.NotFound)

      case RideError.UnauthorizedAccess(_, _) =>
        Response.json(s"""{"error": "Unauthorized access"}""").status(Status.Forbidden)

      case RideError.InvalidStatusTransition(from, to) =>
        Response.json(s"""{"error": "Cannot transition from $from to $to"}""").status(Status.Conflict)

      case RideError.RideAlreadyAssigned(_, _) =>
        Response.json(s"""{"error": "Ride is already assigned"}""").status(Status.Conflict)

      case RideError.DatabaseError(_) =>
        Response.json(s"""{"error": "Internal server error"}""").status(Status.InternalServerError)

      case RideError.ExternalServiceError(service, _) =>
        Response.json(s"""{"error": "$service temporarily unavailable"}""").status(Status.ServiceUnavailable)

      case RideError.BusinessRuleViolation(rule, message) =>
        Response.json(s"""{"error": "Business rule violation: $message"}""").status(Status.BadRequest)

      case RideError.TariffNotFound(_) =>
        Response.json(s"""{"error": "Pricing information not available"}""").status(Status.ServiceUnavailable)

      case other => Response.json(s"""{"error": "Unexpected error occurred"}""").status(Status.InternalServerError)
    }
}
