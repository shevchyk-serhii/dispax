package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.config.AirportArrivalTimingConfig
import com.shevchyk.core.domain.{ExternalDriverId, PartnerCompanyId, Person, PersonId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  AirportTimingService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  FlightStatusProvider,
  FlightStatusRefresher,
  RideEstimateService,
  RideService
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{*, given}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.{RideRatingRepository, RideRepository, TariffRepository}
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

  // -- Pagination ----------------------------------------------------------
  // Clamp client-supplied paging params so negative / oversized values never
  // reach the SQL LIMIT/OFFSET clauses.
  private[ride] object Paging:
    val MinLimit: Int = 1
    val MaxLimit: Int = 200

    def clampLimit(limit: Int): Int   = limit.max(MinLimit).min(MaxLimit)
    def clampOffset(offset: Int): Int = offset.max(0)

  // -- Environment ---------------------------------------------------------
  type RideEnv =
    RideService & ClientAddressService & ClientLocationService & AirportCheckpointService & ChatService &
      RideRatingRepository & PersonRepository & JwtService & TariffRepository & RideEstimateService & GeocodingService &
      AirportTimingService & RideRepository & AirportArrivalTimingConfig & FlightStatusProvider & EventHub

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
    .in(jsonBody[AirportTimingRequest])
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

  val handOffRideEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "hand-off")
    .in(jsonBody[HandOffRideApiRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Hand off a ride to an external driver")

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

  val refreshFlightEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "refresh-flight")
    .out(jsonBody[RefreshFlightResponse])
    .tag(rideTag)
    .summary("Refresh a ride's flight status now (on-demand, same as the background monitor)")

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

  // -- driver confirmation routes ------------------------------------------

  val confirmRideEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "confirm")
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Driver confirms the assigned ride")

  val rejectRideEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "reject")
    .in(jsonBody[RejectRideRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Driver rejects the assigned ride with a reason")

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

  val setRidePriceEndpoint = secureEndpoint.put
    .in("api" / "rides" / path[String]("rideId") / "price")
    .in(jsonBody[SetRidePriceRequest])
    .out(jsonBody[RideDto])
    .tag(rideTag)
    .summary("Set the final price of a ride")

  // driverIds: comma-separated list; from/to: optional ISO-8601 date strings (YYYY-MM-DD)
  val getRidesByDriversEndpoint = secureEndpoint.get
    .in("api" / "rides" / "by-drivers")
    .in(query[String]("driverIds"))
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[List[RideDto]])
    .tag(rideTag)
    .summary("List rides for multiple drivers (bulk, date-scoped)")

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
    handOffRideEndpoint,
    updateRideEndpoint,
    getRideEndpoint,
    refreshFlightEndpoint,
    listRidesEndpoint,
    estimateRideEndpoint,
    updateClientLocationEndpoint,
    getRideLocationsEndpoint,
    sendChatMessageEndpoint,
    getChatMessagesEndpoint,
    rateRideEndpoint,
    getRatingEndpoint,
    confirmRideEndpoint,
    rejectRideEndpoint,
    markAirportCheckpointEndpoint,
    getAirportCheckpointEndpoint,
    setRidePriceEndpoint,
    getRidesByDriversEndpoint
  )

  // ======================================================================
  // Server logic
  // ======================================================================

  private val createRideServer: ZServerEndpoint[RideEnv, Any] = createRideEndpoint.serverLogic { user => apiRequest =>
    for {
      _               <- checkRole(user, "DISPATCHER", "SECRETARY", "CLIENT", "DRIVER", "CLIENT_SECRETARY")
      companyId       <- requireCompanyId(user.companyId)
      validRequest    <- apiRequest.validate.mapError(fromRideError)
      // provisionalClient is a staff affordance (driver/dispatcher/secretary booking a walk-in
      // passenger). A CLIENT/CLIENT_SECRETARY must always book as an identified client — honouring
      // the flag for them would let a client fabricate phantom Person rows and book rides under an
      // arbitrary name/phone instead of their own identity.
      _               <- ZIO
                           .fail((StatusCode.Forbidden, ApiError("provisionalClient is not available to client roles")))
                           .when(
                             validRequest.provisionalClient &&
                               Set("CLIENT", "CLIENT_SECRETARY").contains(user.role.toUpperCase)
                           )
      personRepo      <- ZIO.service[PersonRepository]
      // Provisional ("from-chat") ride: no real client is known. Create a lightweight provisional
      // client carrying the typed clientName/clientPhone (which were previously discarded), stamped
      // with the creator's companyId for tenant isolation, and book the ride against it. This replaces
      // the old "clientId == own userId" driver hack, which silently booked the ride onto the driver.
      provisionalOpt  <-
        ZIO
          .when(validRequest.provisionalClient) {
            val provisional = Person.provisionalClient(
              name = Option(validRequest.clientName).map(_.trim).filter(_.nonEmpty),
              phone = validRequest.clientPhone,
              companyId = companyId
            )
            personRepo
              .create(provisional)
              // Never surface raw repository/driver text (constraint and table names) to the
              // caller — log the cause, answer with the same generic 500 as fromRideError.
              .tapError(e => ZIO.logError(s"Failed to create provisional client: ${e.getMessage}"))
              .mapError(_ => (StatusCode.InternalServerError, ApiError("Internal server error")))
          }
      // For a client booking, the client is always the authenticated user. For a provisional ride,
      // point clientId at the freshly created provisional client. Otherwise use the supplied clientId.
      effectiveRequest =
        provisionalOpt match
          case Some(p) => validRequest.copy(clientId = p.id.value.toString)
          case None    =>
            if (user.role.toUpperCase == "CLIENT")
              validRequest.copy(clientId = user.userId.toString)
            else
              validRequest
      domainRequest   <- CreateRideApiRequest
                           .toDomain(effectiveRequest, companyId)
                           .mapError(_ => (StatusCode.BadRequest, ApiError("Invalid UUID format")))
      // Resolve the client's clientCompanyId so PickupTimeService can apply per-client timing
      // overrides (e.g. a corporate account with a custom check-in window). The lookup is
      // best-effort: if the person is not found or has no company affiliation, we proceed
      // without a client override (company/global defaults apply). For a provisional ride we already
      // hold the Person, so skip the round-trip.
      clientPerson    <-
        provisionalOpt match
          case Some(p) => ZIO.some(p)
          case None    =>
            personRepo
              .findById(domainRequest.clientId)
              .tapError(e => ZIO.logError(s"Failed to load ride client: ${e.getMessage}"))
              .mapError(_ => (StatusCode.InternalServerError, ApiError("Internal server error")))
      enrichedRequest  =
        clientPerson
          .flatMap(_.clientCompanyId)
          .fold(domainRequest)(ccId => domainRequest.copy(clientCompanyId = Some(ccId)))
      service         <- ZIO.service[RideService]
      ride0           <- service.createRide(enrichedRequest).mapError(fromRideError)
      ride            <-
        validRequest.driverId match
          case Some(driverIdStr) =>
            parsePersonId(driverIdStr).flatMap { driverPid =>
              // The ride is already created and sitting in the pool. The optional
              // self-assign must never lose it: a schedule conflict is non-fatal —
              // we keep the pooled (unassigned) ride and return it. The client
              // detects "self-assign requested but the ride came back without a
              // driver" and offers to assign anyway via PUT /assign-driver
              // (override).
              //
              // A cross-tenant driverId (company_isolation) is also swallowed
              // here: surfacing it would leak the existence of another company's
              // driver via the create response. Returning the pooled, unassigned
              // ride hides that just like a schedule conflict does. Other assign
              // errors (driver not found, blacklist) still fail the request.
              service
                .assignDriver(ride0.id, driverPid)
                .catchSome {
                  case _: RideError.ScheduleConflict                           => ZIO.succeed(ride0)
                  case RideError.BusinessRuleViolation("company_isolation", _) => ZIO.succeed(ride0)
                }
                .mapError(fromRideError)
            }
          case None              => ZIO.succeed(ride0)
      addrService     <- ZIO.service[ClientAddressService]
      _               <-
        addrService
          .recordUsage(ride.clientId, ride.pickupLocation.address, "Pickup", None, None)
          .tapError(e => ZIO.logWarning(s"Failed to record from address: $e"))
          .ignore
      _               <-
        addrService
          .recordUsage(ride.clientId, ride.dropoffLocation.address, "Dropoff", None, None)
          .tapError(e => ZIO.logWarning(s"Failed to record to address: $e"))
          .ignore
    } yield RideDto.fromDomain(
      ride,
      clientName = clientPerson.map(_.name),
      clientHasAvatar = clientPerson.exists(_.avatarPresent),
      clientProvisional = clientPerson.exists(_.provisional)
    )
  }

  private val getPendingRidesServer: ZServerEndpoint[RideEnv, Any] = getPendingRidesEndpoint.serverLogic { user => _ =>
    for {
      _           <- checkRole(user, "DISPATCHER")
      companyId   <- requireCompanyId(user.companyId)
      service     <- ZIO.service[RideService]
      personRepo  <- ZIO.service[PersonRepository]
      ratingRepo  <- ZIO.service[RideRatingRepository]
      rides       <- service.getRidesByStatusAndCompany(RideStatus.Requested, companyId).mapError(fromRideError)
      clientIds    = rides.map(_.clientId).distinct
      persons     <- ZIO
                       .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                       .mapError(fromRideError)
      clientMap    = persons.collect { case (id, Some(p)) => id -> p }.toMap
      ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
    } yield rides.map { r =>
      val (rating, count) = r.driverId
        .flatMap(ratingStats.get)
        .map { case (avg, n) => (Some(avg), Some(n)) }
        .getOrElse((None, None))
      RideDto.fromDomain(
        r,
        clientName = clientMap.get(r.clientId).map(_.name),
        clientHasAvatar = clientMap.get(r.clientId).exists(_.avatarPresent),
        clientProvisional = clientMap.get(r.clientId).exists(_.provisional),
        driverRating = rating,
        driverRatingCount = count
      )
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
      clientMap    = persons.collect { case (id, Some(p)) => id -> p }.toMap
      ratingStats <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
    } yield rides.map { r =>
      val (rating, count) = r.driverId
        .flatMap(ratingStats.get)
        .map { case (avg, n) => (Some(avg), Some(n)) }
        .getOrElse((None, None))
      RideDto.fromDomain(
        r,
        clientName = clientMap.get(r.clientId).map(_.name),
        clientHasAvatar = clientMap.get(r.clientId).exists(_.avatarPresent),
        clientProvisional = clientMap.get(r.clientId).exists(_.provisional),
        driverRating = rating,
        driverRatingCount = count
      )
    }
  }

  private val getDriverRidesServer: ZServerEndpoint[RideEnv, Any] = getDriverRidesEndpoint.serverLogic {
    user => driverId =>
      for {
        driverPid    <- parsePersonId(driverId)
        _            <- checkRoleOrOwner(user, driverPid.value, "DISPATCHER")
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        personRepo   <- ZIO.service[PersonRepository]
        ratingRepo   <- ZIO.service[RideRatingRepository]
        rideRepo     <- ZIO.service[RideRepository]
        rides        <- service.getDriverRides(driverPid, companyId).mapError(fromRideError)
        clientIds     = rides.map(_.clientId).distinct
        persons      <- ZIO
                          .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                          .mapError(fromRideError)
        clientMap     = persons.collect { case (id, Some(p)) => id -> p }.toMap
        ratingStats  <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
        // Live flight gate/terminal/status (kept fresh by FlightStatusMonitor) for airport rides,
        // loaded in one bulk query so the driver "Today" cards show it without an N+1. Mirrors the
        // dispatcher "My Rides" endpoint (getRidesByDriversServer) which already enriches flight data.
        airportIds    = rides.filter(_.isAirportTransfer).map(_.id)
        flightMap    <- rideRepo.findFlightStatusFor(airportIds).mapError(fromRideError)
        timingConfig <- ZIO.service[AirportArrivalTimingConfig]
      } yield rides.map { r =>
        val (rating, count) = r.driverId
          .flatMap(ratingStats.get)
          .map { case (avg, n) => (Some(avg), Some(n)) }
          .getOrElse((None, None))
        val flight          = flightMap.get(r.id)
        RideDto.fromDomain(
          r,
          clientName = clientMap.get(r.clientId).map(_.name),
          clientHasAvatar = clientMap.get(r.clientId).exists(_.avatarPresent),
          clientProvisional = clientMap.get(r.clientId).exists(_.provisional),
          driverRating = rating,
          driverRatingCount = count,
          flight = flight,
          optimalEntryTime = optimalEntryFor(r, flight, timingConfig)
        )
      }
  }

  private val getClientRidesServer: ZServerEndpoint[RideEnv, Any] = getClientRidesEndpoint.serverLogic {
    user => clientId =>
      for {
        clientPid     <- parsePersonId(clientId)
        _             <- checkRoleOrOwner(user, clientPid.value, "DISPATCHER", "SECRETARY", "CLIENT_SECRETARY")
        companyId     <- requireCompanyId(user.companyId)
        service       <- ZIO.service[RideService]
        personRepo    <- ZIO.service[PersonRepository]
        ratingRepo    <- ZIO.service[RideRatingRepository]
        rides         <- service.getClientRides(clientPid, companyId).mapError(fromRideError)
        clientPerson  <- personRepo.findById(clientPid).mapError(fromRideError)
        // Resolve every distinct driver name once in parallel instead of one sequential
        // findById per ride (was N+1).
        driverIds      = rides.flatMap(_.driverId).distinct
        // Resolve each driver once (parallel) as a full Person so we can surface
        // both the name and whether they have a profile photo (avatarPresent).
        driverPersons <- ZIO
                           .foreachPar(driverIds)(id => personRepo.findById(id).map(p => id -> p))
                           .map(_.toMap)
                           .mapError(fromRideError)
        ratingStats   <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
        rideDtos       = rides.map { r =>
                           val driverPerson        = r.driverId.flatMap(driverPersons.getOrElse(_, None))
                           val (rating, rateCount) = r.driverId
                             .flatMap(ratingStats.get)
                             .map { case (avg, n) => (Some(avg), Some(n)) }
                             .getOrElse((None, None))
                           RideDto.fromDomain(
                             r,
                             clientName = clientPerson.map(_.name),
                             clientHasAvatar = clientPerson.exists(_.avatarPresent),
                             driverName = driverPerson.map(_.name),
                             driverHasAvatar = driverPerson.exists(_.avatarPresent),
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
        clientPerson <- personRepo.findById(ride.clientId).mapError(fromRideError)
      } yield RideDto.fromDomain(
        ride,
        clientName = clientPerson.map(_.name),
        clientHasAvatar = clientPerson.exists(_.avatarPresent),
        clientProvisional = clientPerson.exists(_.provisional)
      )
  }

  private val assignDriverServer: ZServerEndpoint[RideEnv, Any] = assignDriverEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _              <- checkRole(user, "DISPATCHER")
        validated      <- apiRequest.validate.mapError(fromRideError)
        parsedRideId   <- parseRideId(rideId)
        parsedDriverId <- parsePersonId(validated.driverId)
        companyId      <- requireCompanyId(user.companyId)
        service        <- ZIO.service[RideService]
        personRepo     <- ZIO.service[PersonRepository]
        existing       <- service.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: a dispatcher may only assign drivers to rides of their own company.
        // Hide cross-tenant rides as not found instead of leaking their existence.
        _              <- ZIO
                            .fail(RideError.RideNotFound(parsedRideId))
                            .when(existing.companyId != companyId)
                            .mapError(fromRideError)
        ride           <- service
                            .assignDriver(parsedRideId, parsedDriverId, validated.overrideScheduleConflict)
                            .mapError(fromRideError)
        clientPerson   <- personRepo.findById(ride.clientId).mapError(fromRideError)
      } yield RideDto.fromDomain(
        ride,
        clientName = clientPerson.map(_.name),
        clientHasAvatar = clientPerson.exists(_.avatarPresent),
        clientProvisional = clientPerson.exists(_.provisional)
      )
  }

  private val reassignDriverServer: ZServerEndpoint[RideEnv, Any] = reassignDriverEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _              <- checkRole(user, "DISPATCHER")
        validated      <- apiRequest.validate.mapError(fromRideError)
        parsedRideId   <- parseRideId(rideId)
        parsedDriverId <- parsePersonId(validated.driverId)
        companyId      <- requireCompanyId(user.companyId)
        service        <- ZIO.service[RideService]
        personRepo     <- ZIO.service[PersonRepository]
        existing       <- service.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: a dispatcher may only reassign drivers on rides of their own company.
        _              <- ZIO
                            .fail(RideError.RideNotFound(parsedRideId))
                            .when(existing.companyId != companyId)
                            .mapError(fromRideError)
        ride           <- service
                            .reassignDriver(parsedRideId, parsedDriverId, validated.overrideScheduleConflict)
                            .mapError(fromRideError)
        clientPerson   <- personRepo.findById(ride.clientId).mapError(fromRideError)
      } yield RideDto.fromDomain(
        ride,
        clientName = clientPerson.map(_.name),
        clientHasAvatar = clientPerson.exists(_.avatarPresent),
        clientProvisional = clientPerson.exists(_.provisional)
      )
  }

  private val updateRideServer: ZServerEndpoint[RideEnv, Any] = updateRideEndpoint.serverLogic {
    user => (rideId, apiRequest) =>
      for {
        _            <- checkRole(user, "DRIVER", "DISPATCHER", "SECRETARY", "CLIENT")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        validRequest <- apiRequest.validate.mapError(fromRideError)
        service      <- ZIO.service[RideService]
        personRepo   <- ZIO.service[PersonRepository]
        ride         <- service
                          .updateRideDetails(
                            parsedRideId,
                            UpdateRideDetailsApiRequest.toDomain(validRequest),
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            Some(companyId)
                          )
                          .mapError(fromRideError)
        clientPerson <- personRepo.findById(ride.clientId).mapError(fromRideError)
      } yield RideDto.fromDomain(
        ride,
        clientName = clientPerson.map(_.name),
        clientHasAvatar = clientPerson.exists(_.avatarPresent),
        clientProvisional = clientPerson.exists(_.provisional)
      )
  }

  private val getRideServer: ZServerEndpoint[RideEnv, Any] = getRideEndpoint.serverLogic { user => rideId =>
    for {
      _            <- checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY")
      parsedRideId <- parseRideId(rideId)
      service      <- ZIO.service[RideService]
      personRepo   <- ZIO.service[PersonRepository]
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
      clientPerson <- personRepo.findById(ride.clientId).mapError(fromRideError)
    } yield RideDto.fromDomain(
      ride,
      clientName = clientPerson.map(_.name),
      clientHasAvatar = clientPerson.exists(_.avatarPresent),
      clientProvisional = clientPerson.exists(_.provisional)
    )
  }

  private val refreshFlightServer: ZServerEndpoint[RideEnv, Any] = refreshFlightEndpoint.serverLogic { user => rideId =>
    for {
      // Anyone who works the ride and sees its card may trigger a refresh — it only re-reads the
      // public flight board and never mutates booking data.
      _            <- checkRole(user, "DISPATCHER", "DRIVER", "SECRETARY")
      parsedRideId <- parseRideId(rideId)
      companyId    <- requireCompanyId(user.companyId)
      service      <- ZIO.service[RideService]
      personRepo   <- ZIO.service[PersonRepository]
      rideRepo     <- ZIO.service[RideRepository]
      provider     <- ZIO.service[FlightStatusProvider]
      eventHub     <- ZIO.service[EventHub]
      ride         <- service.getRideById(parsedRideId).mapError(fromRideError)
      // Company isolation: hide cross-tenant rides as not found instead of leaking their existence.
      _            <- ZIO
                        .fail(RideError.RideNotFound(parsedRideId))
                        .when(ride.companyId != companyId)
                        .mapError(fromRideError)
      result       <- FlightStatusRefresher.refresh(ride, rideRepo, provider, eventHub).mapError(fromRideError)
      outcome       =
        result match
          case FlightStatusRefresher.RefreshResult.Updated(_) => "updated"
          case FlightStatusRefresher.RefreshResult.Unchanged  => "unchanged"
          case FlightStatusRefresher.RefreshResult.NotFound   => "notFound"
      // Re-read the persisted flight row so the response reflects the latest stored data (incl. an
      // unchanged or not-found case, where we still return the current row, not an empty one).
      flightRow    <- rideRepo.findFlightStatus(parsedRideId).mapError(fromRideError)
      clientPerson <- personRepo.findById(ride.clientId).mapError(fromRideError)
    } yield RefreshFlightResponse(
      ride = RideDto.fromDomain(
        ride,
        flight = flightRow,
        clientName = clientPerson.map(_.name),
        clientHasAvatar = clientPerson.exists(_.avatarPresent),
        clientProvisional = clientPerson.exists(_.provisional)
      ),
      outcome = outcome
    )
  }

  /**
   * GPS-free recommended terminal-entry instant ("Einfahrt um") for a ride, for list cards. Only airport ARRIVAL rides
   * get a value; everything else is None. The arrival time prefers the live flight time over the booking's scheduled
   * time; the gate (else terminal) from the live flight row selects the satellite vs normal walk buffer.
   */
  private def optimalEntryFor(
      ride: Ride,
      flight: Option[FlightStatusRow],
      config: AirportArrivalTimingConfig
  ): Option[java.time.Instant] =
    if !ride.isArrivalAirportTransfer then None
    else
      val arrivalTime = flight.flatMap(_.flightTime).orElse(ride.scheduledTime)
      AirportTimingService.arrivalOptimalEntry(arrivalTime, flight.flatMap(_.gate), flight.flatMap(_.terminal), config)

  private def fromAirportTimingError(error: AirportTimingService.Error): Err =
    error match
      case AirportTimingService.Error.NotFound              => (StatusCode.NotFound, ApiError("Ride not found"))
      case AirportTimingService.Error.NotAnAirportTransfer  =>
        (StatusCode.BadRequest, ApiError("Ride is not an airport transfer"))
      case AirportTimingService.Error.SettingsLoadFailed(_) =>
        (StatusCode.InternalServerError, ApiError("Internal server error"))

  private val airportTimingServer: ZServerEndpoint[RideEnv, Any] = airportTimingEndpoint.serverLogic {
    user => (rideId, request) =>
      for {
        _             <- checkRole(user, "CLIENT", "DRIVER", "DISPATCHER")
        parsedRideId  <- parseRideId(rideId)
        companyId     <- requireCompanyId(user.companyId)
        service       <- ZIO.service[AirportTimingService]
        fallbackCoords =
          (request.driverLatitude, request.driverLongitude) match
            case (Some(lat), Some(lng)) => Some((lat, lng))
            case _                      => None
        result        <- service
                           .compute(parsedRideId, companyId, fallbackCoords)
                           .mapError(fromAirportTimingError)
        body           =
          s"""{
            "optimalEntryTime": "${result.optimalEntryTime}",
            "latestEntryTime": "${result.latestEntryTime}",
            "travelTimeMinutes": ${result.travelMinutes},
            "bufferTimeMinutes": ${result.walkBufferMinutes},
            "optimalParkingCost": ${result.optimalParkingCost},
            "earlyEntryParkingCost": ${result.earlyEntryParkingCost},
            "savings": ${result.savings},
            "flightStatus": "${result.flightStatus}",
            "actualArrivalTime": "${result.actualArrivalTime}",
            "timeToDepartMinutes": ${result.timeToDepartMinutes}
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
        validated    <- cancelReq.validate.mapError(fromRideError)
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        ride         <- service
                          .cancelRideWithReason(
                            parsedRideId,
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            CancelRideRequest(validated.reason, validated.fee.map(BigDecimal(_))),
                            companyId
                          )
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val handOffRideServer: ZServerEndpoint[RideEnv, Any] = handOffRideEndpoint.serverLogic {
    user => (rideId, req) =>
      for {
        _                <- checkRole(user, "DISPATCHER", "ADMIN")
        parsedRideId     <- parseRideId(rideId)
        companyId        <- requireCompanyId(user.companyId)
        externalDriverId <- ZIO
                              .attempt(java.util.UUID.fromString(req.externalDriverId))
                              .mapError(_ =>
                                (sttp.model.StatusCode.BadRequest, ApiError("Invalid externalDriverId UUID"))
                              )
                              .map(ExternalDriverId.apply)
        partnerCompanyId <- ZIO
                              .attempt(java.util.UUID.fromString(req.partnerCompanyId))
                              .mapError(_ =>
                                (sttp.model.StatusCode.BadRequest, ApiError("Invalid partnerCompanyId UUID"))
                              )
                              .map(PartnerCompanyId.apply)
        service          <- ZIO.service[RideService]
        ride             <- service
                              .handOffToExternal(
                                parsedRideId,
                                companyId,
                                PersonId(user.userId),
                                HandOffRequest(externalDriverId, partnerCompanyId)
                              )
                              .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val listRidesServer: ZServerEndpoint[RideEnv, Any] = listRidesEndpoint.serverLogic {
    user => (offsetOpt, limitOpt) =>
      for {
        companyId    <- requireCompanyId(user.companyId)
        offset        = Paging.clampOffset(offsetOpt.getOrElse(0))
        limit         = Paging.clampLimit(limitOpt.getOrElse(50))
        service      <- ZIO.service[RideService]
        personRepo   <- ZIO.service[PersonRepository]
        ratingRepo   <- ZIO.service[RideRatingRepository]
        rideRepo     <- ZIO.service[RideRepository]
        rides        <- service.getRidesByCompanyPaginated(companyId, offset, limit).mapError(fromRideError)
        clientIds     = rides.map(_.clientId).distinct
        persons      <- ZIO
                          .foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p))
                          .mapError(fromRideError)
        clientMap     = persons.collect { case (id, Some(p)) => id -> p }.toMap
        ratingStats  <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
        // Live flight gate/terminal/status (kept fresh by FlightStatusMonitor) for airport rides,
        // loaded in one bulk query so the dispatcher schedule/list can show the gate without an N+1.
        airportIds    = rides.filter(_.isAirportTransfer).map(_.id)
        flightMap    <- rideRepo.findFlightStatusFor(airportIds).mapError(fromRideError)
        timingConfig <- ZIO.service[AirportArrivalTimingConfig]
      } yield rides.map { r =>
        val (rating, count) = r.driverId
          .flatMap(ratingStats.get)
          .map { case (avg, n) => (Some(avg), Some(n)) }
          .getOrElse((None, None))
        val flight          = flightMap.get(r.id)
        RideDto.fromDomain(
          r,
          clientName = clientMap.get(r.clientId).map(_.name),
          clientHasAvatar = clientMap.get(r.clientId).exists(_.avatarPresent),
          clientProvisional = clientMap.get(r.clientId).exists(_.provisional),
          driverRating = rating,
          driverRatingCount = count,
          flight = flight,
          optimalEntryTime = optimalEntryFor(r, flight, timingConfig)
        )
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
        // Participation: only the ride's client, its assigned driver or staff may write to its chat.
        _            <- checkRideParticipant(user, ride)
        service      <- ZIO.service[ChatService]
        msg          <- service.sendMessage(parsedRideId, PersonId(user.userId), chatReq.message).mapError(fromChatError)
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
        // Participation: only the ride's client, its assigned driver or staff may read its chat.
        _            <- checkRideParticipant(user, ride)
        service      <- ZIO.service[ChatService]
        messages     <- service.getMessages(parsedRideId).mapError(fromChatError)
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

  // -- driver confirmation servers -----------------------------------------

  private val confirmRideServer: ZServerEndpoint[RideEnv, Any] = confirmRideEndpoint.serverLogic { user => rideId =>
    for {
      _            <- checkRole(user, "DRIVER")
      parsedRideId <- parseRideId(rideId)
      companyId    <- requireCompanyId(user.companyId)
      service      <- ZIO.service[RideService]
      existing     <- service.getRideById(parsedRideId).mapError(fromRideError)
      // Company isolation: hide cross-tenant rides as 404.
      _            <- ZIO
                        .fail(RideError.RideNotFound(parsedRideId))
                        .when(existing.companyId != companyId)
                        .mapError(fromRideError)
      ride         <- service.confirmRide(parsedRideId, PersonId(user.userId)).mapError(fromRideError)
    } yield RideDto.fromDomain(ride)
  }

  private val rejectRideServer: ZServerEndpoint[RideEnv, Any] = rejectRideEndpoint.serverLogic {
    user => (rideId, rejectReq) =>
      for {
        _            <- checkRole(user, "DRIVER")
        parsedRideId <- parseRideId(rideId)
        validated    <- rejectReq.validate.mapError(fromRideError)
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        existing     <- service.getRideById(parsedRideId).mapError(fromRideError)
        // Company isolation: hide cross-tenant rides as 404.
        _            <- ZIO
                          .fail(RideError.RideNotFound(parsedRideId))
                          .when(existing.companyId != companyId)
                          .mapError(fromRideError)
        ride         <- service
                          .rejectRide(parsedRideId, PersonId(user.userId), validated.reason)
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
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
        checkpointName = ride.airportCheckpoint.map(AirportCheckpoint.defaultDisplayName)
      )
  }

  // -- estimate server -----------------------------------------------------

  // Estimation logic (Haversine distance + 50 km/h duration + tariff lookup) lives in the
  // application-layer RideEstimateService; the handler only maps role/companyId/DTO ↔ domain.
  private val estimateRideServer: ZServerEndpoint[RideEnv, Any] = estimateRideEndpoint.serverLogic { user => req =>
    for {
      _           <- checkRole(user, "DRIVER", "CLIENT", "DISPATCHER", "SECRETARY", "ADMIN")
      companyId   <- requireCompanyId(user.companyId)
      service     <- ZIO.service[RideEstimateService]
      geocoding   <- ZIO.service[GeocodingService]
      vehicleClass = VehicleClass.fromString(req.vehicleClass).getOrElse(VehicleClass.Default)
      pickupTime   = req.pickupDateTime.flatMap(s => scala.util.Try(java.time.Instant.parse(s)).toOption)
      // The client sends free-text addresses without coordinates; geocode them here (same
      // enrichLocation flow RideService.createRide uses) so distance/price can be computed.
      from        <- geocoding
                       .enrichLocation(LocationDto.toDomain(req.from))
                       .orElse(ZIO.succeed(LocationDto.toDomain(req.from)))
      to          <- geocoding
                       .enrichLocation(LocationDto.toDomain(req.to))
                       .orElse(ZIO.succeed(LocationDto.toDomain(req.to)))
      result      <- service
                       .estimate(
                         companyId,
                         from,
                         to,
                         vehicleClass,
                         req.isAirportTransfer,
                         pickupTime
                       )
                       .mapError {
                         case RideEstimateService.EstimateError.MissingCoordinates(field) =>
                           (StatusCode.BadRequest, ApiError(s"$field is required for estimation"))
                         case RideEstimateService.EstimateError.TariffLoadFailed(_)       =>
                           (StatusCode.InternalServerError, ApiError("Failed to load tariff"))
                       }
    } yield EstimateRideResponse(
      distanceKm = result.distanceKm.doubleValue,
      durationMinutes = result.durationMinutes,
      estimatedPrice = result.estimatedPrice.doubleValue,
      currency = result.currency
    )
  }

  private val setRidePriceServer: ZServerEndpoint[RideEnv, Any] = setRidePriceEndpoint.serverLogic {
    user => (rideId, priceReq) =>
      for {
        _            <- checkRole(user, "DISPATCHER", "DRIVER")
        parsedRideId <- parseRideId(rideId)
        companyId    <- requireCompanyId(user.companyId)
        service      <- ZIO.service[RideService]
        ride         <- service
                          .setRidePrice(
                            parsedRideId,
                            priceReq.price,
                            PersonId(user.userId),
                            toPersonRole(user.role),
                            companyId
                          )
                          .mapError(fromRideError)
      } yield RideDto.fromDomain(ride)
  }

  private val getRidesByDriversServer: ZServerEndpoint[RideEnv, Any] = getRidesByDriversEndpoint.serverLogic {
    user => (driverIdsStr, fromDateOpt, toDateOpt) =>
      for {
        _            <- checkRole(user, "DISPATCHER", "DRIVER")
        companyId    <- requireCompanyId(user.companyId)
        // Parse comma-separated driver IDs — request-parsing concern stays in the handler.
        // Cap to 10 to guard against DoS via very long ID lists.
        driverPids   <-
          ZIO
            .foreach(
              driverIdsStr
                .split(",")
                .map(_.trim)
                .filter(_.nonEmpty)
                .take(10)
                .toList
            )(parsePersonId)
        service      <- ZIO.service[RideService]
        personRepo   <- ZIO.service[PersonRepository]
        ratingRepo   <- ZIO.service[RideRatingRepository]
        rideRepo     <- ZIO.service[RideRepository]
        // Business logic (parallel fetch + date-filter) lives in the service layer.
        filtered     <- service.getRidesByDrivers(driverPids, fromDateOpt, toDateOpt, companyId).mapError(fromRideError)
        // DTO enrichment: client names and per-driver rating stats (presentational, not business logic).
        // Resolve both client and driver Persons in one bulk fetch so the cards
        // can show each one's name and profile photo (avatarPresent) without N+1.
        peopleIds     = (filtered.map(_.clientId) ++ filtered.flatMap(_.driverId)).distinct
        persons      <- ZIO
                          .foreachPar(peopleIds)(id => personRepo.findById(id).map(p => id -> p))
                          .mapError(fromRideError)
        personMap     = persons.collect { case (id, Some(p)) => id -> p }.toMap
        clientMap     = personMap
        ratingStats  <- ratingRepo.driverRatingStatsByCompany(companyId).mapError(fromRideError)
        // Live flight gate/terminal/status (kept fresh by FlightStatusMonitor) for airport rides,
        // loaded in one bulk query so the dispatcher "My Rides" cards can show it without an N+1.
        airportIds    = filtered.filter(_.isAirportTransfer).map(_.id)
        flightMap    <- rideRepo.findFlightStatusFor(airportIds).mapError(fromRideError)
        timingConfig <- ZIO.service[AirportArrivalTimingConfig]
      } yield filtered.map { r =>
        val (rating, count) = r.driverId
          .flatMap(ratingStats.get)
          .map { case (avg, n) => (Some(avg), Some(n)) }
          .getOrElse((None, None))
        val flight          = flightMap.get(r.id)
        RideDto.fromDomain(
          r,
          clientName = clientMap.get(r.clientId).map(_.name),
          clientHasAvatar = clientMap.get(r.clientId).exists(_.avatarPresent),
          clientProvisional = clientMap.get(r.clientId).exists(_.provisional),
          driverName = r.driverId.flatMap(personMap.get).map(_.name),
          driverHasAvatar = r.driverId.flatMap(personMap.get).exists(_.avatarPresent),
          driverRating = rating,
          driverRatingCount = count,
          flight = flight,
          optimalEntryTime = optimalEntryFor(r, flight, timingConfig)
        )
      }
  }

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
    handOffRideServer,
    updateRideServer,
    // Literal-path endpoints must precede generic path[String] endpoints so that
    // Tapir does not absorb them into the dynamic-segment handler first.
    estimateRideServer,
    setRidePriceServer,
    getRidesByDriversServer,
    getRideServer,
    refreshFlightServer,
    listRidesServer,
    updateClientLocationServer,
    getRideLocationsServer,
    sendChatMessageServer,
    getChatMessagesServer,
    rateRideServer,
    getRatingServer,
    confirmRideServer,
    rejectRideServer,
    markAirportCheckpointServer,
    getAirportCheckpointServer
  )
