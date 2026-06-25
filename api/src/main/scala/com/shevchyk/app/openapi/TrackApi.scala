package com.shevchyk.app.openapi

import com.shevchyk.core.openapi.ApiError
import com.shevchyk.driver.application.{DriverLocationService, EtaService}
import com.shevchyk.ride.application.service.{LocationWithTimestamp, RideService, RideShareTokenService}
import com.shevchyk.ride.domain.RideError
import com.shevchyk.ride.openapi.RideSecure.{checkRole, fromRideError, parseRideId, requireCompanyId, secureEndpoint}
import sttp.model.StatusCode
import sttp.tapir.generic.auto.*
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

/**
 * Public guest-tracking endpoints.
 *
 * A staff member (Driver/Dispatcher/Secretary) creates a token via the authenticated `POST
 * /api/rides/{rideId}/share-link`. A browser-only client then reads the ride state through the public, unauthenticated
 * `GET /api/track/{token}` — which exposes a deliberately sanitized [[PublicRideDto]] with NO driver/client PII and NO
 * price. ETA is composed here (not in the `ride` module) because `EtaService` lives in `driver`, and `ride` must not
 * depend on `driver`.
 */
object TrackApi:

  private val trackTag = "Guest tracking"

  // -- Public DTOs ---------------------------------------------------------

  /**
   * A map point exposed to a guest: address plus optional coordinates. No identity, no price.
   */
  final case class PublicLocation(address: String, latitude: Option[Double], longitude: Option[Double])
      derives JsonCodec

  /**
   * Everything a guest may see about a ride. Deliberately omits clientId, driverId, the driver's name/rating/phone, the
   * price, and any notes. Adding a field here is a PII decision — keep it minimal.
   */
  final case class PublicRideDto(
      status: String,
      pickup: PublicLocation,
      dropoff: PublicLocation,
      driverLocation: Option[LocationWithTimestamp],
      etaMinutes: Option[Int],
      driverAssigned: Boolean
  ) derives JsonCodec

  final case class PublicLocationsResponse(driverLocation: Option[LocationWithTimestamp]) derives JsonCodec

  final case class ShareLinkResponse(token: String, path: String) derives JsonCodec

  // -- Endpoint descriptions ----------------------------------------------

  val createShareLinkEndpoint = secureEndpoint.post
    .in("api" / "rides" / path[String]("rideId") / "share-link")
    .out(jsonBody[ShareLinkResponse])
    .tag(trackTag)
    .summary("Create (or reuse) a public guest tracking link for a ride")

  // Override the default public error-out (which would render 400) with 404: an invalid/expired/unknown token must be
  // indistinguishable and must not leak existence — the page treats 404 as "link expired".
  private val notFoundError = statusCode(StatusCode.NotFound).and(jsonBody[ApiError])

  val getTrackedRideEndpoint = endpoint.get
    .in("api" / "track" / path[String]("token"))
    .errorOut(notFoundError)
    .out(jsonBody[PublicRideDto])
    .tag(trackTag)
    .summary("Public ride state for a guest tracking token (no auth)")

  val getTrackedLocationsEndpoint = endpoint.get
    .in("api" / "track" / path[String]("token") / "locations")
    .errorOut(notFoundError)
    .out(jsonBody[PublicLocationsResponse])
    .tag(trackTag)
    .summary("Public driver location for a guest tracking token (no auth)")

  val endpoints = List(createShareLinkEndpoint, getTrackedRideEndpoint, getTrackedLocationsEndpoint)

  // -- Server logic --------------------------------------------------------

  type TrackEnv =
    com.shevchyk.auth.service.JwtService & RideShareTokenService & RideService & DriverLocationService & EtaService

  // The public read endpoints map every failure to a generic 404 ApiError — a guest must not be able to tell a wrong
  // token from an expired one from a missing ride (no existence leak).
  private val publicNotFound: ApiError = ApiError("Tracking link not found or expired")

  /**
   * Build the sanitized guest DTO from a ride plus its resolved driver location and ETA. Pure + package-private so the
   * PII surface (status/route/driver-coords/eta only — NO clientId/driverId/name/price) is unit-testable directly.
   */
  private[openapi] def toPublicDto(
      ride: com.shevchyk.ride.domain.Ride,
      driverLocation: Option[LocationWithTimestamp],
      etaMinutes: Option[Int]
  ): PublicRideDto = PublicRideDto(
    status = ride.status.toString,
    pickup = PublicLocation(ride.pickupLocation.address, ride.pickupLocation.latitude, ride.pickupLocation.longitude),
    dropoff = PublicLocation(
      ride.dropoffLocation.address,
      ride.dropoffLocation.latitude,
      ride.dropoffLocation.longitude
    ),
    driverLocation = driverLocation,
    etaMinutes = etaMinutes,
    driverAssigned = ride.driverId.isDefined
  )

  /**
   * Resolve a token to its driver location, in the RideError channel (callers map to a generic 404).
   */
  private def resolveDriverLocation(token: String): ZIO[TrackEnv, RideError, Option[LocationWithTimestamp]] =
    for {
      shareTokenService     <- ZIO.service[RideShareTokenService]
      rideService           <- ZIO.service[RideService]
      driverLocationService <- ZIO.service[DriverLocationService]
      resolved              <- shareTokenService.resolve(token)
      ride                  <- rideService.getRideById(resolved.rideId)
      driverLoc             <-
        ride.driverId match
          case Some(driverId) => driverLocationService.getLocation(driverId).mapError(RideError.DatabaseError(_))
          case None           => ZIO.none
    } yield driverLoc.map(d => LocationWithTimestamp(d.latitude, d.longitude, d.updatedAt))

  private val createShareLinkServer: ZServerEndpoint[TrackEnv, Any] = createShareLinkEndpoint.serverLogic {
    user => rideId =>
      for {
        // Only staff may mint a link. Backend gate in addition to the UI hiding the button.
        _         <- checkRole(user, "DRIVER", "DISPATCHER", "SECRETARY")
        parsedId  <- parseRideId(rideId)
        companyId <- requireCompanyId(user.companyId)
        service   <- ZIO.service[RideShareTokenService]
        // Tenant gate lives in the service (ride.companyId == companyId). Map any ride error to its status; an
        // UnauthorizedAccess (cross-tenant) collapses to 403 there, RideNotFound to 404.
        token     <- service.generateForRide(parsedId, companyId).mapError(fromRideError)
      } yield ShareLinkResponse(token = token, path = s"/track/$token")
  }

  private val getTrackedRideServer: ZServerEndpoint[TrackEnv, Any] = getTrackedRideEndpoint.zServerLogic { token =>
    (for {
      shareTokenService     <- ZIO.service[RideShareTokenService]
      rideService           <- ZIO.service[RideService]
      driverLocationService <- ZIO.service[DriverLocationService]
      etaService            <- ZIO.service[EtaService]
      resolved              <- shareTokenService.resolve(token)
      ride                  <- rideService.getRideById(resolved.rideId)
      driverLoc             <-
        ride.driverId match
          case Some(driverId) => driverLocationService.getLocation(driverId).mapError(RideError.DatabaseError(_))
          case None           => ZIO.none
      eta                   <- etaService.etaForRide(ride).mapError(RideError.DatabaseError(_))
    } yield toPublicDto(ride, driverLoc.map(d => LocationWithTimestamp(d.latitude, d.longitude, d.updatedAt)), eta))
      .mapError(_ => publicNotFound)
  }

  private val getTrackedLocationsServer: ZServerEndpoint[TrackEnv, Any] = getTrackedLocationsEndpoint.zServerLogic {
    token => resolveDriverLocation(token).map(PublicLocationsResponse(_)).mapError(_ => publicNotFound)
  }

  val serverEndpoints: List[ZServerEndpoint[TrackEnv, Any]] = List(
    createShareLinkServer,
    getTrackedRideServer,
    getTrackedLocationsServer
  )
