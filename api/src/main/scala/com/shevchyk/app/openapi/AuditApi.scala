package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the audit-log endpoints. Replaces the hand-written zio-http handlers in
 * `AuditRoutes` while preserving paths, query params, role checks, company isolation, status codes and error mapping.
 */
object AuditApi:

  import AppSecure.*
  import ApiSchemas.given

  private val auditTag = "Audit"

  type AuditEnv = JwtService & AuditService

  // -- Endpoint descriptions ------------------------------------------------

  val findByEntityEndpoint = secureEndpoint.get
    .in("api" / "audit")
    .in(query[Option[String]]("entityType"))
    .in(query[Option[String]]("entityId"))
    .out(jsonBody[List[AuditLogEntry]])
    .tag(auditTag)
    .summary("Audit log entries for an entity (dispatcher, admin)")

  val recentEndpoint = secureEndpoint.get
    .in("api" / "audit" / "recent")
    .in(query[Option[Int]]("limit"))
    .in(query[Option[Int]]("offset"))
    .out(jsonBody[List[AuditLogEntry]])
    .tag(auditTag)
    .summary("Recent audit log entries for the company (dispatcher, admin)")

  val endpoints = List(findByEntityEndpoint, recentEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val findByEntityServer: ZServerEndpoint[AuditEnv, Any] = findByEntityEndpoint.serverLogic[AuditEnv] { user =>
    { case (entityTypeOpt, entityIdOpt) =>
      for {
        _          <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId  <- requireCompanyId(user.companyId)
        entityType <- ZIO
                        .fromOption(entityTypeOpt)
                        .orElseFail(internal(new RuntimeException("entityType query parameter is required")))
        entityId   <- ZIO
                        .fromOption(entityIdOpt)
                        .orElseFail(internal(new RuntimeException("entityId query parameter is required")))
        service    <- ZIO.service[AuditService]
        parsedId   <- parseUuid(entityId)
        // Enforce tenant isolation: findByEntity is not company-scoped at the SQL
        // level, so filter out audit entries of other companies before returning.
        entries    <- service.findByEntity(entityType, parsedId).map(_.filter(_.companyId == companyId)).mapError(internal)
      } yield entries
    }
  }

  private val recentServer: ZServerEndpoint[AuditEnv, Any] = recentEndpoint.serverLogic[AuditEnv] { user =>
    { case (limitOpt, offsetOpt) =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        limit      = limitOpt.getOrElse(50).min(100).max(1)
        offset     = offsetOpt.getOrElse(0).max(0)
        service   <- ZIO.service[AuditService]
        entries   <- service.findByCompany(companyId, limit, offset).mapError(internal)
      } yield entries
    }
  }

  val serverEndpoints: List[ZServerEndpoint[AuditEnv, Any]] = List(
    recentServer,
    findByEntityServer
  )
