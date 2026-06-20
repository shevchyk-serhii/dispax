package com.shevchyk.billing.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.domain.{CompanyBillingProfile, UpdateCompanyBillingProfileRequest}
import com.shevchyk.billing.openapi.BillingSecure.*
import com.shevchyk.billing.repository.CompanyBillingProfileRepository
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the company billing-profile endpoints. Replaces the zio-http handlers in
 * `BillingProfileRoutes` while keeping the exact paths, request/response shapes, status codes, role checks and company
 * isolation. Like the original handler, any failure is surfaced as a generic 500.
 */
object BillingProfileApi:

  private val billingProfileTag = "Billing Profile"

  // -- Environment ---------------------------------------------------------
  type BillingProfileEnv = CompanyBillingProfileRepository & JwtService

  // -- Schemas (CompanyId already provides a `given Schema` in its companion) -
  given Schema[CompanyBillingProfile]              = Schema.derived
  given Schema[UpdateCompanyBillingProfileRequest] = Schema.derived

  // ======================================================================
  // Endpoint descriptions
  // ======================================================================

  val getProfileEndpoint = secureEndpoint.get
    .in("api" / "billing" / "profile")
    .out(jsonBody[CompanyBillingProfile])
    .tag(billingProfileTag)
    .summary("Get the current company's invoice issuer details")

  val updateProfileEndpoint = secureEndpoint.put
    .in("api" / "billing" / "profile")
    .in(jsonBody[UpdateCompanyBillingProfileRequest])
    .out(jsonBody[CompanyBillingProfile])
    .tag(billingProfileTag)
    .summary("Create or update the current company's invoice issuer details")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    getProfileEndpoint,
    updateProfileEndpoint
  )

  // ======================================================================
  // Server logic
  // ======================================================================

  private val getProfileServer: ZServerEndpoint[BillingProfileEnv, Any] = getProfileEndpoint.serverLogic { user => _ =>
    for {
      companyId <- requireCompanyId(user.companyId)
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      repo      <- ZIO.service[CompanyBillingProfileRepository]
      profile   <- repo.findByCompany(companyId).mapError(_ => internalError)
    } yield profile.getOrElse(CompanyBillingProfile(companyId))
  }

  private val updateProfileServer: ZServerEndpoint[BillingProfileEnv, Any] = updateProfileEndpoint.serverLogic {
    user => req =>
      for {
        companyId <- requireCompanyId(user.companyId)
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[CompanyBillingProfileRepository]
        profile   <- repo.upsert(companyId, req).mapError(_ => internalError)
      } yield profile
  }

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[BillingProfileEnv, Any]] = List(
    getProfileServer,
    updateProfileServer
  )
