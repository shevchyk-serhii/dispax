package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.domain.{AuditAction, AuditLogEntry, AuditLogId, CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.ride.application.service.{RideService, ClientLocationService, ChatService, ClientAddressService}
import com.shevchyk.ride.repository.RideRatingRepository
import com.shevchyk.ride.domain.{RideRating, RideRatingId, CreateRatingRequest}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{*, given}
import com.shevchyk.ride.validation.{Validator, given}
import com.shevchyk.ride.validation.Validator.validate
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {
  import com.shevchyk.core.repository.PersonRepository

  private object AirportTimingConfig:
    val travelTimeMinutes: Int        = 45
    val bufferTimeMinutes: Int        = 30
    val optimalParkingCost: Double    = 12.50
    val earlyEntryParkingCost: Double = 25.00

  private def handleRideError(ex: Throwable): UIO[Response] =
    ex match
      case RideError.ValidationError(msg)               =>
        val userMsg = s"Validation error: $msg"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.RideNotFound(id)                   =>
        val userMsg = s"Ride not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.PersonNotFound(id)                 =>
        val userMsg = s"Person not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.DriverNotFound(id)                 =>
        val userMsg = s"Driver not found: ${id.value}"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.UnauthorizedAccess(userId, rideId) =>
        ZIO
          .logError(s"Ride error: Access denied for user=${userId.value} ride=${rideId.value}")
          .as(Response(Status.Forbidden, body = Body.fromString(s"""{"error":"Access denied"}""")))
      case RideError.InvalidStatusTransition(from, to)  =>
        val userMsg = s"Cannot transition from $from to $to"
        ZIO
          .logError(s"Ride error: $userMsg")
          .as(Response(Status.Conflict, body = Body.fromString(s"""{"error":"$userMsg"}""")))
      case RideError.RideAlreadyAssigned(_, _)          =>
        ZIO
          .logError(s"Ride error: Ride already assigned")
          .as(Response(Status.Conflict, body = Body.fromString(s"""{"error":"Ride already assigned"}""")))
      case RideError.BusinessRuleViolation(_, msg)      =>
        ZIO
          .logError(s"Ride error: $msg")
          .as(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$msg"}""")))
      case RideError.DatabaseError(cause)               =>
        val causeMsg = Option(cause.getMessage).getOrElse(cause.toString)
        ZIO
          .logError(s"Database error: $causeMsg")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )
      case other                                        =>
        val errorDetail = Option(other.getMessage).getOrElse(other.toString)
        val causeDetail = Option(other.getCause).map(c => s" caused by: ${c.getMessage}").getOrElse("")
        ZIO
          .logError(s"Unhandled error: $errorDetail$causeDetail")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )

  private def toPersonRole(role: String): PersonRole =
    role.toUpperCase match
      case "DRIVER"           => PersonRole.Driver
      case "CLIENT"           => PersonRole.Client
      case "SECRETARY"        => PersonRole.Secretary
      case "DISPATCHER"       => PersonRole.Dispatcher
      case "ADMIN"            => PersonRole.Admin
      case "CLIENT_SECRETARY" => PersonRole.ClientSecretary
      case _                  => PersonRole.Client

  val authenticatedRoutes: Routes[RideService & ClientAddressService & PersonRepository & JwtService, Response] =
    Routes(
      Method.POST / "api" / "rides"                                       -> authenticatedJsonHandler[
        RideService & ClientAddressService,
        CreateRideApiRequest
      ] { (user, apiRequest) =>
        (for {
          _             <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "CLIENT", "DRIVER", "CLIENT_SECRETARY")
          companyId     <- UuidParser.requireCompanyId(user.companyId)
          validRequest  <- apiRequest.validate
          domainRequest <- CreateRideApiRequest
                             .toDomain(validRequest, companyId)
                             .map { req =>
                               // Clients and drivers always create rides for themselves
                               // Secretaries, dispatchers and client_secretaries can specify a clientId from the request
                               if (user.role.toUpperCase == "CLIENT" || user.role.toUpperCase == "DRIVER")
                                 req.copy(clientId = PersonId(user.userId))
                               else
                                 req
                             }
          service       <- ZIO.service[RideService]
          ride          <- service.createRide(domainRequest)
          // Record from/to addresses for the client after successful ride creation
          addrService   <- ZIO.service[ClientAddressService]
          _             <-
            addrService
              .recordUsage(ride.clientId, ride.pickupLocation.address, "Pickup", None, None)
              .tapError(e => ZIO.logWarning(s"Failed to record from address: $e"))
              .ignore
          _             <-
            addrService
              .recordUsage(ride.clientId, ride.dropoffLocation.address, "Dropoff", None, None)
              .tapError(e => ZIO.logWarning(s"Failed to record to address: $e"))
              .ignore
          rideDto        = RideDto.fromDomain(ride)
        } yield Response(Status.Created, body = Body.fromString(rideDto.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides" / "pending"                            -> authenticatedHandler[RideService & PersonRepository] { (user, _) =>
        (for {
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          rides      <- service.getRidesByStatus(RideStatus.Requested)
          clientIds   = rides.map(_.clientId).distinct
          persons    <- ZIO.foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
          clientMap   = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
          rideDtos    = rides.map(r => RideDto.fromDomain(r, clientName = clientMap.get(r.clientId)))
        } yield Response.json(rideDtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides" / "driver" / string("driverId")        -> handler { (driverId: String, request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          driverPid  <- UuidParser.parsePersonId(driverId)
          _          <- AuthMiddleware.checkRoleOrOwner(user, driverPid.value, "DISPATCHER")
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          rides      <- service.getDriverRides(driverPid)
          clientIds   = rides.map(_.clientId).distinct
          persons    <- ZIO.foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
          clientMap   = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
          rideDtos    = rides.map(r => RideDto.fromDomain(r, clientName = clientMap.get(r.clientId)))
        } yield Response.json(rideDtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides" / "client" / string("clientId")        -> handler { (clientId: String, request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          clientPid  <- UuidParser.parsePersonId(clientId)
          _          <- AuthMiddleware.checkRoleOrOwner(user, clientPid.value, "DISPATCHER", "SECRETARY", "CLIENT_SECRETARY")
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          rides      <- service.getClientRides(clientPid)
          clientName <- personRepo.findById(clientPid).map(_.map(_.name))
          rideDtos    = rides.map(r => RideDto.fromDomain(r, clientName = clientName))
        } yield Response.json(rideDtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.PUT / "api" / "rides" / string("rideId") / "status"          -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER")
          bodyStr      <- request.body.asString
          apiRequest   <- ZIO
                            .fromEither(bodyStr.fromJson[RideStatusUpdateRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          validated    <- apiRequest.validate
          parsedRideId <- UuidParser.parseRideId(rideId)
          service      <- ZIO.service[RideService]
          personRepo   <- ZIO.service[PersonRepository]
          ride         <- service.updateRideStatus(
                            parsedRideId,
                            UpdateRideStatusRequest(RideStatus.valueOf(validated.status)),
                            PersonId(user.userId),
                            toPersonRole(user.role)
                          )
          clientName   <- personRepo.findById(ride.clientId).map(_.map(_.name))
          rideDto       = RideDto.fromDomain(ride, clientName = clientName)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.PUT / "api" / "rides" / string("rideId") / "assign-driver"   -> handler {
        (rideId: String, request: Request) =>
          (for {
            user           <- AuthMiddleware.authenticateRequest(request)
            _              <- AuthMiddleware.checkRole(user, "DISPATCHER")
            bodyStr        <- request.body.asString
            apiRequest     <- ZIO
                                .fromEither(bodyStr.fromJson[AssignDriverRequest])
                                .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
            validated      <- apiRequest.validate
            parsedRideId   <- UuidParser.parseRideId(rideId)
            parsedDriverId <- UuidParser.parsePersonId(validated.driverId)
            service        <- ZIO.service[RideService]
            ride           <- service.assignDriver(parsedRideId, parsedDriverId)
            rideDto         = RideDto.fromDomain(ride)
          } yield Response.json(rideDto.toJson)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      => handleRideError(ex)
          }
      },
      Method.PUT / "api" / "rides" / string("rideId") / "reassign-driver" -> handler {
        (rideId: String, request: Request) =>
          (for {
            user           <- AuthMiddleware.authenticateRequest(request)
            _              <- AuthMiddleware.checkRole(user, "DISPATCHER")
            bodyStr        <- request.body.asString
            apiRequest     <- ZIO
                                .fromEither(bodyStr.fromJson[AssignDriverRequest])
                                .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
            validated      <- apiRequest.validate
            parsedRideId   <- UuidParser.parseRideId(rideId)
            parsedDriverId <- UuidParser.parsePersonId(validated.driverId)
            service        <- ZIO.service[RideService]
            ride           <- service.reassignDriver(parsedRideId, parsedDriverId)
            rideDto         = RideDto.fromDomain(ride)
          } yield Response.json(rideDto.toJson)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      => handleRideError(ex)
          }
      },
      Method.PUT / "api" / "rides" / string("rideId")                     -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER", "SECRETARY")
          bodyStr      <- request.body.asString
          apiRequest   <- ZIO
                            .fromEither(bodyStr.fromJson[UpdateRideDetailsApiRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          parsedRideId <- UuidParser.parseRideId(rideId)
          companyId    <- UuidParser.requireCompanyId(user.companyId)
          service      <- ZIO.service[RideService]
          ride         <- service.updateRideDetails(
                            parsedRideId,
                            UpdateRideDetailsApiRequest.toDomain(apiRequest),
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            Some(companyId)
                          )
          rideDto       = RideDto.fromDomain(ride)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides" / string("rideId")                     -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY")
          parsedRideId <- UuidParser.parseRideId(rideId)
          service      <- ZIO.service[RideService]
          ride         <- service.getRideById(parsedRideId)
          companyId    <- UuidParser.requireCompanyId(user.companyId)
          _            <-
            ZIO.when(ride.companyId != companyId)(
              ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
            )
          // Clients can only see their own rides; drivers only their assigned rides
          _            <-
            ZIO.when(user.role.toUpperCase == "CLIENT" && ride.clientId.value != user.userId)(
              ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
            )
          _            <-
            ZIO.when(user.role.toUpperCase == "DRIVER" && !ride.driverId.exists(_.value == user.userId))(
              ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
            )
          rideDto       = RideDto.fromDomain(ride)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.POST / "api" / "rides" / string("rideId") / "airport-timing" -> handler {
        (rideId: String, request: Request) =>
          (for {
            user         <- AuthMiddleware.authenticateRequest(request)
            _            <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
            parsedRideId <- UuidParser.parseRideId(rideId)
            service      <- ZIO.service[RideService]
            ride         <- service.getRideById(parsedRideId)
            companyId    <- UuidParser.requireCompanyId(user.companyId)
            _            <-
              ZIO.when(ride.companyId != companyId)(
                ZIO.fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
              )
            now           = java.time.Instant.now()
            flightTime    = ride.scheduledTime.getOrElse(now.plusSeconds(7200))
            travelTime    = AirportTimingConfig.travelTimeMinutes
            bufferTime    = AirportTimingConfig.bufferTimeMinutes
            totalTime     = travelTime + bufferTime
            optimalEntry  = flightTime.minusSeconds(totalTime * 60)
            latestEntry   = flightTime.minusSeconds(bufferTime * 60)
            timeToDepart  = java.time.Duration.between(now, optimalEntry).toMinutes.toInt
            optimalCost   = AirportTimingConfig.optimalParkingCost
            earlyCost     = AirportTimingConfig.earlyEntryParkingCost
            savings       = earlyCost - optimalCost
            response      =
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
      Method.PUT / "api" / "rides" / string("rideId") / "payment"         -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr      <- request.body.asString
          payReq       <- ZIO
                            .fromEither(bodyStr.fromJson[MarkPaymentRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          parsedRideId <- UuidParser.parseRideId(rideId)
          service      <- ZIO.service[RideService]
          ride         <- service.markPayment(
                            parsedRideId,
                            payReq.paymentStatus,
                            payReq.paymentMethod
                          )
          rideDto       = RideDto.fromDomain(ride)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides" / "unpaid"                             -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          rides      <- service.getUnpaidCompletedRides
          clientIds   = rides.map(_.clientId).distinct
          persons    <- ZIO.foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
          clientMap   = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
          rideDtos    = rides.map(r => RideDto.fromDomain(r, clientName = clientMap.get(r.clientId)))
        } yield Response.json(rideDtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.PUT / "api" / "rides" / string("rideId") / "cancel"          -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER", "CLIENT")
          bodyStr      <- request.body.asString
          cancelReq    <- ZIO
                            .fromEither(bodyStr.fromJson[CancelRideApiRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          parsedRideId <- UuidParser.parseRideId(rideId)
          service      <- ZIO.service[RideService]
          ride         <- service.cancelRideWithReason(
                            parsedRideId,
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            CancelRideRequest(cancelReq.reason, cancelReq.fee.map(BigDecimal(_)))
                          )
          rideDto       = RideDto.fromDomain(ride)
        } yield Response.json(rideDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      },
      Method.GET / "api" / "rides"                                        -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          offset      = request.url.queryParams.queryParam("offset").flatMap(_.toIntOption).getOrElse(0)
          limit       = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(50)
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          rides      <- service.getRidesByCompanyPaginated(companyId, offset, limit)
          clientIds   = rides.map(_.clientId).distinct
          persons    <- ZIO.foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
          clientMap   = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
          rideDtos    = rides.map(r => RideDto.fromDomain(r, clientName = clientMap.get(r.clientId)))
        } yield Response.json(rideDtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleRideError(ex)
        }
      }
    )

  val clientLocationRoutes: Routes[ClientLocationService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides" / string("rideId") / "client-location" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "CLIENT")
          bodyStr      <- request.body.asString
          locReq       <- ZIO
                            .fromEither(bodyStr.fromJson[UpdateClientLocationRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          parsedRideId <- UuidParser.parseRideId(rideId)
          service      <- ZIO.service[ClientLocationService]
          _            <- service.updateClientLocation(
                            parsedRideId,
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
        user         <- AuthMiddleware.authenticateRequest(request)
        _            <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- UuidParser.parseRideId(rideId)
        service      <- ZIO.service[ClientLocationService]
        locations    <- service.getRideLocations(parsedRideId)
      } yield Response.json(locations.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    }
  )

  val chatRoutes: Routes[ChatService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides" / string("rideId") / "chat" -> handler { (rideId: String, request: Request) =>
      (for {
        user         <- AuthMiddleware.authenticateRequest(request)
        _            <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER")
        bodyStr      <- request.body.asString
        chatReq      <- ZIO
                          .fromEither(bodyStr.fromJson[SendChatMessageRequest])
                          .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        parsedRideId <- UuidParser.parseRideId(rideId)
        service      <- ZIO.service[ChatService]
        msg          <- service.sendMessage(
                          parsedRideId,
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
        user         <- AuthMiddleware.authenticateRequest(request)
        _            <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- UuidParser.parseRideId(rideId)
        service      <- ZIO.service[ChatService]
        messages     <- service.getMessages(parsedRideId)
      } yield Response.json(messages.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    }
  )

  val ratingRoutes: Routes[RideRatingRepository & RideService & JwtService, Response] = Routes(
    Method.POST / "api" / "rides" / string("rideId") / "rate"  -> handler { (rideId: String, request: Request) =>
      (for {
        user         <- AuthMiddleware.authenticateRequest(request)
        _            <- AuthMiddleware.checkRole(user, "CLIENT")
        bodyStr      <- request.body.asString
        ratingReq    <- ZIO
                          .fromEither(bodyStr.fromJson[CreateRatingRequest])
                          .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        _            <- ZIO
                          .fail(new RuntimeException("Rating must be between 1 and 5"))
                          .when(ratingReq.rating < 1 || ratingReq.rating > 5)
        parsedRideId <- UuidParser.parseRideId(rideId)
        service      <- ZIO.service[RideService]
        ride         <- service.getRideById(parsedRideId)
        _            <- ZIO
                          .fail(new RuntimeException("Can only rate completed rides"))
                          .when(ride.status != RideStatus.Completed)
        _            <- ZIO
                          .fail(new RuntimeException("Only the ride client can rate"))
                          .when(ride.clientId.value != user.userId)
        repo         <- ZIO.service[RideRatingRepository]
        existing     <- repo.findByRideId(parsedRideId)
        _            <- ZIO
                          .fail(new RuntimeException("Ride already rated"))
                          .when(existing.isDefined)
        driverPid    <- ZIO
                          .fromOption(ride.driverId)
                          .orElseFail(new RuntimeException("No driver assigned"))
        rating        = RideRating(
                          id = RideRatingId.generate(),
                          rideId = parsedRideId,
                          clientId = PersonId(user.userId),
                          driverId = driverPid,
                          companyId = ride.companyId,
                          rating = ratingReq.rating,
                          comment = ratingReq.comment
                        )
        created      <- repo.create(rating)
      } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    },
    Method.GET / "api" / "rides" / string("rideId") / "rating" -> handler { (rideId: String, request: Request) =>
      (for {
        user         <- AuthMiddleware.authenticateRequest(request)
        _            <- AuthMiddleware.checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- UuidParser.parseRideId(rideId)
        repo         <- ZIO.service[RideRatingRepository]
        rating       <- repo.findByRideId(parsedRideId)
      } yield rating match {
        case Some(r) => Response.json(r.toJson)
        case None    => Response.status(Status.NotFound)
      }).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleRideError(ex)
      }
    }
  )

}
