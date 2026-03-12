package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.application.AuditService
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object BlacklistRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"Blacklist error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString("""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[BlacklistRepository & AuditService & JwtService, Response] = Routes(
    // GET /api/blacklist — list blacklist entries for company
    Method.GET / "api" / "blacklist" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        repo      <- ZIO.service[BlacklistRepository]
        companyId <- UuidParser.requireCompanyId(user.companyId)
        entries   <- repo.findByCompanyId(companyId)
      } yield Response.json(entries.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // POST /api/blacklist — add blacklist entry
    Method.POST / "api" / "blacklist" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
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
      } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // GET /api/blacklist/check?clientId=...&driverId=... — check if pair is blacklisted
    Method.GET / "api" / "blacklist" / "check" -> handler { (request: Request) =>
      (for {
        user     <- AuthMiddleware.authenticateRequest(request)
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
      } yield Response.json(s"""{"blacklisted":$blocked}""")).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // DELETE /api/blacklist/{id} — remove blacklist entry
    Method.DELETE / "api" / "blacklist" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRole(user, "DISPATCHER")
        repo    <- ZIO.service[BlacklistRepository]
        entryId <- UuidParser.parse(id).map(BlacklistEntryId(_))
        deleted <- repo.deactivate(entryId)
      } yield if deleted then Response.status(Status.NoContent) else Response.status(Status.NotFound)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
