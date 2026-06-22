package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{ClientCompanyRepository, PersonRepository}
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the core client-company endpoints (`/api/client-companies`). Replaces the
 * hand-written zio-http handlers in `ClientCompanyRoutes` while preserving paths, role checks, taxi-company isolation,
 * status codes and error mapping.
 *
 * The original handlers fail with explicit `Response`s for "Access denied" (403) and "Cannot delete company with active
 * members" (409); those statuses are reproduced here. Every other non-`Response` failure (e.g. "ClientCompany not
 * found", repository errors) is routed through `RouteErrorHandler` to a 500, reproduced via `internal`.
 */
object ClientCompanyApi:

  import AppSecure.*
  import ApiSchemas.given

  private val clientCompanyTag = "ClientCompany"

  type ClientCompanyEnv = JwtService & ClientCompanyRepository & PersonRepository

  private val accessDenied: Err = (StatusCode.Forbidden, ApiError("Access denied"))

  // -- Endpoint descriptions ------------------------------------------------

  val listEndpoint = secureEndpoint.get
    .in("api" / "client-companies")
    .out(jsonBody[List[ClientCompany]])
    .tag(clientCompanyTag)
    .summary("List client companies for the taxi company (dispatcher, secretary, admin)")

  val createEndpoint = secureEndpoint.post
    .in("api" / "client-companies")
    .in(jsonBody[CreateClientCompanyRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[ClientCompany]))
    .tag(clientCompanyTag)
    .summary("Create a client company (dispatcher, admin)")

  val membersEndpoint = secureEndpoint.get
    .in("api" / "client-companies" / path[String]("id") / "members")
    .out(jsonBody[List[PersonDto]])
    .tag(clientCompanyTag)
    .summary("List members of a client company (dispatcher, secretary, admin)")

  val getEndpoint = secureEndpoint.get
    .in("api" / "client-companies" / path[String]("id"))
    .out(jsonBody[ClientCompany])
    .tag(clientCompanyTag)
    .summary("Get a client company by id (dispatcher, secretary, admin)")

  val updateEndpoint = secureEndpoint.put
    .in("api" / "client-companies" / path[String]("id"))
    .in(jsonBody[CreateClientCompanyRequest])
    .out(jsonBody[ClientCompany])
    .tag(clientCompanyTag)
    .summary("Update a client company (dispatcher, admin)")

  val deleteEndpoint = secureEndpoint.delete
    .in("api" / "client-companies" / path[String]("id"))
    .out(statusCode)
    .tag(clientCompanyTag)
    .summary("Delete a client company (dispatcher, admin)")

  val endpoints = List(listEndpoint, createEndpoint, membersEndpoint, getEndpoint, updateEndpoint, deleteEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val listServer: ZServerEndpoint[ClientCompanyEnv, Any] = listEndpoint.serverLogic[ClientCompanyEnv] {
    user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[ClientCompanyRepository]
        companies <- repo.findByTaxiCompany(companyId).mapError(internal)
      } yield companies
  }

  private val createServer: ZServerEndpoint[ClientCompanyEnv, Any] = createEndpoint.serverLogic[ClientCompanyEnv] {
    user => req =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[ClientCompanyRepository]
        company    = ClientCompany(
                       id = ClientCompanyId.generate(),
                       name = req.name,
                       taxiCompanyId = companyId,
                       email = req.email,
                       phone = req.phone,
                       address = req.address,
                       preferredLanguage = req.preferredLanguage,
                       airportBufferMinutes = req.airportBufferMinutes,
                       airportCheckInCloseMinutes = req.airportCheckInCloseMinutes
                     )
        created   <- repo.create(company).mapError(internal)
      } yield created
  }

  private val getServer: ZServerEndpoint[ClientCompanyEnv, Any] = getEndpoint.serverLogic[ClientCompanyEnv] {
    user => id =>
      for {
        _               <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        taxiCompanyId   <- requireCompanyId(user.companyId)
        clientCompanyId <- parseUuid(id).map(ClientCompanyId(_))
        repo            <- ZIO.service[ClientCompanyRepository]
        company         <- repo
                             .findById(clientCompanyId)
                             .mapError(internal)
                             .someOrFail(internal(new RuntimeException(s"ClientCompany not found: $id")))
        _               <- ZIO.fail(accessDenied).when(company.taxiCompanyId != taxiCompanyId)
      } yield company
  }

  private val updateServer: ZServerEndpoint[ClientCompanyEnv, Any] = updateEndpoint.serverLogic[ClientCompanyEnv] {
    user =>
      { case (id, req) =>
        for {
          _               <- checkRole(user, "DISPATCHER", "ADMIN")
          taxiCompanyId   <- requireCompanyId(user.companyId)
          clientCompanyId <- parseUuid(id).map(ClientCompanyId(_))
          repo            <- ZIO.service[ClientCompanyRepository]
          existing        <- repo
                               .findById(clientCompanyId)
                               .mapError(internal)
                               .someOrFail(internal(new RuntimeException(s"ClientCompany not found: $id")))
          _               <- ZIO.fail(accessDenied).when(existing.taxiCompanyId != taxiCompanyId)
          updated         <- repo
                               .update(
                                 existing.copy(
                                   name = req.name,
                                   email = req.email,
                                   phone = req.phone,
                                   address = req.address,
                                   preferredLanguage = req.preferredLanguage,
                                   airportBufferMinutes = req.airportBufferMinutes,
                                   airportCheckInCloseMinutes = req.airportCheckInCloseMinutes
                                 )
                               )
                               .mapError(internal)
        } yield updated
      }
  }

  private val deleteServer: ZServerEndpoint[ClientCompanyEnv, Any] = deleteEndpoint.serverLogic[ClientCompanyEnv] {
    user => id =>
      for {
        _               <- checkRole(user, "DISPATCHER", "ADMIN")
        taxiCompanyId   <- requireCompanyId(user.companyId)
        clientCompanyId <- parseUuid(id).map(ClientCompanyId(_))
        repo            <- ZIO.service[ClientCompanyRepository]
        existing        <- repo
                             .findById(clientCompanyId)
                             .mapError(internal)
                             .someOrFail(internal(new RuntimeException(s"ClientCompany not found: $id")))
        _               <- ZIO.fail(accessDenied).when(existing.taxiCompanyId != taxiCompanyId)
        personRepo      <- ZIO.service[PersonRepository]
        members         <- personRepo.findByClientCompany(clientCompanyId).mapError(internal)
        _               <- ZIO
                             .fail(
                               (
                                 StatusCode.Conflict,
                                 ApiError(s"Cannot delete company with ${members.size} active members")
                               ): Err
                             )
                             .when(members.nonEmpty)
        deleted         <- repo.delete(clientCompanyId, taxiCompanyId).mapError(internal)
      } yield if deleted then StatusCode.NoContent else StatusCode.NotFound
  }

  private val membersServer: ZServerEndpoint[ClientCompanyEnv, Any] = membersEndpoint.serverLogic[ClientCompanyEnv] {
    user => id =>
      for {
        _               <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        taxiCompanyId   <- requireCompanyId(user.companyId)
        clientCompanyId <- parseUuid(id).map(ClientCompanyId(_))
        repo            <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: only expose members of a client company that
        // belongs to the caller's taxi company. Otherwise NotFound to avoid
        // leaking cross-tenant existence.
        clientCompany   <- repo.findById(clientCompanyId).mapError(internal)
        members         <-
          clientCompany.filter(_.taxiCompanyId == taxiCompanyId) match
            case None    => ZIO.fail((StatusCode.NotFound, ApiError("Not found")): Err)
            case Some(_) =>
              for {
                personRepo <- ZIO.service[PersonRepository]
                ms         <- personRepo.findByClientCompany(clientCompanyId).mapError(internal)
              } yield ms
      } yield members.map(PersonDto.fromPerson)
  }

  // Static sub-path (/{id}/members) precedes the bare /{id} matcher.
  val serverEndpoints: List[ZServerEndpoint[ClientCompanyEnv, Any]] = List(
    membersServer,
    listServer,
    createServer,
    getServer,
    updateServer,
    deleteServer
  )
