package com.shevchyk.app.routes

import com.shevchyk.application.service.RideFacade
import com.shevchyk.application.errors.RideError
import com.shevchyk.domain.model.*
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object SimpleRideRoutes {

  val routes = Routes(
    Method.GET / "api" / "v2" / "rides" / long("id") ->
      endpointWithParams { (id: Long, req: Request) =>
        (for
          rideFacade <- ZIO.service[RideFacade]
          ride       <- rideFacade.getRideById(RideId(id))
        yield jsonResponse(ride))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      },
    Method.POST / "api" / "v2" / "rides"             ->
      safeEndpoint((req: Request) =>
        (for
          body          <- req.body.asString
          createRequest <- ZIO
                             .fromEither(body.fromJson[CreateRideRequest])
                             .mapError(err => RideError.ValidationError(s"Invalid request format: $err"))
          rideFacade    <- ZIO.service[RideFacade]
          newRide       <- rideFacade.createRide(createRequest)
        yield jsonResponseWithStatus(newRide, Status.Created))
          .catchAll {
            case rideError: RideError => ZIO.succeed(errorResponse(rideError))
            case other: Throwable     => ZIO.succeed(errorResponse(RideError.ValidationError(other.getMessage)))
          }
      )
  )

  private def errorResponse(error: Throwable): Response =
    error match {
      case RideError.ValidationError(message)                                                    => Response.json(s"""{"error": "$message"}""").status(Status.BadRequest)
      case RideError.NoDriversAvailable(location)                                                =>
        Response.json(s"""{"error": "No available drivers near $location"}""").status(Status.ServiceUnavailable)
      case RideError.RideNotFound(_) | RideError.PersonNotFound(_) | RideError.DriverNotFound(_) =>
        Response.json(s"""{"error": "Resource not found"}""").status(Status.NotFound)
      case RideError.UnauthorizedAccess(_, _)                                                    =>
        Response.json(s"""{"error": "Unauthorized access"}""").status(Status.Forbidden)
      case RideError.InvalidStatusTransition(from, to)                                           =>
        Response.json(s"""{"error": "Cannot transition from $from to $to"}""").status(Status.Conflict)
      case RideError.RideAlreadyAssigned(_, _)                                                   =>
        Response.json(s"""{"error": "Ride is already assigned"}""").status(Status.Conflict)
      case RideError.DatabaseError(_)                                                            =>
        Response.json(s"""{"error": "Internal server error"}""").status(Status.InternalServerError)
      case RideError.ExternalServiceError(service, _)                                            =>
        Response.json(s"""{"error": "$service temporarily unavailable"}""").status(Status.ServiceUnavailable)
      case RideError.BusinessRuleViolation(rule, message)                                        =>
        Response.json(s"""{"error": "Business rule violation: $message"}""").status(Status.BadRequest)
      case RideError.TariffNotFound(_)                                                           =>
        Response.json(s"""{"error": "Pricing information not available"}""").status(Status.ServiceUnavailable)
      case other                                                                                 => Response.json(s"""{"error": "Unexpected error occurred"}""").status(Status.InternalServerError)
    }
}
