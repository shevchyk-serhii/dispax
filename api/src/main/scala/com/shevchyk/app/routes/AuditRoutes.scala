package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

object AuditRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("Audit")(ex)

  val authenticatedRoutes: Routes[AuditService & JwtService, Response] = Routes(
    // GET /api/audit?entityType=ride&entityId={id}
    Method.GET / "api" / "audit" -> handler { (request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
        entityType <- ZIO
                        .fromOption(request.url.queryParams.queryParam("entityType"))
                        .orElseFail(new RuntimeException("entityType query parameter is required"))
        entityId   <- ZIO
                        .fromOption(request.url.queryParams.queryParam("entityId"))
                        .orElseFail(new RuntimeException("entityId query parameter is required"))
        service    <- ZIO.service[AuditService]
        parsedId   <- UuidParser.parse(entityId)
        entries    <- service.findByEntity(entityType, parsedId)
      } yield Response.json(entries.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // GET /api/audit/recent?limit=50
    Method.GET / "api" / "audit" / "recent" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        limit      = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(50).min(100).max(1)
        offset     = request.url.queryParams.queryParam("offset").flatMap(_.toIntOption).getOrElse(0).max(0)
        service   <- ZIO.service[AuditService]
        entries   <- service.findByCompany(companyId, limit, offset)
      } yield Response.json(entries.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
