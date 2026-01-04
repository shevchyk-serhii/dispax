package com.shevchyk.ride.infrastructure.http

import com.shevchyk.TestDataGenerator
import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, RideId}
import com.shevchyk.ride.application.RideFacade
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{*, given}
import com.shevchyk.ride.validation.{Validator, given}
import com.shevchyk.ride.validation.Validator.validate
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

object RideRoutes {
  import com.shevchyk.repository.PersonRepository

  val authenticatedRoutes: Routes[RideFacade & JwtService, Response] = Routes(
    Method.POST / "api" / "rides"                                       -> authenticatedJsonHandler[RideFacade, CreateRideApiRequest] { (user, apiRequest) =>
      (for {
        _            <-
          ZIO.when(user.companyId.isEmpty)(
            ZIO.fail(RideError.ValidationError("User must belong to a company to create rides"))
          )
        validRequest <- apiRequest.validate

        domainRequest = CreateRideApiRequest
                          .toDomain(validRequest)
                          .copy(clientId = PersonId(user.userId))
        facade       <- ZIO.service[RideFacade]
        ride         <- facade.createRide(domainRequest)
        rideDto       = RideDto.fromDomain(ride)
      } yield Response(Status.Created, body = Body.fromString(rideDto.toJson)))
        .catchAll { ex =>
          val errorMsg =
            ex match {
              case RideError.ValidationError(msg) => s"Validation error: $msg"
              case RideError.PersonNotFound(id)   => s"Person not found: ${id.value}"
              case RideError.RideNotFound(id)     => s"Ride not found: ${id.value}"
              case other                          => Option(other.getMessage).getOrElse(other.toString)
            }
          ZIO
            .logError(s"Create ride error: $errorMsg")
            .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$errorMsg"}""")))
        }
    },
    Method.GET / "api" / "rides"                                        -> authenticatedHandler[RideFacade] { (user, _) =>
      for {
        facade  <- ZIO.service[RideFacade]
        rides   <- facade.getRidesForUser(PersonId(user.userId))
        rideDtos = rides.map(RideDto.fromDomain)
      } yield Response.json(rideDtos.toJson)
    },
    Method.GET / "api" / "rides" / string("rideId")                     -> handler { (rideId: String, request: Request) =>
      (for {
        user   <- AuthMiddleware.authenticateRequest(request)
        facade <- ZIO.service[RideFacade]
        ride   <- facade.getRideById(RideId(UUID.fromString(rideId)))
        rideDto = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      =>
          ZIO.succeed(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"${ex.getMessage}"}""")))
      }
    },
    Method.POST / "api" / "rides" / string("rideId") / "airport-timing" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user   <- AuthMiddleware.authenticateRequest(request)
          facade <- ZIO.service[RideFacade]
          ride   <- facade.getRideById(RideId(UUID.fromString(rideId)))

          now          = java.time.Instant.now()
          flightTime   = ride.scheduledTime.getOrElse(now.plusSeconds(7200))
          travelTime   = 45
          bufferTime   = 30
          totalTime    = travelTime + bufferTime
          optimalEntry = flightTime.minusSeconds(totalTime * 60)
          latestEntry  = flightTime.minusSeconds(bufferTime * 60)
          timeToDepart = java.time.Duration.between(now, optimalEntry).toMinutes.toInt
          optimalCost  = 12.50
          earlyCost    = 25.00
          savings      = earlyCost - optimalCost

          response =
            s"""{
          "optimalEntryTime": "${optimalEntry}",
          "latestEntryTime": "${latestEntry}",
          "travelTimeMinutes": $travelTime,
          "bufferTimeMinutes": $bufferTime,
          "optimalParkingCost": $optimalCost,
          "earlyEntryParkingCost": $earlyCost,
          "savings": $savings,
          "flightStatus": "On time",
          "timeToDepartMinutes": $timeToDepart
        }"""

        } yield Response.json(response)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      =>
            ZIO.succeed(Response(Status.NotFound, body = Body.fromString(s"""{"error":"${ex.getMessage}"}""")))
        }
    }
  )

  val routes: Routes[Any, Response] = MockRideRoutes.routes

  val routesWithPersonRepo: Routes[PersonRepository, Response] = MockRideRoutes.routes
}
