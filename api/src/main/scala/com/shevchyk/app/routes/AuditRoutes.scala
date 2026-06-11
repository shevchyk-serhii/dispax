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

  val authenticatedRoutes: Routes[AuditService & JwtService, Response] = Routes(
    // GET /api/audit?entityType=ride&entityId={id}
    Method.GET / "api" / "audit" -> RouteHelpers.authHandler("Audit") { (user, request) =>
      for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId  <- UuidParser.requireCompanyId(user.companyId)
        entityType <- ZIO
                        .fromOption(request.url.queryParams.queryParam("entityType"))
                        .orElseFail(new RuntimeException("entityType query parameter is required"))
        entityId   <- ZIO
                        .fromOption(request.url.queryParams.queryParam("entityId"))
                        .orElseFail(new RuntimeException("entityId query parameter is required"))
        service    <- ZIO.service[AuditService]
        parsedId   <- UuidParser.parse(entityId)
        // Enforce tenant isolation: findByEntity is not company-scoped at the SQL
        // level, so filter out audit entries of other companies before returning.
        entries    <- service.findByEntity(entityType, parsedId).map(_.filter(_.companyId == companyId))
      } yield Response.json(entries.toJson)
    },

    // GET /api/audit/recent?limit=50
    Method.GET / "api" / "audit" / "recent" -> RouteHelpers.authHandler("Audit") { (user, request) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        limit      = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(50).min(100).max(1)
        offset     = request.url.queryParams.queryParam("offset").flatMap(_.toIntOption).getOrElse(0).max(0)
        service   <- ZIO.service[AuditService]
        entries   <- service.findByCompany(companyId, limit, offset)
      } yield Response.json(entries.toJson)
    }
  )
