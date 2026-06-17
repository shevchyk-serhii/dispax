package com.shevchyk.app.openapi

import com.github.f4b6a3.uuid.UuidCreator
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.AirportConfigService
import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone, RideError}
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the SuperAdmin airport configuration endpoints.
 *
 * SECURITY NOTE — Escape-hatch boundary: Every handler in this object begins with `requireSuperAdmin(user)`, which
 * checks that the authenticated user's role equals `"SUPER_ADMIN"` (case-insensitive). A SuperAdmin has `companyId =
 * None` in their JWT; `requireCompanyId` is NEVER called here.
 *
 * Cross-tenant scope: Airports are GLOBAL configuration data — they have no `company_id` column by design. The access
 * control substitute is the `requireSuperAdmin` gate on EVERY endpoint including reads. This prevents regular company
 * users from discovering airport configuration data.
 *
 * Mirrors [[SuperAdminApi]] in structure.
 */
object SuperAdminAirportApi:

  import AppSecure.*

  private val superAdminTag = "SuperAdmin"

  // --------------------------------------------------------------------------
  // Response / request DTOs (separated from domain — invariant §6)
  // --------------------------------------------------------------------------

  final case class AirportZoneResponse(
      id: String,
      airportCode: String,
      terminalCode: String,
      checkpointType: String,
      displayName: String,
      lat: Double,
      lon: Double,
      radiusMeters: Int,
      sortOrder: Int,
      createdAt: String,
      updatedAt: String
  ) derives JsonCodec

  object AirportZoneResponse:
    given Schema[AirportZoneResponse] = Schema.derived

    def from(z: AirportCheckpointZone): AirportZoneResponse = AirportZoneResponse(
      id = z.id.toString,
      airportCode = z.airportCode,
      terminalCode = z.terminalCode,
      checkpointType = z.checkpointType,
      displayName = z.displayName,
      lat = z.lat,
      lon = z.lon,
      radiusMeters = z.radiusMeters,
      sortOrder = z.sortOrder,
      createdAt = z.createdAt.toString,
      updatedAt = z.updatedAt.toString
    )

  final case class AirportResponse(
      code: String,
      name: String,
      country: String,
      landingLat: Double,
      landingLon: Double,
      landingRadius: Int,
      isActive: Boolean,
      zones: List[AirportZoneResponse],
      createdAt: String,
      updatedAt: String
  ) derives JsonCodec

  object AirportResponse:
    given Schema[AirportResponse] = Schema.derived

    def from(a: Airport): AirportResponse = AirportResponse(
      code = a.code,
      name = a.name,
      country = a.country,
      landingLat = a.landingLat,
      landingLon = a.landingLon,
      landingRadius = a.landingRadius,
      isActive = a.isActive,
      zones = a.zones.map(AirportZoneResponse.from),
      createdAt = a.createdAt.toString,
      updatedAt = a.updatedAt.toString
    )

  final case class CreateAirportRequest(
      code: String,
      name: String,
      country: String = "DE",
      landingLat: Double,
      landingLon: Double,
      landingRadius: Int
  ) derives JsonCodec

  object CreateAirportRequest:
    given Schema[CreateAirportRequest] = Schema.derived

  final case class UpdateAirportRequest(
      name: Option[String] = None,
      country: Option[String] = None,
      landingLat: Option[Double] = None,
      landingLon: Option[Double] = None,
      landingRadius: Option[Int] = None,
      isActive: Option[Boolean] = None
  ) derives JsonCodec

  object UpdateAirportRequest:
    given Schema[UpdateAirportRequest] = Schema.derived

  final case class CreateZoneRequest(
      airportCode: String,
      terminalCode: String,
      checkpointType: String,
      displayName: String,
      lat: Double,
      lon: Double,
      radiusMeters: Int,
      sortOrder: Int = 0
  ) derives JsonCodec

  object CreateZoneRequest:
    given Schema[CreateZoneRequest] = Schema.derived

  final case class UpdateZoneRequest(
      terminalCode: Option[String] = None,
      checkpointType: Option[String] = None,
      displayName: Option[String] = None,
      lat: Option[Double] = None,
      lon: Option[Double] = None,
      radiusMeters: Option[Int] = None,
      sortOrder: Option[Int] = None
  ) derives JsonCodec

  object UpdateZoneRequest:
    given Schema[UpdateZoneRequest] = Schema.derived

  // --------------------------------------------------------------------------
  // Combined environment type
  // --------------------------------------------------------------------------

  type SuperAdminAirportEnv = JwtService & AirportConfigService

  // Maps a Throwable from the service layer:
  //   RideError.ValidationError → 400 Bad Request  (validation moved to service)
  //   anything else             → 500 Internal Server Error
  private def fromServiceError(t: Throwable): Err =
    t match
      case RideError.ValidationError(msg) => (StatusCode.BadRequest, ApiError(msg))
      case _                              => internal(t)

  // --------------------------------------------------------------------------
  // Endpoint descriptions
  // --------------------------------------------------------------------------

  private val base = "api" / "superadmin" / "airports"

  val listAirportsEndpoint = secureEndpoint.get
    .in(base)
    .out(jsonBody[List[AirportResponse]])
    .tag(superAdminTag)
    .summary("List all airports [SuperAdmin only]")

  val getAirportEndpoint = secureEndpoint.get
    .in(base / path[String]("code"))
    .out(jsonBody[AirportResponse])
    .tag(superAdminTag)
    .summary("Get a single airport by IATA code [SuperAdmin only]")

  val createAirportEndpoint = secureEndpoint.post
    .in(base)
    .in(jsonBody[CreateAirportRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[AirportResponse]))
    .tag(superAdminTag)
    .summary("Create a new airport configuration [SuperAdmin only]")

  val updateAirportEndpoint = secureEndpoint.patch
    .in(base / path[String]("code"))
    .in(jsonBody[UpdateAirportRequest])
    .out(jsonBody[AirportResponse])
    .tag(superAdminTag)
    .summary("Update airport configuration [SuperAdmin only]")

  val deleteAirportEndpoint = secureEndpoint.delete
    .in(base / path[String]("code"))
    .out(jsonBody[AirportResponse])
    .tag(superAdminTag)
    .summary("Soft-deactivate an airport [SuperAdmin only]")

  val createZoneEndpoint = secureEndpoint.post
    .in(base / path[String]("code") / "zones")
    .in(jsonBody[CreateZoneRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[AirportZoneResponse]))
    .tag(superAdminTag)
    .summary("Add a checkpoint zone to an airport [SuperAdmin only]")

  val updateZoneEndpoint = secureEndpoint.patch
    .in(base / path[String]("code") / "zones" / path[String]("zoneId"))
    .in(jsonBody[UpdateZoneRequest])
    .out(jsonBody[AirportZoneResponse])
    .tag(superAdminTag)
    .summary("Update a checkpoint zone [SuperAdmin only]")

  val deleteZoneEndpoint = secureEndpoint.delete
    .in(base / path[String]("code") / "zones" / path[String]("zoneId"))
    .out(statusCode(StatusCode.NoContent))
    .tag(superAdminTag)
    .summary("Delete a checkpoint zone [SuperAdmin only]")

  // --------------------------------------------------------------------------
  // Server logic
  // --------------------------------------------------------------------------

  private val listAirportsServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = listAirportsEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { _ =>
        for
          _        <- requireSuperAdmin(user)
          svc      <- ZIO.service[AirportConfigService]
          airports <- svc.listAirports().mapError(internal)
        yield airports.map(AirportResponse.from)
      }
    }

  private val getAirportServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = getAirportEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { code =>
        for
          _       <- requireSuperAdmin(user)
          svc     <- ZIO.service[AirportConfigService]
          airport <- svc.getAirport(code).mapError(internal)
          result  <- ZIO
                       .fromOption(airport)
                       .mapBoth(
                         _ => (StatusCode.NotFound, ApiError(s"Airport not found: $code")),
                         AirportResponse.from
                       )
        yield result
      }
    }

  private val createAirportServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = createAirportEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { req =>
        for
          _       <- requireSuperAdmin(user)
          svc     <- ZIO.service[AirportConfigService]
          now      = Instant.now()
          airport  = Airport(
                       code = req.code.toUpperCase,
                       name = req.name,
                       country = req.country,
                       landingLat = req.landingLat,
                       landingLon = req.landingLon,
                       landingRadius = req.landingRadius,
                       isActive = true,
                       zones = Nil,
                       createdAt = now,
                       updatedAt = now
                     )
          created <- svc.createAirport(airport).mapError(fromServiceError)
        yield AirportResponse.from(created)
      }
    }

  private val updateAirportServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = updateAirportEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { case (code, req) =>
        for
          _        <- requireSuperAdmin(user)
          svc      <- ZIO.service[AirportConfigService]
          existing <- svc.getAirport(code).mapError(internal)
          current  <- ZIO
                        .fromOption(existing)
                        .orElseFail((StatusCode.NotFound, ApiError(s"Airport not found: $code")))
          updated   = current.copy(
                        name = req.name.getOrElse(current.name),
                        country = req.country.getOrElse(current.country),
                        landingLat = req.landingLat.getOrElse(current.landingLat),
                        landingLon = req.landingLon.getOrElse(current.landingLon),
                        landingRadius = req.landingRadius.getOrElse(current.landingRadius),
                        isActive = req.isActive.getOrElse(current.isActive)
                      )
          result   <- svc.updateAirport(code, updated).mapError(fromServiceError)
          airport  <- ZIO
                        .fromOption(result)
                        .orElseFail((StatusCode.NotFound, ApiError(s"Airport not found: $code")))
        yield AirportResponse.from(airport)
      }
    }

  private val deleteAirportServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = deleteAirportEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { code =>
        for
          _        <- requireSuperAdmin(user)
          svc      <- ZIO.service[AirportConfigService]
          existing <- svc.getAirport(code).mapError(internal)
          airport  <- ZIO
                        .fromOption(existing)
                        .orElseFail((StatusCode.NotFound, ApiError(s"Airport not found: $code")))
          deleted  <- svc.deleteAirport(code).mapError(internal)
          _        <- ZIO
                        .fail((StatusCode.NotFound, ApiError(s"Airport not found or already inactive: $code")))
                        .when(!deleted)
        yield AirportResponse.from(airport.copy(isActive = false))
      }
    }

  private val createZoneServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = createZoneEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { case (code, req) =>
        for
          _       <- requireSuperAdmin(user)
          svc     <- ZIO.service[AirportConfigService]
          now      = Instant.now()
          zone     = AirportCheckpointZone(
                       id = UuidCreator.getTimeOrderedEpoch(),
                       airportCode = code,
                       terminalCode = req.terminalCode,
                       checkpointType = req.checkpointType,
                       displayName = req.displayName,
                       lat = req.lat,
                       lon = req.lon,
                       radiusMeters = req.radiusMeters,
                       sortOrder = req.sortOrder,
                       createdAt = now,
                       updatedAt = now
                     )
          created <- svc.createZone(zone).mapError(fromServiceError)
        yield AirportZoneResponse.from(created)
      }
    }

  private val updateZoneServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = updateZoneEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { case (code, zoneIdStr, req) =>
        for
          _       <- requireSuperAdmin(user)
          svc     <- ZIO.service[AirportConfigService]
          zoneId  <- parseUuid(zoneIdStr)
          // Load the airport to find the current zone for defaults
          airOpt  <- svc.getAirport(code).mapError(internal)
          airport <- ZIO
                       .fromOption(airOpt)
                       .orElseFail((StatusCode.NotFound, ApiError(s"Airport not found: $code")))
          current <- ZIO
                       .fromOption(airport.zones.find(_.id == zoneId))
                       .orElseFail((StatusCode.NotFound, ApiError(s"Zone not found: $zoneIdStr")))
          updated  = current.copy(
                       terminalCode = req.terminalCode.getOrElse(current.terminalCode),
                       checkpointType = req.checkpointType.getOrElse(current.checkpointType),
                       displayName = req.displayName.getOrElse(current.displayName),
                       lat = req.lat.getOrElse(current.lat),
                       lon = req.lon.getOrElse(current.lon),
                       radiusMeters = req.radiusMeters.getOrElse(current.radiusMeters),
                       sortOrder = req.sortOrder.getOrElse(current.sortOrder)
                     )
          result  <- svc.updateZone(zoneId, updated).mapError(fromServiceError)
          zone    <- ZIO
                       .fromOption(result)
                       .orElseFail((StatusCode.NotFound, ApiError(s"Zone not found: $zoneIdStr")))
        yield AirportZoneResponse.from(zone)
      }
    }

  private val deleteZoneServer: ZServerEndpoint[SuperAdminAirportEnv, Any] = deleteZoneEndpoint
    .serverLogic[SuperAdminAirportEnv] { user =>
      { case (_, zoneIdStr) =>
        for
          _       <- requireSuperAdmin(user)
          svc     <- ZIO.service[AirportConfigService]
          zoneId  <- parseUuid(zoneIdStr)
          deleted <- svc.deleteZone(zoneId).mapError(internal)
          _       <- ZIO
                       .fail((StatusCode.NotFound, ApiError(s"Zone not found: $zoneIdStr")))
                       .when(!deleted)
        yield ()
      }
    }

  // --------------------------------------------------------------------------
  // Public API surface
  // --------------------------------------------------------------------------

  val serverEndpoints: List[ZServerEndpoint[SuperAdminAirportEnv, Any]] = List(
    listAirportsServer,
    getAirportServer,
    createAirportServer,
    updateAirportServer,
    deleteAirportServer,
    createZoneServer,
    updateZoneServer,
    deleteZoneServer
  )
