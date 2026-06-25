package com.shevchyk.driver.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, PersonRole}
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.{DriverLocationService, EtaService}
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{DriverEarningsReport, EarningsPeriod}
import com.shevchyk.ride.infrastructure.http.dto.{LocationDto, RideDto}
import sttp.tapir.Schema
import zio.*
import zio.http.*
import zio.json.*

case class UpdateLocationRequest(
    latitude: Double,
    longitude: Double
) derives JsonCodec

object UpdateLocationRequest:
  given Schema[UpdateLocationRequest] = Schema.derived[UpdateLocationRequest]

case class UpdateAvailabilityRequest(
    status: String
) derives JsonCodec

object UpdateAvailabilityRequest:
  given Schema[UpdateAvailabilityRequest] = Schema.derived[UpdateAvailabilityRequest]

case class AvailableDriverDto(
    id: String,
    status: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec

object AvailableDriverDto:
  given Schema[AvailableDriverDto] = Schema.derived[AvailableDriverDto]

case class DriverProximityDto(
    driverLocation: Option[LocationDto] = None,
    driverApproaching: Boolean = false,
    driverDistanceMeters: Option[Int] = None,
    etaMinutes: Option[Int] = None
) derives JsonCodec

object DriverProximityDto:
  given Schema[DriverProximityDto] = Schema.derived[DriverProximityDto]

case class EarningsBucketDto(
    bucketStart: String,
    amount: Double
) derives JsonCodec

object EarningsBucketDto:
  given Schema[EarningsBucketDto] = Schema.derived[EarningsBucketDto]

case class DriverEarningsDto(
    period: String,
    grossRevenue: Double,
    totalExpenses: Double,
    netRevenue: Double,
    completedRides: Int,
    cancelledRides: Int,
    avgFare: Double,
    currency: String,
    buckets: List[EarningsBucketDto]
) derives JsonCodec

object DriverEarningsDto:
  given Schema[DriverEarningsDto] = Schema.derived[DriverEarningsDto]

object DriverRoutes:

  // Company isolation: ensure the target driver belongs to the caller's company.
  // Hide cross-tenant (or unknown) drivers as NotFound so existence is not revealed.
  private def assertDriverInCompany(
      driverUuid: java.util.UUID,
      companyId: com.shevchyk.core.domain.CompanyId
  ): ZIO[PersonRepository, Response, Unit] =
    for {
      personRepo <- ZIO.service[PersonRepository]
      driver     <- personRepo
                      .findById(PersonId(driverUuid))
                      .mapError(_ => Response.status(Status.InternalServerError))
      _          <- ZIO
                      .fail(Response.status(Status.NotFound))
                      .when(!driver.exists(_.companyId.contains(companyId)))
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

  val authenticatedRoutes
      : Routes[DriverLocationService & RideService & EtaService & GeocodingService & PersonRepository & JwtService, Response]     =
    Routes(
      Method.PUT / "api" / "drivers" / string("driverId") / "location"     -> handler {
        (driverId: String, request: Request) =>
          (for {
            user       <- AuthMiddleware.authenticateRequest(request)
            driverUuid <- UuidParser.parse(driverId)
            _          <- AuthMiddleware.checkRoleOrOwner(user, driverUuid, "DISPATCHER")
            companyId  <- UuidParser.requireCompanyId(user.companyId)
            _          <- assertDriverInCompany(driverUuid, companyId)
            bodyStr    <- request.body.asString
            locReq     <- ZIO
                            .fromEither(bodyStr.fromJson[UpdateLocationRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
            service    <- ZIO.service[DriverLocationService]
            _          <- service.updateLocation(
                            PersonId(driverUuid),
                            locReq.latitude,
                            locReq.longitude
                          )
          } yield Response(Status.NoContent)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      =>
              ZIO
                .logError(s"Unhandled error: ${ex.getMessage}")
                .as(
                  Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
                )
          }
      },
      Method.PUT / "api" / "drivers" / string("driverId") / "availability" -> handler {
        (driverId: String, request: Request) =>
          (for {
            user       <- AuthMiddleware.authenticateRequest(request)
            driverUuid <- UuidParser.parse(driverId)
            _          <- AuthMiddleware.checkRoleOrOwner(user, driverUuid, "DISPATCHER")
            companyId  <- UuidParser.requireCompanyId(user.companyId)
            _          <- assertDriverInCompany(driverUuid, companyId)
            bodyStr    <- request.body.asString
            req        <- ZIO
                            .fromEither(bodyStr.fromJson[UpdateAvailabilityRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
            _          <- ZIO
                            .fail(new RuntimeException("Invalid status. Use 'Available' or 'Offline'"))
                            .when(req.status != "Available" && req.status != "Offline")
            service    <- ZIO.service[DriverLocationService]
            _          <- service.updateAvailability(PersonId(driverUuid), req.status)
          } yield Response(Status.NoContent)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      =>
              ZIO
                .logError(s"Unhandled error: ${Option(ex.getMessage).getOrElse(ex.toString)}")
                .as(
                  Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
                )
          }
      },
      Method.GET / "api" / "drivers" / string("driverId") / "availability" -> handler {
        (driverId: String, request: Request) =>
          (for {
            user       <- AuthMiddleware.authenticateRequest(request)
            driverUuid <- UuidParser.parse(driverId)
            _          <- AuthMiddleware.checkRoleOrOwner(user, driverUuid, "DISPATCHER", "SECRETARY")
            companyId  <- UuidParser.requireCompanyId(user.companyId)
            _          <- assertDriverInCompany(driverUuid, companyId)
            service    <- ZIO.service[DriverLocationService]
            status     <- service.getAvailability(PersonId(driverUuid))
            statusStr   = status.getOrElse("Offline")
          } yield Response.json(s"""{"status":"$statusStr"}""")).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      =>
              ZIO
                .logError(s"Unhandled error: ${Option(ex.getMessage).getOrElse(ex.toString)}")
                .as(
                  Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
                )
          }
      },
      Method.GET / "api" / "drivers" / string("driverId") / "earnings"     -> handler {
        (driverId: String, request: Request) =>
          (for {
            user       <- AuthMiddleware.authenticateRequest(request)
            driverUuid <- UuidParser.parse(driverId)
            _          <- AuthMiddleware.checkRoleOrOwner(user, driverUuid, "DISPATCHER")
            companyId  <- UuidParser.requireCompanyId(user.companyId)
            periodStr   = request.url.queryParams.queryParam("period").getOrElse("week")
            period     <- ZIO
                            .fromOption(EarningsPeriod.fromString(periodStr))
                            .orElseFail(
                              Response(
                                Status.BadRequest,
                                body = Body.fromString("""{"error":"Invalid period. Use 'day', 'week' or 'month'"}""")
                              )
                            )
            anchorDate <- ZIO
                            .attempt(
                              request.url.queryParams
                                .queryParam("date")
                                .map(java.time.LocalDate.parse)
                                .getOrElse(java.time.LocalDate.now())
                            )
                            .orElseFail(
                              Response(
                                Status.BadRequest,
                                body = Body.fromString("""{"error":"Invalid date. Use ISO format YYYY-MM-DD"}""")
                              )
                            )
            service    <- ZIO.service[RideService]
            report     <- service.getDriverEarnings(PersonId(driverUuid), companyId, period, anchorDate)
          } yield Response.json(toEarningsDto(report).toJson)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      =>
              ZIO
                .logError(s"Unhandled error: ${Option(ex.getMessage).getOrElse(ex.toString)}")
                .as(
                  Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
                )
          }
      },
      Method.GET / "api" / "drivers" / "available"                         -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          service   <- ZIO.service[DriverLocationService]
          drivers   <- service.getAvailableDrivers(companyId)
        } yield Response.json(drivers.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      =>
            ZIO
              .logError(s"Unhandled error: ${Option(ex.getMessage).getOrElse(ex.toString)}")
              .as(
                Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
              )
        }
      },
      Method.GET / "api" / "rides" / string("rideId") / "driver-location"  -> handler {
        (rideId: String, request: Request) =>
          (for {
            user         <- AuthMiddleware.authenticateRequest(request)
            companyId    <- UuidParser.requireCompanyId(user.companyId)
            rideService  <- ZIO.service[RideService]
            parsedRideId <- UuidParser.parseRideId(rideId)
            ride         <- rideService.getRideById(parsedRideId)
            // Company isolation: hide cross-tenant rides as not found.
            _            <- ZIO
                              .fail(com.shevchyk.ride.domain.RideError.RideNotFound(parsedRideId))
                              .when(ride.companyId != companyId)
            // Lazy geocoding: enrich pickup coords for old rides that have none
            ride         <-
              if ride.pickupLocation.latitude.isEmpty then
                ZIO
                  .serviceWithZIO[GeocodingService](_.enrichLocation(ride.pickupLocation))
                  .flatMap { enriched =>
                    if enriched.latitude.isDefined then
                      // Try to persist coords; on failure (e.g. InProgress ride) still use enriched for ETA
                      rideService
                        .updateRideDetails(
                          parsedRideId,
                          com.shevchyk.ride.domain.UpdateRideDetailsRequest(pickupLocation = Some(enriched)),
                          PersonId(user.userId),
                          PersonRole.valueOf(user.role),
                          Some(companyId)
                        )
                        .orElse(ZIO.succeed(ride.copy(pickupLocation = enriched)))
                    else ZIO.succeed(ride)
                  }
                  .orElse(ZIO.succeed(ride))
              else ZIO.succeed(ride)
            locService   <- ZIO.service[DriverLocationService]
            driverLoc    <-
              ride.driverId match {
                case Some(dId) => locService.getLocation(dId)
                case None      => ZIO.none
              }
            rideDto       = RideDto.fromDomain(
                              ride,
                              driverLat = driverLoc.map(_.latitude),
                              driverLng = driverLoc.map(_.longitude)
                            )
            // ETA assembly (driver loc → client/pickup coords → HERE → fallback)
            // lives in EtaService, the single source of truth shared with the
            // predictive ETA monitor.
            eta          <- ZIO.serviceWithZIO[EtaService](_.etaForRide(ride))
            proximity     = DriverProximityDto(
                              driverLocation = rideDto.driverLocation,
                              driverApproaching = rideDto.driverApproaching,
                              driverDistanceMeters = rideDto.driverDistanceMeters,
                              etaMinutes = eta
                            )
          } yield Response.json(proximity.toJson)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      =>
              ZIO
                .logError(s"Unhandled error: ${ex.getMessage}")
                .as(
                  Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
                )
          }
      }
    )
