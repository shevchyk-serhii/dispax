package com.shevchyk.driver.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole, RideId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
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
import com.shevchyk.ride.repository.ClientLocationRepository
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
  type DriverEnv =
    DriverLocationService & RideService & HereRoutingService & GeocodingService & ClientLocationRepository &
      PersonRepository & JwtService

  private type Err = (StatusCode, ApiError)

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
            case _                                           => (StatusCode.InternalServerError, ApiError("Internal server error"))
          },
          payload =>
            AuthenticatedUser(
              userId = payload.userId,
              email = payload.email,
              role = payload.role.toString,
              companyId = payload.companyId,
              clientCompanyId = payload.clientCompanyId
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

  private def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if roles.exists(_.toUpperCase == userRoleUpper) then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))

  private def checkRoleOrOwner(
      user: AuthenticatedUser,
      resourceOwnerId: UUID,
      roles: String*
  ): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if roles.exists(_.toUpperCase == userRoleUpper) || user.userId == resourceOwnerId then ZIO.unit
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

  // Fallback ETA estimate when HERE API key is not configured (~50 km/h urban speed)
  private def estimateEtaMinutes(dLat: Double, dLng: Double, pickLat: Double, pickLng: Double): Option[Int] =
    val R     = 6371000.0
    val dPhi  = math.toRadians(pickLat - dLat)
    val dLam  = math.toRadians(pickLng - dLng)
    val a     =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(math.toRadians(dLat)) * math.cos(math.toRadians(pickLat)) *
        math.sin(dLam / 2) * math.sin(dLam / 2)
    val distM = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    val eta   = math.ceil(distM / (50000.0 / 60.0)).toInt
    Some(math.max(1, eta))

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
                      PersonRole.valueOf(user.role)
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
        clientLoc    <- ZIO.serviceWithZIO[ClientLocationRepository](_.getLocation(parsedRideId)).orElse(ZIO.none)
        eta          <-
          (for {
            dLat   <- driverLoc.map(_.latitude)
            dLng   <- driverLoc.map(_.longitude)
            destLat = clientLoc.map(_.latitude).getOrElse(ride.pickupLocation.latitude.getOrElse(0.0))
            destLng = clientLoc.map(_.longitude).getOrElse(ride.pickupLocation.longitude.getOrElse(0.0))
            if destLat != 0.0 || destLng != 0.0
          } yield (dLat, dLng, destLat, destLng)) match {
            case Some((dLat, dLng, destLat, destLng)) =>
              ZIO
                .serviceWithZIO[HereRoutingService](_.getEtaMinutes(dLat, dLng, destLat, destLng))
                .map(_.orElse(estimateEtaMinutes(dLat, dLng, destLat, destLng)))
                .orElseFail(internalError)
            case None                                 => ZIO.none
          }
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
