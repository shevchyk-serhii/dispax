package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideService
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{*, given}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.{RideRatingRepository, TariffRepository}
import com.shevchyk.ride.validation.Validator.validate
import com.shevchyk.ride.validation.given
import sttp.model.{MediaType, StatusCode}
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

// NOTE: The estimate endpoint uses Haversine great-circle distance (not HERE Routing) because the
// `ride` module does not depend on `driver` (where HereRoutingService lives) and adding that
// dependency would create a build-graph cycle. Haversine gives an appropriate straight-line distance
// for billing estimates; duration is derived from a 50 km/h average urban speed (same fallback used
// by EtaService when HERE is unavailable). If sub-minute accuracy is needed, a shared routing trait
// can be extracted to `core` in a follow-up.

/**
 * Tapir descriptions and server logic for the ride endpoints. Replaces the zio-http handlers in `RideRoutes`
 * (authenticated rides, client-location, chat and rating route groups) while keeping the exact paths, request/response
 * shapes, status codes, role checks and company isolation.
 */
object RideApi:

  private val rideTag = "Rides"

  // -- Environment ---------------------------------------------------------
  type RideEnv =
    RideService & ClientAddressService & ClientLocationService & AirportCheckpointService & ChatService &
      RideRatingRepository & PersonRepository & JwtService & TariffRepository

  private object AirportTimingConfig:
    val travelTimeMinutes: Int        = 45
    val bufferTimeMinutes: Int        = 30
    val optimalParkingCost: Double    = 12.50
    val earlyEntryParkingCost: Double = 25.00

  // ======================================================================
  // Endpoint descriptions
  // ======================================================================

  val createRideEndpoint = secureEndpoint.post
    .in("api" / "rides")
    .in(jsonBody[CreateRideApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[RideDto]))
    .tag(rideTag)
    .summary("Create a ride")

  val getPendingRidesEndpoint = secureEndpoint.get
    .in("api" / "rides" / "pending")
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List pending (requested) rides")

  val getUnpaidRidesEndpoint = secureEndpoint.get
    .in("api" / "rides" / "unpaid")
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List unpaid completed rides")

  val getDriverRidesEndpoint = secureEndpoint.get
    .in("api" / "rides" / "driver" / path[String]("driverId"))
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List a driver's rides")

  val getClientRidesEndpoint = secureEndpoint.get
    .in("api" / "rides" / "client" / path[String]("clientId"))
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List a client's rides")

  val updateRideStatusEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "status")
    .in(jsonBody[RideStatusUpdateRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Update a ride's status")

  val assignDriverEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "assign-driver")
    .in(jsonBody[AssignDriverRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Assign a driver to a ride")

  val reassignDriverEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "reassign-driver")
    .in(jsonBody[AssignDriverRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Reassign a driver to a ride")

  val airportTimingEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "airport-timing")
    .out(stringBody.and(header(sttp.model.Header.contentType(MediaType.ApplicationJson))))
    .tag(rideTag)
    .summary("Compute optimal airport timing for a ride")

  val markPaymentEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "payment")
    .in(jsonBody[MarkPaymentRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Mark a ride's payment status")

  val cancelRideEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "cancel")
    .in(jsonBody[CancelRideApiRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Cancel a ride")

  val updateRideEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId"))
    .in(jsonBody[UpdateRideDetailsApiRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Update ride details")

  val getRideEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId"))
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Get a ride by id")

  val listRidesEndpoint = secureEndpoint.get
    .in("api" / "rides")
    .in(query[Option[Int]]("offset"))
    .in(query[Option[Int]]("limit"))
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List company rides (paginated)")

  // -- estimate route ------------------------------------------------------

  val estimateRideEndpoint = secureEndpoint.post
    .in("api" / "rides" / "estimate")
    .in(jsonBody[EstimateRideRequest])
    .out(jsonBody[EstimateRideResponse])
    .tag(rideTag)
    .summary("Estimate ride distance, duration and price")

  // -- client-location routes ----------------------------------------------

  val updateClientLocationEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "client-location")
    .in(jsonBody[UpdateClientLocationRequest])
    .out(statusCode(StatusCode.NoContent))
    .tag(rideTag)
    .summary("Update the client's live location for a ride")

  val getRideLocationsEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId") / "locations")
    .out(jsonBody[com.shevchyk.ride.application.service.RideLocationsResponse])
    .tag(rideTag)
    .summary("Get the driver and client locations for a ride")

  // -- chat routes ---------------------------------------------------------

  val sendChatMessageEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "chat")
    .in(jsonBody[SendChatMessageRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[ChatMessage]))
    .tag(rideTag)
    .summary("Send a chat message for a ride")

  val getChatMessagesEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId") / "chat")
    .out(jsonBody[List[ChatMessage]])
    .tag(rideTag)
    .summary("Get the chat messages for a ride")

  // -- rating routes -------------------------------------------------------

  val rateRideEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "rate")
    .in(jsonBody[CreateRatingRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[RideRating]))
    .tag(rideTag)
    .summary("Rate a completed ride")

  val getRatingEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId") / "rating")
    .out(jsonBody[RideRating])
    .tag(rideTag)
    .summary("Get a ride's rating")

  // -- airport-checkpoint routes -------------------------------------------

  val markAirportCheckpointEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "airport-checkpoint")
    .in(jsonBody[MarkCheckpointRequest])
    .out(statusCode(StatusCode.NoContent))
    .tag(rideTag)
    .summary("Mark the client's current airport checkpoint (CLIENT only)")

  val getAirportCheckpointEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId") / "airport-checkpoint")
    .out(jsonBody[CheckpointStateResponse])
    .tag(rideTag)
    .summary("Get the current airport checkpoint state for a ride")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    createRideEndpoint,
    getPendingRidesEndpoint,
    getUnpaidRidesEndpoint,
    getDriverRidesEndpoint,
    getClientRidesEndpoint,
    updateRideStatusEndpoint,
    assignDriverEndpoint,
    reassignDriverEndpoint,
    airportTimingEndpoint,
    markPaymentEndpoint,
    cancelRideEndpoint,
    updateRideEndpoint,
    getRideEndpoint,
    listRidesEndpoint,
    estimateRideEndpoint,
    updateClientLocationEndpoint,
    getRideLocationsEndpoint,
    sendChatMessageEndpoint,
    getChatMessagesEndpoint,
    rateRideEndpoint,
    getRatingEndpoint,
    markAirportCheckpointEndpoint,
    getAirportCheckpointEndpoint
  )

  // ======================================================================
  // Server logic
  // ======================================================================

  private val createRideServer: ZServerEndpoint[RideEnv, Any] = createRideEndpoint.serverLogic { user => apiRequest =>
    for {
      _             <- checkRole(user, "DISPATCHER", "SECRETARY", "CLIENT", "DRIVER", "CLIENT_SECRETARY")
      companyId     <- requireCompanyId(user.companyId)
      validRequest  <- apiRequest.validate.mapError(fromRideError)
      domainRequest <- CreateRideApiRequest
                         .toDomain(validRequest, companyId)
                         .mapError(_ => (StatusCode.BadRequest, ApiError("Invalid UUID format")))
                         .map { req =>
                           if (user.role.toUpperCase == "CLIENT")
                             req.copy(clientId = PersonId(user.userId))
                           else if (user.role.toUpperCase == "DRIVER" && validRequest.clientId == user.userId.toString)
                             req.copy(clientId = PersonId(user.userId))
                           else
                             req
                         }
      service       <- ZIO.service[RideService]
      ride0         <- service.createRide(domainRequest).mapError(fromRideError)
      ride          <-
        validRequest.driverId match
          case Some(driverIdStr) =>
            parsePersonId(driverIdStr).flatMap { driverPid =>
              service.assignDriver(ride0.id, driverPid).mapError(fromRideError)
            }
          case None              => ZIO.succeed(ride0)
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
    } yield RideDto.fromDomain(ride)
  }

  private val getPendingRidesServer: ZServerEndpoint[RideEnv, Any] = getPendingRidesEndpoint.serverLogic { user => _ =>
    for {
      _           <- checkRole(user, "DISPATCHER")
      companyId   <- requireCompanyId(user.companyId)
      service     <- ZIO.service[RideService]
      personRepo  <- ZIO.service[PersonRepository]
      ratingRepo  <- ZIO.service[RideRatingRepository]
      rides       <- service.getRidesByStatus(RideStatus.Requested).mapError(fromRideError)
      clientIds    = rides.map(_.clientId).distinct
      persons     <- ZIO
                       .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                       .mapError(fromRideError)
      clientMap    = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
      ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
    } yield rides.map { r =>
      val (rating, count) = r.driverId
        .flatMap(ratingStats.get)
        .map { case (avg, n) => (Some(avg), Some(n)) }
        .getOrElse((None, None))
      RideDto.fromDomain(r, clientName = clientMap.get(r.clientId), driverRating = rating, driverRatingCount = count)
    }
  }

  private val getUnpaidRidesServer: ZServerEndpoint[RideEnv, Any] = getUnpaidRidesEndpoint.serverLogic { user => _ =>
    for {
      _           <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId   <- requireCompanyId(user.companyId)
      service     <- ZIO.service[RideService]
      personRepo  <- ZIO.service[PersonRepository]
      ratingRepo  <- ZIO.service[RideRatingRepository]
      rides       <- service.getUnpaidCompletedRides(companyId).mapError(fromRideError)
      clientIds    = rides.map(_.clientId).distinct
      persons     <- ZIO
                       .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                       .mapError(fromRideError)
      clientMap    = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
      ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
    } yield rides.map { r =>
      val (rating, count) = r.driverId
        .flatMap(ratingStats.get)
        .map { case (avg, n) => (Some(avg), Some(n)) }
        .getOrElse((None, None))
      RideDto.fromDomain(r, clientName = clientMap.get(r.clientId), driverRating = rating, driverRatingCount = count)
    }
  }

  private val getDriverRidesServer: ZServerEndpoint[RideEnv, Any] = getDriverRidesEndpoint.serverLogic {
    user => driverId =>
      for {
        driverPid   <- parsePersonId(driverId)
        _           <- checkRoleOrOwner(user, driverPid.value, "DISPATCHER")
        companyId   <- requireCompanyId(user.companyId)
        service     <- ZIO.service[RideService]
        personRepo  <- ZIO.service[PersonRepository]
        ratingRepo  <- ZIO.service[RideRatingRepository]
        rides       <- service.getDriverRides(driverPid, companyId).mapError(fromRideError)
        clientIds    = rides.map(_.clientId).distinct
        persons     <- ZIO
                         .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                         .mapError(fromRideError)
        clientMap    = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
        ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
      } yield rides.map { r =>
        val (rating, count) = r.driverId
          .flatMap(ratingStats.get)
          .map { case (avg, n) => (Some(avg), Some(n)) }
          .getOrElse((None, None))
        RideDto.fromDomain(r, clientName = clientMap.get(r.clientId), driverRating = rating, driverRatingCount = count)
      }
  }

  private val getClientRidesServer: ZServerEndpoint[RideEnv, Any] = getClientRidesEndpoint.serverLogic {
    user => clientId =>
      for {
        clientPid   <- parsePersonId(clientId)
        _           <- checkRoleOrOwner(user, clientPid.value, "DISPATCHER", "SECRETARY", "CLIENT_SECRETARY")
        companyId   <- requireCompanyId(user.companyId)
        service     <- ZIO.service[RideService]
        personRepo  <- ZIO.service[PersonRepository]
        ratingRepo  <- ZIO.service[RideRatingRepository]
        rides       <- service.getClientRides(clientPid, companyId).mapError(fromRideError)
        clientName  <- personRepo.findById(clientPid).map(_.map(_.name)).mapError(fromRideError)
        // Resolve every distinct driver name once in parallel instead of one sequential
        // findById per ride (was N+1).
        driverIds    = rides.flatMap(_.driverId).distinct
        driverNames <- ZIO
                         .foreachPar(driverIds)(id => personRepo.findById(id).map(p => id -> p.map(_.name)))
                         .map(_.toMap)
                         .mapError(fromRideError)
        ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
        rideDtos     = rides.map { r =>
                         val driverName          = r.driverId.flatMap(driverNames.getOrElse(_, None))
                         val (rating, rateCount) = r.driverId
                           .flatMap(ratingStats.get)
                           .map { case (avg, n) => (Some(avg), Some(n)) }
                           .getOrElse((None, None))
                         RideDto.fromDomain(
                           r,
                           clientName = clientName,
                           driverName = driverName,
                           driverRating = rating,
                           driverRatingCount = rateCount
                         )
                       }
      } yield rideDtos
  }

  private val updateRideStatusServer: ZServerEndpoint[RideEnv, Any] = updateRideStatusEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _            <- checkRole(user, "DRIVER", "DISPATCHER")
        validated    <- apiRequest.validate.mapError(fromRideError)
        parsedRideId <- parseRideId(rideId)
        service      <- ZIO.service[RideService]
        personRepo   <- ZIO.service[PersonRepository]
        ride         <- service
                          .updateRideStatus(
                            parsedRideId,
                            UpdateRideStatusRequest(RideStatus.valueOf(validated.status)),
                            PersonId(user.userId),
                            toPersonRole(user.role)
                          )
                          .mapError(fromRideError)
        clientName   <- personRepo.findById(ride.clientId).map(_.map(_.name)).mapError(fromRideError)
      } yield RideDto.fromDomain(ride, clientName = clientName)
  }

  private val assignDriverServer: ZServerEndpoint[RideEnv, Any] = assignDriverEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _              <- checkRole(user, "DISPATCHER")
        validated      <- apiRequest.validate.mapError(fromRideError)
        parsedRideId   <- parseRideId(rideId)
        parsedDriverId <- parsePersonId(validated.driverId)
        service        <- ZIO.service[RideService]
        ride           <- service.assignDriver(parsedRideId, parsedDriverId).mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val reassignDriverServer: ZServerEndpoint[RideEnv, Any] = reassignDriverEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _              <- checkRole(user, "DISPATCHER")
        validated      <- apiRequest.validate.mapError(fromRideError)
        parsedRideId   <- parseRideId(rideId)
        parsedDriverId <- parsePersonId(validated.driverId)
        service        <- ZIO.service[RideService]
        ride           <- service.reassignDriver(parsedRideId, parsedDriverId).mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val updateRideServer: ZServerEndpoint[RideEnv, Any] = updateRideEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _            <- checkRole(user, "DRIVER", "DISPATCHER", "SECRETARY")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        ride         <- service
                          .updateRideDetails(
                            parsedRideId,
                            UpdateRideDetailsApiRequest.toDomain(apiRequest),
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            Some(companyId)
                          )
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val getRideServer: ZServerEndpoint[RideEnv, Any] = getRideEndpoint.serverLogic { user => rideId =>
    for {
      _            <- checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY")
      parsedRideId <- parseRideId(rideId)
      service      <- ZIO.service[RideService]
      ride         <- service.getRideById(parsedRideId).mapError(fromRideError)
      companyId    <- requireCompanyId(user.companyId)
      _            <- ZIO
                        .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                        .when(ride.companyId != companyId)
                        .mapError(fromRideError)
      _            <- ZIO
                        .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                        .when(user.role.toUpperCase == "CLIENT" && ride.clientId.value != user.userId)
                        .mapError(fromRideError)
      _            <- ZIO
                        .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                        .when(user.role.toUpperCase == "DRIVER" && !ride.driverId.exists(_.value == user.userId))
                        .mapError(fromRideError)
    } yield RideDto.fromDomain(ride)
  }

  private val airportTimingServer: ZServerEndpoint[RideEnv, Any] = airportTimingEndpoint.serverLogic { user => rideId =>
    for {
      _            <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
      parsedRideId <- parseRideId(rideId)
      service      <- ZIO.service[RideService]
      ride         <- service.getRideById(parsedRideId).mapError(fromRideError)
      companyId    <- requireCompanyId(user.companyId)
      _            <- ZIO
                        .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                        .when(ride.companyId != companyId)
                        .mapError(fromRideError)
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
      body          =
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
    } yield body
  }

  private val markPaymentServer: ZServerEndpoint[RideEnv, Any] = markPaymentEndpoint.serverLogic {
    user => (rideId, payReq) =>
      for {
        _            <- checkRole(user, "DISPATCHER", "ADMIN")
        parsedRideId <- parseRideId(rideId)
        service      <- ZIO.service[RideService]
        existing     <- service.getRideById(parsedRideId).mapError(fromRideError)
        companyId    <- requireCompanyId(user.companyId)
        _            <- ZIO
                          .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                          .when(existing.companyId != companyId)
                          .mapError(fromRideError)
        ride         <- service
                          .markPayment(parsedRideId, payReq.paymentStatus, payReq.paymentMethod)
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val cancelRideServer: ZServerEndpoint[RideEnv, Any] = cancelRideEndpoint.serverLogic {
    user => (rideId, cancelReq) =>
      for {
        _            <- checkRole(user, "DRIVER", "DISPATCHER", "CLIENT")
        parsedRideId <- parseRideId(rideId)
        service      <- ZIO.service[RideService]
        ride         <- service
                          .cancelRideWithReason(
                            parsedRideId,
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            CancelRideRequest(cancelReq.reason, cancelReq.fee.map(BigDecimal(_)))
                          )
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val listRidesServer: ZServerEndpoint[RideEnv, Any] = listRidesEndpoint.serverLogic {
    user => (offsetOpt, limitOpt) =>
      for {
        companyId   <- requireCompanyId(user.companyId)
        offset       = offsetOpt.getOrElse(0)
        limit        = limitOpt.getOrElse(50)
        service     <- ZIO.service[RideService]
        personRepo  <- ZIO.service[PersonRepository]
        ratingRepo  <- ZIO.service[RideRatingRepository]
        rides       <- service.getRidesByCompanyPaginated(companyId, offset, limit).mapError(fromRideError)
        clientIds    = rides.map(_.clientId).distinct
        persons     <- ZIO
                         .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                         .mapError(fromRideError)
        clientMap    = persons.collect { case (id, Some(p)) => id -> p.name }.toMap
        ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
      } yield rides.map { r =>
        val (rating, count) = r.driverId
          .flatMap(ratingStats.get)
          .map { case (avg, n) => (Some(avg), Some(n)) }
          .getOrElse((None, None))
        RideDto.fromDomain(r, clientName = clientMap.get(r.clientId), driverRating = rating, driverRatingCount = count)
      }
  }

  // -- client-location servers ---------------------------------------------

  private val updateClientLocationServer: ZServerEndpoint[RideEnv, Any] = updateClientLocationEndpoint.serverLogic {
    user => (rideId, locReq) =>
      for {
        _            <- checkRole(user, "CLIENT")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        service      <- ZIO.service[ClientLocationService]
        _            <- service
                          .updateClientLocation(parsedRideId, PersonId(user.userId), locReq.latitude, locReq.longitude)
                          .mapError(fromRideError)
      } yield ()
  }

  private val getRideLocationsServer: ZServerEndpoint[RideEnv, Any] = getRideLocationsEndpoint.serverLogic {
    user => rideId =>
      for {
        _            <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        service      <- ZIO.service[ClientLocationService]
        locations    <- service.getRideLocations(parsedRideId).mapError(fromRideError)
      } yield locations
  }

  // -- chat servers --------------------------------------------------------

  private val sendChatMessageServer: ZServerEndpoint[RideEnv, Any] = sendChatMessageEndpoint.serverLogic {
    user => (rideId, chatReq) =>
      for {
        _            <- checkRole(user, "CLIENT", "DRIVER")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        service      <- ZIO.service[ChatService]
        msg          <- service.sendMessage(parsedRideId, PersonId(user.userId), chatReq.message).mapError(fromRideError)
      } yield msg
  }

  private val getChatMessagesServer: ZServerEndpoint[RideEnv, Any] = getChatMessagesEndpoint.serverLogic {
    user => rideId =>
      for {
        _            <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        service      <- ZIO.service[ChatService]
        messages     <- service.getMessages(parsedRideId).mapError(fromRideError)
      } yield messages
  }

  // -- rating servers ------------------------------------------------------

  private val rateRideServer: ZServerEndpoint[RideEnv, Any] = rateRideEndpoint.serverLogic {
    user => (rideId, ratingReq) =>
      for {
        _            <- checkRole(user, "CLIENT")
        _            <- ZIO
                          .fail(RideError.ValidationError("Rating must be between 1 and 5"))
                          .when(ratingReq.rating < 1 || ratingReq.rating > 5)
                          .mapError(fromRideError)
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        ride         <- service.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        _            <- ZIO
                          .fail(RideError.BusinessRuleViolation("ride_status", "Can only rate completed rides"))
                          .when(ride.status != RideStatus.Completed)
                          .mapError(fromRideError)
        _            <- ZIO
                          .fail(RideError.UnauthorizedAccess(PersonId(user.userId), parsedRideId))
                          .when(ride.clientId.value != user.userId)
                          .mapError(fromRideError)
        repo         <- ZIO.service[RideRatingRepository]
        existing     <- repo.findByRideId(parsedRideId).mapError(fromRideError)
        _            <- ZIO
                          .fail(RideError.BusinessRuleViolation("already_rated", "Ride already rated"))
                          .when(existing.isDefined)
                          .mapError(fromRideError)
        driverPid    <- ZIO
                          .fromOption(ride.driverId)
                          .orElseFail((StatusCode.InternalServerError, ApiError("Internal server error")))
        rating        = RideRating(
                          id = RideRatingId.generate(),
                          rideId = parsedRideId,
                          clientId = PersonId(user.userId),
                          driverId = driverPid,
                          companyId = ride.companyId,
                          rating = ratingReq.rating,
                          comment = ratingReq.comment
                        )
        created      <- repo.create(rating).mapError(fromRideError)
      } yield created
  }

  private val getRatingServer: ZServerEndpoint[RideEnv, Any] = getRatingEndpoint.serverLogic { user => rideId =>
    for {
      _            <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
      parsedRideId <- parseRideId(rideId)
      companyId    <- requireCompanyId(user.companyId)
      rideService  <- ZIO.service[RideService]
      ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
      // Company isolation: hide cross-tenant rides as not found.
      _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
      repo         <- ZIO.service[RideRatingRepository]
      ratingOpt    <- repo.findByRideId(parsedRideId).mapError(fromRideError)
      rating       <- ZIO
                        .fromOption(ratingOpt)
                        .orElseFail((StatusCode.NotFound, ApiError("Not found")))
    } yield rating
  }

  // -- airport-checkpoint servers ------------------------------------------

  private val markAirportCheckpointServer: ZServerEndpoint[RideEnv, Any] = markAirportCheckpointEndpoint.serverLogic {
    user => (rideId, checkpointReq) =>
      for {
        _             <- checkRole(user, "CLIENT")
        parsedRideId  <- parseRideId(rideId)
        companyId     <- requireCompanyId(user.companyId)
        validReq      <- checkpointReq.validate.mapError(fromRideError)
        rideService   <- ZIO.service[RideService]
        ride          <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _             <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
        checkpoint    <- ZIO
                           .fromOption(AirportCheckpoint.fromString(validReq.checkpoint))
                           .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid checkpoint: ${validReq.checkpoint}")))
        checkpointSvc <- ZIO.service[AirportCheckpointService]
        _             <- checkpointSvc.markCheckpoint(ride, checkpoint, PersonId(user.userId)).mapError(fromRideError)
      } yield ()
  }

  private val getAirportCheckpointServer: ZServerEndpoint[RideEnv, Any] = getAirportCheckpointEndpoint.serverLogic {
    user => rideId =>
      for {
        _            <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        ride         <- rideService.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(RideError.RideNotFound(parsedRideId)).when(ride.companyId != companyId).mapError(fromRideError)
      } yield CheckpointStateResponse(
        checkpoint = ride.airportCheckpoint.map(AirportCheckpoint.toDbString),
        checkpointName = ride.airportCheckpoint.map(MucCheckpoints.displayName)
      )
  }

  // -- estimate server -----------------------------------------------------

  // Distance and duration are computed with Haversine + 50 km/h average speed because the ride
  // module cannot import HereRoutingService (that lives in the driver module, a sibling, not a
  // dependency of ride). See the note at the top of the file for the full rationale.
  private val estimateRideServer: ZServerEndpoint[RideEnv, Any] = estimateRideEndpoint.serverLogic { user => req =>
    for {
      _           <- checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY", "ADMIN")
      companyId   <- requireCompanyId(user.companyId)
      // Both locations must have coordinates for a meaningful estimate.
      fromLat     <- ZIO
                       .fromOption(req.from.latitude)
                       .orElseFail((StatusCode.BadRequest, ApiError("from.latitude is required for estimation")))
      fromLng     <- ZIO
                       .fromOption(req.from.longitude)
                       .orElseFail((StatusCode.BadRequest, ApiError("from.longitude is required for estimation")))
      toLat       <- ZIO
                       .fromOption(req.to.latitude)
                       .orElseFail((StatusCode.BadRequest, ApiError("to.latitude is required for estimation")))
      toLng       <- ZIO
                       .fromOption(req.to.longitude)
                       .orElseFail((StatusCode.BadRequest, ApiError("to.longitude is required for estimation")))
      // Compute straight-line distance via Haversine (used as the billing distance).
      distanceKm   = haversineKm(fromLat, fromLng, toLat, toLng)
      // Duration estimate: 50 km/h average urban speed (same fallback as EtaService).
      etaMinutes   = Math.ceil(distanceKm / 50.0 * 60.0).toInt.max(1)
      // Load company tariff; fall back to defaults if absent.
      tariffRepo  <- ZIO.service[TariffRepository]
      tariff      <- tariffRepo
                       .findByCompanyId(companyId)
                       .map(_.getOrElse(CompanyTariff.default(companyId)))
                       .mapError(ex => (StatusCode.InternalServerError, ApiError("Failed to load tariff")))
      vehicleClass = VehicleClass.fromString(req.vehicleClass).getOrElse(VehicleClass.Default)
      price        = tariff.estimate(distanceKm, req.isAirportTransfer, vehicleClass)
    } yield EstimateRideResponse(
      distanceKm = BigDecimal(distanceKm).setScale(2, BigDecimal.RoundingMode.HALF_UP).doubleValue,
      durationMinutes = etaMinutes,
      estimatedPrice = price.doubleValue,
      currency = tariff.currency
    )
  }

  /**
   * Haversine great-circle distance in kilometres between two WGS-84 coordinates.
   */
  private def haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double =
    val R    = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    R * c

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[RideEnv, Any]] = List(
    createRideServer,
    getPendingRidesServer,
    getUnpaidRidesServer,
    getDriverRidesServer,
    getClientRidesServer,
    updateRideStatusServer,
    assignDriverServer,
    reassignDriverServer,
    airportTimingServer,
    markPaymentServer,
    cancelRideServer,
    updateRideServer,
    getRideServer,
    listRidesServer,
    estimateRideServer,
    updateClientLocationServer,
    getRideLocationsServer,
    sendChatMessageServer,
    getChatMessagesServer,
    rateRideServer,
    getRatingServer,
    markAirportCheckpointServer,
    getAirportCheckpointServer
  )
