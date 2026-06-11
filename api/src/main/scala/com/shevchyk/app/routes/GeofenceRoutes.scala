package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeofenceService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.GeofenceRepository
import zio.*
import zio.http.*
import zio.json.*

object GeofenceRoutes:

  val authenticatedRoutes: Routes[GeofenceRepository & GeofenceService & JwtService, Response] = Routes(
    // POST /api/geofences - create geofence
    Method.POST / "api" / "geofences" -> RouteHelpers.authHandler("Geofence") { (user, request) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[CreateGeofenceRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        gfType    <- ZIO
                       .attempt(GeofenceType.valueOf(req.geofenceType))
                       .mapError(_ =>
                         new RuntimeException(
                           s"Invalid geofence type: ${req.geofenceType}. Valid: ${GeofenceType.values.mkString(", ")}"
                         )
                       )
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
        created   <- repo.create(geofence)
      } yield Response.json(created.toJson).status(Status.Created)
    },

    // GET /api/geofences - list geofences for company
    Method.GET / "api" / "geofences" -> RouteHelpers.authHandler("Geofence") { (user, _) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[GeofenceRepository]
        geofences <- repo.findByCompanyId(companyId)
      } yield Response.json(geofences.toJson)
    },

    // PUT /api/geofences/{id} - update geofence
    Method.PUT / "api" / "geofences" / string("id") -> RouteHelpers.authPathHandler("Geofence") {
      (user, id: String, request) =>
        for {
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          geoId     <- UuidParser.parse(id).map(GeofenceId(_))
          repo      <- ZIO.service[GeofenceRepository]
          existing  <- repo.findById(geoId)
          geofence  <- ZIO.fromOption(existing).orElseFail(new RuntimeException("Geofence not found"))
          _         <- ZIO
                         .fail(new RuntimeException("Geofence belongs to different company"))
                         .when(geofence.companyId != companyId)
          bodyStr   <- request.body.asString
          req       <- ZIO
                         .fromEither(bodyStr.fromJson[CreateGeofenceRequest])
                         .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          gfType    <- ZIO
                         .attempt(GeofenceType.valueOf(req.geofenceType))
                         .mapError(_ => new RuntimeException(s"Invalid geofence type: ${req.geofenceType}"))
          updated    = geofence.copy(
                         name = req.name,
                         geofenceType = gfType,
                         centerLatitude = req.centerLatitude,
                         centerLongitude = req.centerLongitude,
                         radiusMeters = req.radiusMeters,
                         notifyOnEntry = req.notifyOnEntry,
                         notifyOnExit = req.notifyOnExit
                       )
          result    <- repo.update(updated)
        } yield Response.json(result.toJson)
    },

    // DELETE /api/geofences/{id} - delete geofence
    Method.DELETE / "api" / "geofences" / string("id") -> RouteHelpers.authPathHandler("Geofence") {
      (user, id: String, _) =>
        for {
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          geoId     <- UuidParser.parse(id).map(GeofenceId(_))
          repo      <- ZIO.service[GeofenceRepository]
          existing  <- repo.findById(geoId)
          geofence  <- ZIO.fromOption(existing).orElseFail(new RuntimeException("Geofence not found"))
          _         <- ZIO
                         .fail(new RuntimeException("Geofence belongs to different company"))
                         .when(geofence.companyId != companyId)
          deleted   <- repo.delete(geoId)
        } yield if deleted then Response(Status.NoContent) else Response(Status.NotFound)
    },

    // GET /api/geofences/alerts?limit=50 - recent alerts for company
    Method.GET / "api" / "geofences" / "alerts" -> RouteHelpers.authHandler("Geofence") { (user, request) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        limit      = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(50).min(100).max(1)
        repo      <- ZIO.service[GeofenceRepository]
        alerts    <- repo.findAlertsByCompany(companyId, limit)
      } yield Response.json(alerts.toJson)
    },

    // GET /api/geofences/alerts/driver/{driverId} - alerts for specific driver
    Method.GET / "api" / "geofences" / "alerts" / "driver" / string("driverId") ->
      RouteHelpers.authPathHandler("Geofence") { (user, driverId: String, request) =>
        for {
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          limit      = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(50).min(100).max(1)
          repo      <- ZIO.service[GeofenceRepository]
          dPid      <- UuidParser.parsePersonId(driverId)
          // Enforce tenant isolation: findAlertsByDriver is not company-scoped, so
          // a dispatcher must not see alerts of a driver from another company.
          alerts    <- repo.findAlertsByDriver(dPid, limit).map(_.filter(_.companyId == companyId))
        } yield Response.json(alerts.toJson)
      }
  )
