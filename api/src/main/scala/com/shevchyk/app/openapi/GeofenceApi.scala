package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeofenceService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{GeofenceRepository, PersonRepository}
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant
import java.util.UUID

/**
 * Tapir descriptions and server logic for the geofence endpoints. Replaces the hand-written zio-http handlers in
 * `GeofenceRoutes` while preserving paths, query params, role checks, company isolation, status codes and error
 * mapping. The original handlers funnel every non-`Response` failure (not found, wrong company, invalid type, ...)
 * through `RouteErrorHandler`, which always produces a 500 — reproduced here via `internal`.
 */
object GeofenceApi:

  import AppSecure.*
  import ApiSchemas.given

  private val geofenceTag = "Geofence"

  /**
   * `GeofenceAlert` enriched with the driver's display name so the UI never has to show a bare UUID. The name is
   * resolved at read time; `None` when the person no longer exists.
   */
  final case class GeofenceAlertDto(
      id: UUID,
      geofenceId: GeofenceId,
      driverId: PersonId,
      companyId: CompanyId,
      alertType: String,
      geofenceName: String,
      latitude: Double,
      longitude: Double,
      timestamp: Instant,
      driverName: Option[String]
  ) derives JsonCodec

  object GeofenceAlertDto:

    def fromDomain(a: GeofenceAlert, names: Map[PersonId, String]): GeofenceAlertDto = GeofenceAlertDto(
      id = a.id,
      geofenceId = a.geofenceId,
      driverId = a.driverId,
      companyId = a.companyId,
      alertType = a.alertType,
      geofenceName = a.geofenceName,
      latitude = a.latitude,
      longitude = a.longitude,
      timestamp = a.timestamp,
      driverName = names.get(a.driverId)
    )

  type GeofenceEnv = JwtService & GeofenceRepository & GeofenceService & PersonRepository

  // -- Endpoint descriptions ------------------------------------------------

  val createEndpoint = secureEndpoint.post
    .in("api" / "geofences")
    .in(jsonBody[CreateGeofenceRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[Geofence]))
    .tag(geofenceTag)
    .summary("Create a geofence (dispatcher, admin)")

  val alertsEndpoint = secureEndpoint.get
    .in("api" / "geofences" / "alerts")
    .in(query[Option[Int]]("limit"))
    .out(jsonBody[List[GeofenceAlertDto]])
    .tag(geofenceTag)
    .summary("Recent geofence alerts for the company (dispatcher, admin)")

  val alertsByDriverEndpoint = secureEndpoint.get
    .in("api" / "geofences" / "alerts" / "driver" / path[String]("driverId"))
    .in(query[Option[Int]]("limit"))
    .out(jsonBody[List[GeofenceAlertDto]])
    .tag(geofenceTag)
    .summary("Geofence alerts for a specific driver (dispatcher, admin)")

  val listEndpoint = secureEndpoint.get
    .in("api" / "geofences")
    .out(jsonBody[List[Geofence]])
    .tag(geofenceTag)
    .summary("List geofences for the company (dispatcher, admin)")

  val updateEndpoint = secureEndpoint.put
    .in("api" / "geofences" / path[String]("id"))
    .in(jsonBody[CreateGeofenceRequest])
    .out(jsonBody[Geofence])
    .tag(geofenceTag)
    .summary("Update a geofence (dispatcher, admin)")

  val deleteEndpoint = secureEndpoint.delete
    .in("api" / "geofences" / path[String]("id"))
    .out(statusCode)
    .tag(geofenceTag)
    .summary("Delete a geofence (dispatcher, admin)")

  val endpoints = List(
    createEndpoint,
    alertsEndpoint,
    alertsByDriverEndpoint,
    listEndpoint,
    updateEndpoint,
    deleteEndpoint
  )

  // -- Server logic ---------------------------------------------------------

  private val createServer: ZServerEndpoint[GeofenceEnv, Any] = createEndpoint.serverLogic[GeofenceEnv] { user => req =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      gfType    <- ZIO
                     .attempt(GeofenceType.valueOf(req.geofenceType))
                     .mapError(internal)
      geofence   = Geofence(
                     id = GeofenceId.generate(),
                     companyId = companyId,
                     name = req.name,
                     geofenceType = gfType,
                     centerLatitude = req.centerLatitude,
                     centerLongitude = req.centerLongitude,
                     radiusMeters = req.radiusMeters,
                     notifyOnEntry = req.notifyOnEntry,
                     notifyOnExit = req.notifyOnExit
                   )
      repo      <- ZIO.service[GeofenceRepository]
      created   <- repo.create(geofence).mapError(internal)
    } yield created
  }

  private val listServer: ZServerEndpoint[GeofenceEnv, Any] = listEndpoint.serverLogic[GeofenceEnv] { user => _ =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      repo      <- ZIO.service[GeofenceRepository]
      geofences <- repo.findByCompanyId(companyId).mapError(internal)
    } yield geofences
  }

  private val updateServer: ZServerEndpoint[GeofenceEnv, Any] = updateEndpoint.serverLogic[GeofenceEnv] { user =>
    { case (id, req) =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        geoId     <- parseUuid(id).map(GeofenceId(_))
        repo      <- ZIO.service[GeofenceRepository]
        existing  <- repo.findById(geoId).mapError(internal)
        geofence  <- ZIO.fromOption(existing).orElseFail(internal(new RuntimeException("Geofence not found")))
        _         <- ZIO
                       .fail(internal(new RuntimeException("Geofence belongs to different company")))
                       .when(geofence.companyId != companyId)
        gfType    <- ZIO
                       .attempt(GeofenceType.valueOf(req.geofenceType))
                       .mapError(internal)
        updated    = geofence.copy(
                       name = req.name,
                       geofenceType = gfType,
                       centerLatitude = req.centerLatitude,
                       centerLongitude = req.centerLongitude,
                       radiusMeters = req.radiusMeters,
                       notifyOnEntry = req.notifyOnEntry,
                       notifyOnExit = req.notifyOnExit
                     )
        result    <- repo.update(updated).mapError(internal)
      } yield result
    }
  }

  private val deleteServer: ZServerEndpoint[GeofenceEnv, Any] = deleteEndpoint.serverLogic[GeofenceEnv] { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      geoId     <- parseUuid(id).map(GeofenceId(_))
      repo      <- ZIO.service[GeofenceRepository]
      existing  <- repo.findById(geoId).mapError(internal)
      geofence  <- ZIO.fromOption(existing).orElseFail(internal(new RuntimeException("Geofence not found")))
      _         <- ZIO
                     .fail(internal(new RuntimeException("Geofence belongs to different company")))
                     .when(geofence.companyId != companyId)
      deleted   <- repo.delete(geoId, companyId).mapError(internal)
    } yield if deleted then StatusCode.NoContent else StatusCode.NotFound
  }

  private val alertsServer: ZServerEndpoint[GeofenceEnv, Any] = alertsEndpoint.serverLogic[GeofenceEnv] {
    user => limitOpt =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        limit      = limitOpt.getOrElse(50).min(100).max(1)
        repo      <- ZIO.service[GeofenceRepository]
        alerts    <- repo.findAlertsByCompany(companyId, limit).mapError(internal)
        names     <- PersonNameLookup.names(alerts.map(_.driverId), companyId).mapError(internal)
      } yield alerts.map(GeofenceAlertDto.fromDomain(_, names))
  }

  private val alertsByDriverServer: ZServerEndpoint[GeofenceEnv, Any] = alertsByDriverEndpoint
    .serverLogic[GeofenceEnv] { user =>
      { case (driverId, limitOpt) =>
        for {
          _         <- checkRole(user, "DISPATCHER", "ADMIN")
          companyId <- requireCompanyId(user.companyId)
          limit      = limitOpt.getOrElse(50).min(100).max(1)
          repo      <- ZIO.service[GeofenceRepository]
          dPid      <- parsePersonId(driverId)
          // Enforce tenant isolation: findAlertsByDriver is not company-scoped, so
          // a dispatcher must not see alerts of a driver from another company.
          alerts    <- repo.findAlertsByDriver(dPid, limit).map(_.filter(_.companyId == companyId)).mapError(internal)
          names     <- PersonNameLookup.names(alerts.map(_.driverId), companyId).mapError(internal)
        } yield alerts.map(GeofenceAlertDto.fromDomain(_, names))
      }
    }

  // Static sub-paths (/alerts, /alerts/driver/{id}) precede the bare /{id} matcher.
  val serverEndpoints: List[ZServerEndpoint[GeofenceEnv, Any]] = List(
    alertsByDriverServer,
    alertsServer,
    createServer,
    listServer,
    updateServer,
    deleteServer
  )
