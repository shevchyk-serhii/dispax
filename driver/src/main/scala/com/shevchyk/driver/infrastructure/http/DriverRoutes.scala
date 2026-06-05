package com.shevchyk.driver.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, PersonRole, RideId}
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.ClientLocationRepository
import com.shevchyk.ride.infrastructure.http.dto.{LocationDto, RideDto}
import zio.*
import zio.http.*
import zio.json.*

case class UpdateLocationRequest(
    latitude: Double,
    longitude: Double
) derives JsonCodec

case class UpdateAvailabilityRequest(
    status: String
) derives JsonCodec

case class AvailableDriverDto(
    id: String,
    status: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec

case class DriverProximityDto(
    driverLocation: Option[LocationDto] = None,
    driverApproaching: Boolean = false,
    driverDistanceMeters: Option[Int] = None,
    etaMinutes: Option[Int] = None
) derives JsonCodec

object DriverRoutes:

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
    val eta   = math.ceil(distM / (50000.0 / 60.0)).toInt // 50 km/h → minutes
    Some(math.max(1, eta))

  val authenticatedRoutes
      : Routes[DriverLocationService & RideService & HereRoutingService & GeocodingService & ClientLocationRepository & JwtService, Response]     =
    Routes(
      Method.PUT / "api" / "drivers" / string("driverId") / "location"     -> handler {
        (driverId: String, request: Request) =>
          (for {
            user       <- AuthMiddleware.authenticateRequest(request)
            driverUuid <- UuidParser.parse(driverId)
            _          <- AuthMiddleware.checkRoleOrOwner(user, driverUuid, "DISPATCHER")
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
            rideService  <- ZIO.service[RideService]
            parsedRideId <- UuidParser.parseRideId(rideId)
            ride         <- rideService.getRideById(parsedRideId)
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
                          PersonRole.valueOf(user.role)
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
            // Use real-time client location if available, fall back to pickup address coords
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
                case None                                 => ZIO.none
              }
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
