package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{GdprRepository, PersonRepository}
import com.shevchyk.ride.repository.{ExpenseRepository, RideRepository}
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the GDPR endpoints. Replaces the hand-written zio-http handlers in
 * `GdprRoutes` while preserving paths, request/response shapes, role checks, company isolation, status codes and error
 * mapping.
 */
object GdprApi:

  import AppSecure.*

  private val gdprTag = "GDPR"

  // -- Schemas for domain DTOs ---------------------------------------------
  given Schema[ConsentType]          = Schema.derivedEnumeration[ConsentType].defaultStringBased
  given Schema[GdprRequestType]      = Schema.derivedEnumeration[GdprRequestType].defaultStringBased
  given Schema[GdprRequestStatus]    = Schema.derivedEnumeration[GdprRequestStatus].defaultStringBased
  given Schema[GdprConsentId]        = Schema.derived
  given Schema[GdprRequestId]        = Schema.derived
  given Schema[GdprConsent]          = Schema.derived
  given Schema[GdprRequest]          = Schema.derived
  given Schema[GdprDataExport]       = Schema.derived
  given Schema[UpdateConsentRequest] = Schema.derived

  type GdprEnv = JwtService & GdprRepository & PersonRepository & RideRepository & ExpenseRepository

  // -- Endpoint descriptions ------------------------------------------------

  val getConsentsEndpoint = secureEndpoint.get
    .in("api" / "gdpr" / "consents")
    .out(jsonBody[List[GdprConsent]])
    .tag(gdprTag)
    .summary("Get the current user's consents")

  // Heterogeneous body (granted -> consent JSON, revoked -> {"success":true}, missing -> 404).
  // Preserve the exact raw-JSON bodies and 404 via the error channel.
  val updateConsentEndpoint = secureEndpoint.put
    .in("api" / "gdpr" / "consents")
    .in(jsonBody[UpdateConsentRequest])
    .out(stringBody.map(s => s)(s => s))
    .tag(gdprTag)
    .summary("Update (grant or revoke) a consent")

  val exportEndpoint = secureEndpoint.get
    .in("api" / "gdpr" / "export")
    .out(jsonBody[GdprDataExport])
    .tag(gdprTag)
    .summary("Export all of the current user's data")

  val deletionRequestEndpoint = secureEndpoint.post
    .in("api" / "gdpr" / "deletion-request")
    .out(statusCode(StatusCode.Created).and(jsonBody[GdprRequest]))
    .tag(gdprTag)
    .summary("Request data deletion")

  val requestsEndpoint = secureEndpoint.get
    .in("api" / "gdpr" / "requests")
    .out(jsonBody[List[GdprRequest]])
    .tag(gdprTag)
    .summary("List all GDPR deletion requests (admin, dispatcher)")

  val endpoints = List(
    getConsentsEndpoint,
    updateConsentEndpoint,
    exportEndpoint,
    deletionRequestEndpoint,
    requestsEndpoint
  )

  // -- Server logic ---------------------------------------------------------

  private val getConsentsServer: ZServerEndpoint[GdprEnv, Any] = getConsentsEndpoint.serverLogic[GdprEnv] { user => _ =>
    for {
      repo     <- ZIO.service[GdprRepository]
      consents <- repo.findConsentsByUserId(PersonId(user.userId)).mapError(internal)
    } yield consents
  }

  private val updateConsentServer: ZServerEndpoint[GdprEnv, Any] = updateConsentEndpoint.serverLogic[GdprEnv] {
    user => req =>
      for {
        repo   <- ZIO.service[GdprRepository]
        cType  <- ZIO.attempt(ConsentType.valueOf(req.consentType)).mapError(internal)
        result <-
          if req.granted then
            repo
              .createConsent(
                GdprConsent(
                  id = GdprConsentId.generate(),
                  userId = PersonId(user.userId),
                  consentType = cType,
                  grantedAt = Instant.now()
                )
              )
              .mapError(internal)
              .map(c => c.toJson)
          else
            repo
              .revokeConsent(PersonId(user.userId), cType)
              .mapError(internal)
              .flatMap(ok =>
                if ok then ZIO.succeed("""{"success":true}""")
                else ZIO.fail((StatusCode.NotFound, ApiError("Not found")))
              )
      } yield result
  }

  private val exportServer: ZServerEndpoint[GdprEnv, Any] = exportEndpoint.serverLogic[GdprEnv] { user => _ =>
    for {
      personRepo  <- ZIO.service[PersonRepository]
      rideRepo    <- ZIO.service[RideRepository]
      expRepo     <- ZIO.service[ExpenseRepository]
      gdprRepo    <- ZIO.service[GdprRepository]
      personOpt   <- personRepo.findById(PersonId(user.userId)).mapError(internal)
      clientRides <- rideRepo.findByClientId(PersonId(user.userId)).mapError(internal)
      driverRides <- rideRepo.findByDriverId(PersonId(user.userId)).mapError(internal)
      userRides    = (clientRides ++ driverRides).distinctBy(_.id)
      expenses    <- expRepo.findByDriverId(PersonId(user.userId)).mapError(internal)
      consents    <- gdprRepo.findConsentsByUserId(PersonId(user.userId)).mapError(internal)
      userData     = Map(
                       "id"    -> user.userId.toString,
                       "email" -> user.email,
                       "role"  -> user.role,
                       "name"  -> personOpt.map(_.name).getOrElse(""),
                       "phone" -> personOpt.flatMap(_.phone).getOrElse("")
                     )
      rideData     = userRides.map(r =>
                       Map(
                         "id"     -> r.id.value.toString,
                         "from"   -> r.pickupLocation.address,
                         "to"     -> r.dropoffLocation.address,
                         "status" -> r.status.toString,
                         "date"   -> r.scheduledTime.map(_.toString).getOrElse(r.requestTime.toString),
                         "price"  -> r.finalPrice.orElse(r.estimatedPrice).map(_.toString).getOrElse("")
                       )
                     )
      expenseData  = expenses.map(e =>
                       Map(
                         "id"          -> e.id.value.toString,
                         "category"    -> e.category.toString,
                         "amount"      -> e.amount.toString,
                         "description" -> e.description.getOrElse("")
                       )
                     )
    } yield GdprDataExport(
      user = userData,
      rides = rideData,
      expenses = expenseData,
      consents = consents,
      exportedAt = Instant.now()
    )
  }

  private val deletionRequestServer: ZServerEndpoint[GdprEnv, Any] = deletionRequestEndpoint.serverLogic[GdprEnv] {
    user => _ =>
      for {
        repo    <- ZIO.service[GdprRepository]
        req      = GdprRequest(
                     id = GdprRequestId.generate(),
                     userId = PersonId(user.userId),
                     requestType = GdprRequestType.DELETION,
                     requestedAt = Instant.now()
                   )
        created <- repo.createRequest(req).mapError(internal)
      } yield created
  }

  private val requestsServer: ZServerEndpoint[GdprEnv, Any] = requestsEndpoint.serverLogic[GdprEnv] { user => _ =>
    for {
      _         <- checkRole(user, "ADMIN", "DISPATCHER")
      companyId <- requireCompanyId(user.companyId)
      repo      <- ZIO.service[GdprRepository]
      requests  <- repo.findAllRequests(companyId).mapError(internal)
    } yield requests
  }

  val serverEndpoints: List[ZServerEndpoint[GdprEnv, Any]] = List(
    getConsentsServer,
    updateConsentServer,
    exportServer,
    deletionRequestServer,
    requestsServer
  )
