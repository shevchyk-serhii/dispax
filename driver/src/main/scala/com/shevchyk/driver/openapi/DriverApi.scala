package com.shevchyk.driver.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.{DriverLocationService, EtaService}
import com.shevchyk.driver.infrastructure.http.{
  AvailableDriverDto,
  DriverEarningsDto,
  DriverProximityDto,
  EarningsBucketDto,
  UpdateAvailabilityRequest,
  UpdateLocationRequest
}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{DriverEarningsReport, EarningsPeriod}
import com.shevchyk.ride.infrastructure.http.dto.RideDto
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.util.UUID

/**
 * Tapir descriptions and server logic for the driver endpoints. These replace the hand-written zio-http handlers in
 * `DriverRoutes` while keeping the exact same paths, request/response shapes, status codes, role checks and company
 * isolation. The same `ServerEndpoint`s drive both the OpenAPI document and the running server.
 *
 * Like the other modules, this uses a local authenticated base endpoint with a `(StatusCode, ApiError)` error channel
 * so each failure maps to the precise HTTP status the old handler returned (e.g. cross-tenant driver → 404, invalid
 * status → 400). A shared `oneOf[ApiError]` base cannot do this because all variants share the same body and Tapir
 * would always pick the first one.
 */
object DriverApi:

  private val driverTag = "Drivers"

  /**
   * Response body for `GET /api/drivers/{driverId}/availability` — mirrors the old `{"status":"..."}` JSON.
   */
  final case class AvailabilityResponse(status: String) derives zio.json.JsonCodec

  object AvailabilityResponse:
    given Schema[AvailabilityResponse] = Schema.derived[AvailabilityResponse]

  // -- Environment ---------------------------------------------------------
  type DriverEnv = DriverLocationService & RideService & EtaService & GeocodingService & PersonRepository & JwtService

  private[openapi] type Err = (StatusCode, ApiError)

  // -- Authenticated base endpoint (mirrors AuthMiddleware.authenticateRequest) --
  private val secureEndpoint = endpoint
    .securityIn(auth.bearer[String]())
    .errorOut(statusCode.and(jsonBody[ApiError]))
    .zServerSecurityLogic[JwtService, AuthenticatedUser] { token =>
      ZIO
        .serviceWithZIO[JwtService](_.validateToken(token))
        .mapBoth(
          {
            case _: InvalidTokenError | _: ExpiredTokenError =>
              (StatusCode.Unauthorized, ApiError("Invalid or expired token"))
            case _: JwtError                                 => (StatusCode.Unauthorized, ApiError("Authentication failed"))
          },
          payload =>
            val wireRoles = payload.roles
              .map(_.map(PersonRole.toWire).toSet)
              .getOrElse(Set(PersonRole.toWire(payload.role)))
            AuthenticatedUser(
              userId = payload.userId,
              email = payload.email,
              role = PersonRole.toWire(payload.role),
              companyId = payload.companyId,
              clientCompanyId = payload.clientCompanyId,
              roles = wireRoles
            )
        )
    }

  // -- Helpers (replicate AuthMiddleware / UuidParser behaviour) -----------

  private val internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  private def parseUuid(value: String): ZIO[Any, Err, UUID] = ZIO
    .attempt(UUID.fromString(value))
    .orElseFail((StatusCode.BadRequest, ApiError("Invalid UUID format")))

  private def requireCompanyId(companyIdOpt: Option[UUID]): ZIO[Any, Err, CompanyId] = ZIO
    .fromOption(companyIdOpt)
    .map(CompanyId(_))
    .orElseFail((StatusCode.BadRequest, ApiError("User must belong to a company")))

  private[openapi] def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    if user.hasAnyRole(roles*) then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))

  private[openapi] def checkRoleOrOwner(
      user: AuthenticatedUser,
      resourceOwnerId: UUID,
      roles: String*
  ): ZIO[Any, Err, Unit] =
    if user.hasAnyRole(roles*) || user.userId == resourceOwnerId then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Access denied")))

  // Company isolation: ensure the target driver belongs to the caller's company.
  // Hide cross-tenant (or unknown) drivers as NotFound so existence is not revealed.
  private def assertDriverInCompany(
      driverUuid: UUID,
      companyId: CompanyId
  ): ZIO[PersonRepository, Err, Unit] =
    for {
      personRepo <- ZIO.service[PersonRepository]
      driver     <- personRepo.findById(PersonId(driverUuid)).orElseFail(internalError)
      _          <- ZIO.fail((StatusCode.NotFound, ApiError("Not found"))).when(!driver.exists(_.companyId.contains(companyId)))
    } yield ()

  private def toEarningsDto(report: DriverEarningsReport): DriverEarningsDto = DriverEarningsDto(
    period = report.period.toString.toLowerCase,
    grossRevenue = report.grossRevenue.toDouble,
    totalExpenses = report.totalExpenses.toDouble,
    netRevenue = report.netRevenue.toDouble,
    completedRides = report.completedRides,
    cancelledRides = report.cancelledRides,
    avgFare = report.avgFare.toDouble,
    currency = "EUR",
    buckets = report.buckets.map(b => EarningsBucketDto(b.bucketStart.toString, b.amount.toDouble))
  )

  // -- Endpoint descriptions -----------------------------------------------

  val updateLocationEndpoint = secureEndpoint.put
    .in("api" / "drivers" / path[String]("driverId") / "location")
    .in(jsonBody[UpdateLocationRequest])
    .out(statusCode(StatusCode.NoContent))
    .tag(driverTag)
    .summary("Update a driver's current location")

  val updateAvailabilityEndpoint = secureEndpoint.put
    .in("api" / "drivers" / path[String]("driverId") / "availability")
    .in(jsonBody[UpdateAvailabilityRequest])
    .out(statusCode(StatusCode.NoContent))
    .tag(driverTag)
    .summary("Update a driver's availability status")

  val getAvailabilityEndpoint = secureEndpoint.get
    .in("api" / "drivers" / path[String]("driverId") / "availability")
    .out(jsonBody[AvailabilityResponse])
    .tag(driverTag)
    .summary("Get a driver's availability status")

  val getEarningsEndpoint = secureEndpoint.get
    .in("api" / "drivers" / path[String]("driverId") / "earnings")
    .in(query[Option[String]]("period"))
    .in(query[Option[String]]("date"))
    .out(jsonBody[DriverEarningsDto])
    .tag(driverTag)
    .summary("Get a driver's earnings report")

  val getAvailableDriversEndpoint = secureEndpoint.get
    .in("api" / "drivers" / "available")
    .out(jsonBody[List[AvailableDriverDto]])
    .tag(driverTag)
    .summary("List available drivers for the company")

  val getRideDriverLocationEndpoint = secureEndpoint.get
    .in("api" / "rides" / path[String]("rideId") / "driver-location")
    .out(jsonBody[DriverProximityDto])
    .tag(driverTag)
    .summary("Get driver proximity/ETA for a ride")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    updateLocationEndpoint,
    updateAvailabilityEndpoint,
    getAvailabilityEndpoint,
    getEarningsEndpoint,
    getAvailableDriversEndpoint,
    getRideDriverLocationEndpoint
  )

  // -- Server logic --------------------------------------------------------

  private val updateLocationServer: ZServerEndpoint[DriverEnv, Any] = updateLocationEndpoint.serverLogic {
    user => (driverId, req) =>
      for {
        driverUuid <- parseUuid(driverId)
        _          <- checkRoleOrOwner(user, driverUuid, "DISPATCHER")
        companyId  <- requireCompanyId(user.companyId)
        _          <- assertDriverInCompany(driverUuid, companyId)
        _          <- ZIO
                        .serviceWithZIO[DriverLocationService](
                          _.updateLocation(PersonId(driverUuid), req.latitude, req.longitude)
                        )
                        .orElseFail(internalError)
      } yield ()
  }

  private val updateAvailabilityServer: ZServerEndpoint[DriverEnv, Any] = updateAvailabilityEndpoint.serverLogic {
    user => (driverId, req) =>
      for {
        driverUuid <- parseUuid(driverId)
        _          <- checkRoleOrOwner(user, driverUuid, "DISPATCHER")
        companyId  <- requireCompanyId(user.companyId)
        _          <- assertDriverInCompany(driverUuid, companyId)
        _          <- ZIO
                        .fail((StatusCode.BadRequest, ApiError("Invalid status. Use 'Available' or 'Offline'")))
                        .when(req.status != "Available" && req.status != "Offline")
        _          <- ZIO
                        .serviceWithZIO[DriverLocationService](_.updateAvailability(PersonId(driverUuid), req.status))
                        .orElseFail(internalError)
      } yield ()
  }

  private val getAvailabilityServer: ZServerEndpoint[DriverEnv, Any] = getAvailabilityEndpoint.serverLogic {
    user => driverId =>
      for {
        driverUuid <- parseUuid(driverId)
        _          <- checkRoleOrOwner(user, driverUuid, "DISPATCHER", "SECRETARY")
        companyId  <- requireCompanyId(user.companyId)
        _          <- assertDriverInCompany(driverUuid, companyId)
        status     <- ZIO
                        .serviceWithZIO[DriverLocationService](_.getAvailability(PersonId(driverUuid)))
                        .orElseFail(internalError)
      } yield AvailabilityResponse(status.getOrElse("Offline"))
  }

  private val getEarningsServer: ZServerEndpoint[DriverEnv, Any] = getEarningsEndpoint.serverLogic {
    user => (driverId, periodOpt, dateOpt) =>
      for {
        driverUuid <- parseUuid(driverId)
        _          <- checkRoleOrOwner(user, driverUuid, "DISPATCHER")
        companyId  <- requireCompanyId(user.companyId)
        periodStr   = periodOpt.getOrElse("week")
        period     <- ZIO
                        .fromOption(EarningsPeriod.fromString(periodStr))
                        .orElseFail((StatusCode.BadRequest, ApiError("Invalid period. Use 'day', 'week' or 'month'")))
        anchorDate <- ZIO
                        .attempt(dateOpt.map(java.time.LocalDate.parse).getOrElse(java.time.LocalDate.now()))
                        .orElseFail((StatusCode.BadRequest, ApiError("Invalid date. Use ISO format YYYY-MM-DD")))
        report     <- ZIO
                        .serviceWithZIO[RideService](
                          _.getDriverEarnings(PersonId(driverUuid), companyId, period, anchorDate)
                        )
                        .orElseFail(internalError)
      } yield toEarningsDto(report)
  }

  private val getAvailableDriversServer: ZServerEndpoint[DriverEnv, Any] = getAvailableDriversEndpoint.serverLogic {
    user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY")
        companyId <- requireCompanyId(user.companyId)
        drivers   <- ZIO
                       .serviceWithZIO[DriverLocationService](_.getAvailableDrivers(companyId))
                       .orElseFail(internalError)
      } yield drivers
  }

  private val getRideDriverLocationServer: ZServerEndpoint[DriverEnv, Any] = getRideDriverLocationEndpoint.serverLogic {
    user => rideId =>
      for {
        companyId    <- requireCompanyId(user.companyId)
        parsedRideId <- parseUuid(rideId).map(RideId(_))
        rideService  <- ZIO.service[RideService]
        ride0        <- rideService.getRideById(parsedRideId).orElseFail(internalError)
        // Company isolation: hide cross-tenant rides as not found.
        _            <- ZIO.fail(internalError).when(ride0.companyId != companyId)
        // Participation guard (IDOR): the live driver position is only for the ride's parties.
        // Staff (dispatcher/admin/secretary/super-admin) always; a CLIENT only for their own ride;
        // a DRIVER only for a ride they are assigned to. Otherwise 403 — a plain company member must
        // not track the driver of a ride they have nothing to do with.
        callerId      = PersonId(user.userId)
        isStaff       = user.hasAnyRole("DISPATCHER", "ADMIN", "SECRETARY", "SUPER_ADMIN")
        isParty       = ride0.clientId == callerId || ride0.driverId.contains(callerId)
        _            <- ZIO
                          .fail((StatusCode.Forbidden, ApiError("You are not a party to this ride")))
                          .when(!isStaff && !isParty)
        // Lazy geocoding: enrich pickup coords for old rides that have none
        ride         <-
          if ride0.pickupLocation.latitude.isEmpty then
            ZIO
              .serviceWithZIO[GeocodingService](_.enrichLocation(ride0.pickupLocation))
              .flatMap { enriched =>
                if enriched.latitude.isDefined then
                  rideService
                    .updateRideDetails(
                      parsedRideId,
                      com.shevchyk.ride.domain.UpdateRideDetailsRequest(pickupLocation = Some(enriched)),
                      PersonId(user.userId),
                      PersonRole.fromWire(user.role).getOrElse(PersonRole.Client),
                      Some(companyId)
                    )
                    .orElse(ZIO.succeed(ride0.copy(pickupLocation = enriched)))
                else ZIO.succeed(ride0)
              }
              .orElse(ZIO.succeed(ride0))
          else ZIO.succeed(ride0)
        locService   <- ZIO.service[DriverLocationService]
        driverLoc    <-
          (ride.driverId match {
            case Some(dId) => locService.getLocation(dId)
            case None      => ZIO.none
          }).orElseFail(internalError)
        rideDto       = RideDto.fromDomain(
                          ride,
                          driverLat = driverLoc.map(_.latitude),
                          driverLng = driverLoc.map(_.longitude)
                        )
        // ETA assembly is delegated to EtaService — the single source of truth for
        // origin/destination resolution (client live position first, else pickup
        // coords) and the HERE-with-Haversine-fallback computation. It returns no
        // ETA when either destination coordinate is missing instead of computing
        // one against a fake 0.0 coordinate.
        eta          <- ZIO.serviceWithZIO[EtaService](_.etaForRide(ride)).orElseFail(internalError)
        proximity     = DriverProximityDto(
                          driverLocation = rideDto.driverLocation,
                          driverApproaching = rideDto.driverApproaching,
                          driverDistanceMeters = rideDto.driverDistanceMeters,
                          etaMinutes = eta
                        )
      } yield proximity
  }

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[DriverEnv, Any]] = List(
    updateLocationServer,
    updateAvailabilityServer,
    getAvailabilityServer,
    getEarningsServer,
    getAvailableDriversServer,
    getRideDriverLocationServer
  )
