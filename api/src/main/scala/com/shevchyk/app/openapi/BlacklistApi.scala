package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.BlacklistRepository
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the blacklist endpoints. Replaces the hand-written zio-http handlers in
 * `BlacklistRoutes` while preserving paths, query params, role checks, company isolation, status codes, audit logging
 * and error mapping.
 */
object BlacklistApi:

  import AppSecure.*
  import ApiSchemas.given

  private val blacklistTag = "Blacklist"

  type BlacklistEnv = JwtService & BlacklistRepository & AuditService

  // -- Endpoint descriptions ------------------------------------------------

  val listEndpoint = secureEndpoint.get
    .in("api" / "blacklist")
    .out(jsonBody[List[BlacklistEntry]])
    .tag(blacklistTag)
    .summary("List blacklist entries for the company (dispatcher, admin)")

  val createEndpoint = secureEndpoint.post
    .in("api" / "blacklist")
    .in(jsonBody[CreateBlacklistRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[BlacklistEntry]))
    .tag(blacklistTag)
    .summary("Add a blacklist entry (dispatcher, admin)")

  val checkEndpoint = secureEndpoint.get
    .in("api" / "blacklist" / "check")
    .in(query[Option[String]]("clientId"))
    .in(query[Option[String]]("driverId"))
    .out(stringBody.map(s => s)(s => s))
    .tag(blacklistTag)
    .summary("Check if a client/driver pair is blacklisted (dispatcher, secretary)")

  val deleteEndpoint = secureEndpoint.delete
    .in("api" / "blacklist" / path[String]("id"))
    .out(statusCode)
    .tag(blacklistTag)
    .summary("Remove a blacklist entry (dispatcher, admin)")

  val endpoints = List(listEndpoint, createEndpoint, checkEndpoint, deleteEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val listServer: ZServerEndpoint[BlacklistEnv, Any] = listEndpoint.serverLogic[BlacklistEnv] { user => _ =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      repo      <- ZIO.service[BlacklistRepository]
      companyId <- requireCompanyId(user.companyId)
      entries   <- repo.findByCompanyId(companyId).mapError(internal)
    } yield entries
  }

  private val createServer: ZServerEndpoint[BlacklistEnv, Any] = createEndpoint.serverLogic[BlacklistEnv] {
    user => req =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[BlacklistRepository]
        companyId <- requireCompanyId(user.companyId)
        clientPid <- parsePersonId(req.clientId)
        driverPid <- parsePersonId(req.driverId)
        entry      = BlacklistEntry(
                       id = BlacklistEntryId.generate(),
                       companyId = companyId,
                       clientId = clientPid,
                       driverId = driverPid,
                       reason = req.reason,
                       createdBy = PersonId(user.userId)
                     )
        created   <- repo.create(entry).mapError(internal)
        audit     <- ZIO.service[AuditService]
        _         <-
          audit
            .log(
              AuditLogEntry.record(
                companyId = entry.companyId,
                actorId = PersonId(user.userId),
                action = AuditAction.UserUpdated,
                entityType = "blacklist",
                entityId = entry.id.value,
                newValue = Some(s"client=${req.clientId}, driver=${req.driverId}")
              )
            )
            .ignore
      } yield created
  }

  private val checkServer: ZServerEndpoint[BlacklistEnv, Any] = checkEndpoint.serverLogic[BlacklistEnv] { user =>
    { case (clientIdOpt, driverIdOpt) =>
      for {
        _        <- checkRole(user, "DISPATCHER", "SECRETARY")
        clientId <- ZIO.fromOption(clientIdOpt).orElseFail(internal(new RuntimeException("clientId required")))
        driverId <- ZIO.fromOption(driverIdOpt).orElseFail(internal(new RuntimeException("driverId required")))
        repo     <- ZIO.service[BlacklistRepository]
        cPid     <- parsePersonId(clientId)
        dPid     <- parsePersonId(driverId)
        blocked  <- repo.isBlacklisted(cPid, dPid).mapError(internal)
      } yield s"""{"blacklisted":$blocked}"""
    }
  }

  private val deleteServer: ZServerEndpoint[BlacklistEnv, Any] = deleteEndpoint.serverLogic[BlacklistEnv] {
    user => id =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[BlacklistRepository]
        entryId   <- parseUuid(id).map(BlacklistEntryId(_))
        // Enforce tenant isolation: deactivate is not company-scoped, so verify
        // the entry belongs to the caller's company before deactivating it.
        entries   <- repo.findByCompanyId(companyId).mapError(internal)
        deleted   <-
          if entries.exists(_.id == entryId) then repo.deactivate(entryId, companyId).mapError(internal)
          else ZIO.succeed(false)
      } yield if deleted then StatusCode.NoContent else StatusCode.NotFound
  }

  val serverEndpoints: List[ZServerEndpoint[BlacklistEnv, Any]] = List(
    checkServer,
    listServer,
    createServer,
    deleteServer
  )
