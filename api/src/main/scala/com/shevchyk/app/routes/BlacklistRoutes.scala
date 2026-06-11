package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object BlacklistRoutes:

  val authenticatedRoutes: Routes[BlacklistRepository & AuditService & JwtService, Response] = Routes(
    // GET /api/blacklist — list blacklist entries for company
    Method.GET / "api" / "blacklist" -> RouteHelpers.authHandler("Blacklist") { (user, _) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[BlacklistRepository]
        companyId <- UuidParser.requireCompanyId(user.companyId)
        entries   <- repo.findByCompanyId(companyId)
      } yield Response.json(entries.toJson)
    },

    // POST /api/blacklist — add blacklist entry
    Method.POST / "api" / "blacklist" -> RouteHelpers.authHandler("Blacklist") { (user, request) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[CreateBlacklistRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo      <- ZIO.service[BlacklistRepository]
        companyId <- UuidParser.requireCompanyId(user.companyId)
        clientPid <- UuidParser.parsePersonId(req.clientId)
        driverPid <- UuidParser.parsePersonId(req.driverId)
        entry      = BlacklistEntry(
                       id = BlacklistEntryId.generate(),
                       companyId = companyId,
                       clientId = clientPid,
                       driverId = driverPid,
                       reason = req.reason,
                       createdBy = PersonId(user.userId)
                     )
        created   <- repo.create(entry)
        audit     <- ZIO.service[AuditService]
        _         <-
          audit
            .log(
              AuditLogEntry(
                id = AuditLogId.generate(),
                companyId = entry.companyId,
                actorId = PersonId(user.userId),
                action = AuditAction.UserUpdated,
                entityType = "blacklist",
                entityId = entry.id.value,
                newValue = Some(s"client=${req.clientId}, driver=${req.driverId}")
              )
            )
            .ignore
      } yield Response(Status.Created, body = Body.fromString(created.toJson))
    },

    // GET /api/blacklist/check?clientId=...&driverId=... — check if pair is blacklisted
    Method.GET / "api" / "blacklist" / "check" -> RouteHelpers.authHandler("Blacklist") { (user, request) =>
      for {
        _        <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
        clientId <- ZIO
                      .fromOption(request.url.queryParams.queryParam("clientId"))
                      .orElseFail(new RuntimeException("clientId required"))
        driverId <- ZIO
                      .fromOption(request.url.queryParams.queryParam("driverId"))
                      .orElseFail(new RuntimeException("driverId required"))
        repo     <- ZIO.service[BlacklistRepository]
        cPid     <- UuidParser.parsePersonId(clientId)
        dPid     <- UuidParser.parsePersonId(driverId)
        blocked  <- repo.isBlacklisted(cPid, dPid)
      } yield Response.json(s"""{"blacklisted":$blocked}""")
    },

    // DELETE /api/blacklist/{id} — remove blacklist entry
    Method.DELETE / "api" / "blacklist" / string("id") -> RouteHelpers.authPathHandler("Blacklist") {
      (user, id: String, _) =>
        for {
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          repo      <- ZIO.service[BlacklistRepository]
          entryId   <- UuidParser.parse(id).map(BlacklistEntryId(_))
          // Enforce tenant isolation: deactivate is not company-scoped, so verify
          // the entry belongs to the caller's company before deactivating it.
          entries   <- repo.findByCompanyId(companyId)
          deleted   <-
            if entries.exists(_.id == entryId) then repo.deactivate(entryId)
            else ZIO.succeed(false)
        } yield if deleted then Response.status(Status.NoContent) else Response.status(Status.NotFound)
    }
  )
