package com.shevchyk.billing.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.openapi.BillingSecure.*
import com.shevchyk.billing.repository.ClientCompanyRepository
import com.shevchyk.core.domain.{ClientCompany, CreateClientCompanyRequest}
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the billing client-company endpoints (`/api/billing/companies`). Replaces the
 * zio-http handlers in `billing.infrastructure.http.ClientCompanyRoutes`, keeping the exact paths, request/response
 * shapes, status codes, role checks and company isolation.
 */
object BillingClientCompanyApi:

  private val companyTag = "Billing client companies"

  // -- Environment ---------------------------------------------------------
  type BillingCompanyEnv = ClientCompanyRepository & JwtService

  // -- Schemas (ClientCompanyId already has a Schema in core.domain) --------
  given Schema[ClientCompany]              = Schema.derived
  given Schema[CreateClientCompanyRequest] = Schema.derived

  // ======================================================================
  // Endpoint descriptions
  // ======================================================================

  val listCompaniesEndpoint = secureEndpoint.get
    .in("api" / "billing" / "companies")
    .out(jsonBody[List[ClientCompany]])
    .tag(companyTag)
    .summary("List billing client companies")

  val createCompanyEndpoint = secureEndpoint.post
    .in("api" / "billing" / "companies")
    .in(jsonBody[CreateClientCompanyRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[ClientCompany]))
    .tag(companyTag)
    .summary("Create a billing client company")

  val updateCompanyEndpoint = secureEndpoint.put
    .in("api" / "billing" / "companies" / path[String]("id"))
    .in(jsonBody[CreateClientCompanyRequest])
    .out(jsonBody[ClientCompany])
    .tag(companyTag)
    .summary("Update a billing client company")

  val deleteCompanyEndpoint = secureEndpoint.delete
    .in("api" / "billing" / "companies" / path[String]("id"))
    .out(statusCode(StatusCode.NoContent))
    .tag(companyTag)
    .summary("Delete a billing client company")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    listCompaniesEndpoint,
    createCompanyEndpoint,
    updateCompanyEndpoint,
    deleteCompanyEndpoint
  )

  // ======================================================================
  // Server logic
  // ======================================================================

  private val listCompaniesServer: ZServerEndpoint[BillingCompanyEnv, Any] = listCompaniesEndpoint.serverLogic {
    user => _ =>
      for {
        companyId <- requireCompanyId(user.companyId)
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        repo      <- ZIO.service[ClientCompanyRepository]
        companies <- repo.findByTaxiCompany(companyId).mapError(_ => internalError)
      } yield companies
  }

  private val createCompanyServer: ZServerEndpoint[BillingCompanyEnv, Any] = createCompanyEndpoint.serverLogic {
    user => req =>
      for {
        companyId <- requireCompanyId(user.companyId)
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[ClientCompanyRepository]
        company   <- repo.create(req, companyId).mapError(_ => internalError)
      } yield company
  }

  private val updateCompanyServer: ZServerEndpoint[BillingCompanyEnv, Any] = updateCompanyEndpoint.serverLogic {
    user => (id, req) =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        ccId      <- parseClientCompanyId(id)
        repo      <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: update is not scoped by taxi_company_id, so
        // verify ownership first; a cross-tenant id resolves to NotFound.
        existing  <- repo.findById(ccId).mapError(_ => internalError)
        result    <-
          existing.filter(_.taxiCompanyId == companyId) match
            case None    => ZIO.none
            case Some(_) => repo.update(ccId, companyId, req).mapError(_ => internalError)
        company   <- ZIO
                       .fromOption(result)
                       .orElseFail((StatusCode.NotFound, ApiError("Not found")))
      } yield company
  }

  private val deleteCompanyServer: ZServerEndpoint[BillingCompanyEnv, Any] = deleteCompanyEndpoint.serverLogic {
    user => id =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        ccId      <- parseClientCompanyId(id)
        repo      <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: delete is not scoped by taxi_company_id, so
        // verify ownership first; a cross-tenant id resolves to NotFound.
        existing  <- repo.findById(ccId).mapError(_ => internalError)
        deleted   <-
          existing.filter(_.taxiCompanyId == companyId) match
            case None    => ZIO.succeed(false)
            case Some(_) => repo.delete(ccId, companyId).mapError(_ => internalError)
        _         <- ZIO
                       .fail((StatusCode.NotFound, ApiError("Not found")))
                       .when(!deleted)
      } yield ()
  }

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[BillingCompanyEnv, Any]] = List(
    listCompaniesServer,
    createCompanyServer,
    updateCompanyServer,
    deleteCompanyServer
  )
