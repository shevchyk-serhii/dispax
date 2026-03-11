package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.ride.application.service.{RideService, ClientLocationService, ChatService}
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

  private def handleRideError(ex: Throwable): UIO[Response] =
    ex match
      case RideError.ValidationError(msg)              =>
        val userMsg = s"Validation error: $msg"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.RideNotFound(id)                  =>
        val userMsg = s"Ride not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.PersonNotFound(id)                =>
        val userMsg = s"Person not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.DriverNotFound(id)                =>
        val userMsg = s"Driver not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.UnauthorizedAccess(_, _)          =>
        ZIO
          .logError(s"Ride error: Access denied")
          .as(Response(Status.Forbidden, body = Body.fromString(s"""{"error":"Access denied"}""")))
      case RideError.InvalidStatusTransition(from, to) =>
        val userMsg = s"Cannot transition from $from to $to"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.Conflict, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.RideAlreadyAssigned(_, _)         =>
        ZIO
          .logError(s"Ride error: Ride already assigned")
          .as(Response(Status.Conflict, body = Body.fromString(s"""{"error":"Ride already assigned"}""")))
      case RideError.BusinessRuleViolation(_, msg)     =>
        ZIO
          .logError(s"Ride error: $msg")
          .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$msg"}""")))
      case other                                       =>
        ZIO
          .logError(s"Unhandled error: ${Option(other.getMessage).getOrElse(other.toString)}")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )

  private def toPersonRole(role: String): PersonRole =
    role match
      case "DRIVER"     => PersonRole.Driver
      case "CLIENT"     => PersonRole.Client
      case "SECRETARY"  => PersonRole.Secretary
      case "DISPATCHER" => PersonRole.Dispatcher
      case _            => PersonRole.Client

  val authenticatedRoutes: Routes[RideService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides"                                       -> authenticatedJsonHandler[RideService, CreateRideApiRequest] { (user, apiRequest) =>
      (for {
        _            <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "CLIENT", "DRIVER")
        _            <-
          ZIO.when(user.companyId.isEmpty)(
            ZIO.fail(RideError.ValidationError("User must belong to a company to create rides"))
          )
        validRequest <- apiRequest.validate
        domainRequest = CreateRideApiRequest
                          .toDomain(validRequest, CompanyId(user.companyId.get))
                          .copy(clientId = PersonId(user.userId))
        service      <- ZIO.service[RideService]
        ride         <- service.createRide(domainRequest)
        rideDto       = RideDto.fromDomain(ride)
      } yield Response(Status.Created, body = Body.fromString(rideDto.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.GET / "api" / "rides" / "pending"                            -> authenticatedHandler[RideService] { (user, _) =>
      (for {
        _       <- AuthMiddleware.checkRole(user, "DISPATCHER")
        service <- ZIO.service[RideService]
        rides   <- service.getRidesByStatus(RideStatus.Requested)
        rideDtos = rides.map(RideDto.fromDomain)
      } yield Response.json(rideDtos.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.GET / "api" / "rides" / "driver" / string("driverId")        -> handler { (driverId: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRoleOrOwner(user, UUID.fromString(driverId), "DISPATCHER")
        service <- ZIO.service[RideService]
        rides   <- service.getDriverRides(PersonId(UUID.fromString(driverId)))
        rideDtos = rides.map(RideDto.fromDomain)
      } yield Response.json(rideDtos.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.PUT / "api" / "rides" / string("rideId") / "status"          -> handler { (rideId: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER")
        bodyStr    <- request.body.asString
        apiRequest <- ZIO
                        .fromEither(bodyStr.fromJson[RideStatusUpdateRequest])
                        .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        validated  <- apiRequest.validate
        service    <- ZIO.service[RideService]
        ride       <- service.updateRideStatus(
                        RideId(UUID.fromString(rideId)),
                        UpdateRideStatusRequest(RideStatus.valueOf(validated.status)),
                        PersonId(user.userId),
                        toPersonRole(user.role)
                      )
        rideDto     = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.PUT / "api" / "rides" / string("rideId") / "assign-driver"   -> handler { (rideId: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
        bodyStr    <- request.body.asString
        apiRequest <- ZIO
                        .fromEither(bodyStr.fromJson[AssignDriverRequest])
                        .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        validated  <- apiRequest.validate
        service    <- ZIO.service[RideService]
        ride       <- service.assignDriver(RideId(UUID.fromString(rideId)), PersonId(UUID.fromString(validated.driverId)))
        rideDto     = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.PUT / "api" / "rides" / string("rideId") / "reassign-driver" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr    <- request.body.asString
          apiRequest <- ZIO
                          .fromEither(bodyStr.fromJson[AssignDriverRequest])
                          .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          validated  <- apiRequest.validate
          service    <- ZIO.service[RideService]
          ride       <- service.reassignDriver(RideId(UUID.fromString(rideId)), PersonId(UUID.fromString(validated.driverId)))
          rideDto     = RideDto.fromDomain(ride)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
    },
    Method.PUT / "api" / "rides" / string("rideId")                     -> handler { (rideId: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER", "SECRETARY")
        bodyStr    <- request.body.asString
        apiRequest <- ZIO
                        .fromEither(bodyStr.fromJson[UpdateRideDetailsApiRequest])
                        .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        service    <- ZIO.service[RideService]
        ride       <- service.updateRideDetails(
                        RideId(UUID.fromString(rideId)),
                        UpdateRideDetailsApiRequest.toDomain(apiRequest),
                        PersonId(user.userId),
                        toPersonRole(user.role)
                      )
        rideDto     = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.GET / "api" / "rides" / string("rideId")                     -> handler { (rideId: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY")
        service <- ZIO.service[RideService]
        ride    <- service.getRideById(RideId(UUID.fromString(rideId)))
        _       <-
          ZIO.when(user.companyId.nonEmpty && ride.companyId.value != user.companyId.get)(
            ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), RideId(UUID.fromString(rideId))))
          )
        rideDto  = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.POST / "api" / "rides" / string("rideId") / "airport-timing" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user        <- AuthMiddleware.authenticateRequest(request)
          _           <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
          service     <- ZIO.service[RideService]
          ride        <- service.getRideById(RideId(UUID.fromString(rideId)))
          _           <-
            ZIO.when(user.companyId.nonEmpty && ride.companyId.value != user.companyId.get)(
              ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), RideId(UUID.fromString(rideId))))
            )
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
          response     =
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
          case ex: Throwable      => handleRideError(ex)
        }
    },
    Method.GET / "api" / "rides"                                        -> authenticatedHandler[RideService] { (user, _) =>
      for {
        service <- ZIO.service[RideService]
        rides   <- service.getRidesForUser(PersonId(user.userId))
        rideDtos = rides.map(RideDto.fromDomain)
      } yield Response.json(rideDtos.toJson)
    }
  )

  val clientLocationRoutes: Routes[ClientLocationService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides" / string("rideId") / "client-location" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          _       <- AuthMiddleware.checkRole(user, "CLIENT")
          bodyStr <- request.body.asString
          locReq  <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateClientLocationRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          service <- ZIO.service[ClientLocationService]
          _       <- service.updateClientLocation(
                       RideId(UUID.fromString(rideId)),
                       PersonId(user.userId),
                       locReq.latitude,
                       locReq.longitude
                     )
        } yield Response(Status.NoContent)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
    },
    Method.GET / "api" / "rides" / string("rideId") / "locations"        -> handler { (rideId: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        service   <- ZIO.service[ClientLocationService]
        locations <- service.getRideLocations(RideId(UUID.fromString(rideId)))
      } yield Response.json(locations.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    }
  )

  val chatRoutes: Routes[ChatService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides" / string("rideId") / "chat" -> handler { (rideId: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER")
        bodyStr <- request.body.asString
        chatReq <- ZIO
                     .fromEither(bodyStr.fromJson[SendChatMessageRequest])
                     .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        service <- ZIO.service[ChatService]
        msg     <- service.sendMessage(
                     RideId(UUID.fromString(rideId)),
                     PersonId(user.userId),
                     chatReq.message
                   )
      } yield Response(Status.Created, body = Body.fromString(msg.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.GET / "api" / "rides" / string("rideId") / "chat"  -> handler { (rideId: String, request: Request) =>
      (for {
        user     <- AuthMiddleware.authenticateRequest(request)
        _        <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        service  <- ZIO.service[ChatService]
        messages <- service.getMessages(RideId(UUID.fromString(rideId)))
      } yield Response.json(messages.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    }
  )

  val routes: Routes[Any, Response] = MockRideRoutes.routes

  val routesWithPersonRepo: Routes[PersonRepository, Response] = MockRideRoutes.routes
}
