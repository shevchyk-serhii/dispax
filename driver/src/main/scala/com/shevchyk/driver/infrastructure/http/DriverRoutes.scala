package com.shevchyk.driver.infrastructure.http

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.driver.application.DriverLocationService
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.infrastructure.http.dto.{RideDto, LocationDto}
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

case class UpdateLocationRequest(
    latitude: Double,
    longitude: Double
) derives JsonCodec

case class DriverProximityDto(
    driverLocation: Option[LocationDto] = None,
    driverApproaching: Boolean = false,
    driverDistanceMeters: Option[Int] = None
) derives JsonCodec

object DriverRoutes:

  val authenticatedRoutes: Routes[DriverLocationService & RideService & JwtService, Response] = Routes(
    Method.PUT / "api" / "drivers" / string("driverId") / "location"    -> handler {
      (driverId: String, request: Request) =>
        (for {
          _       <- AuthMiddleware.authenticateRequest(request)
          bodyStr <- request.body.asString
          locReq  <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateLocationRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateLocation(
                       PersonId(UUID.fromString(driverId)),
                       locReq.latitude,
                       locReq.longitude
                     )
        } yield Response(Status.NoContent)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      =>
            ZIO.succeed(
              Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"${ex.getMessage}"}"""))
            )
        }
    },
    Method.GET / "api" / "rides" / string("rideId") / "driver-location" -> handler {
      (rideId: String, request: Request) =>
        (for {
          _           <- AuthMiddleware.authenticateRequest(request)
          rideService <- ZIO.service[RideService]
          ride        <- rideService.getRideById(RideId(UUID.fromString(rideId)))
          locService  <- ZIO.service[DriverLocationService]
          driverLoc   <-
            ride.driverId match {
              case Some(dId) => locService.getLocation(dId)
              case None      => ZIO.succeed(None)
            }
          rideDto      = RideDto.fromDomain(
                           ride,
                           driverLat = driverLoc.map(_.latitude),
                           driverLng = driverLoc.map(_.longitude)
                         )
          proximity    = DriverProximityDto(
                           driverLocation = rideDto.driverLocation,
                           driverApproaching = rideDto.driverApproaching,
                           driverDistanceMeters = rideDto.driverDistanceMeters
                         )
        } yield Response.json(proximity.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      =>
            ZIO.succeed(
              Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"${ex.getMessage}"}"""))
            )
        }
    }
  )
