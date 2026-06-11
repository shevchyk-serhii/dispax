package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{ClientCompanyRepository, PersonRepository}
import zio.*
import zio.http.*
import zio.json.*

object ClientCompanyRoutes:

  val authenticatedRoutes: Routes[ClientCompanyRepository & PersonRepository & JwtService, Response] = Routes(
    // GET /api/client-companies — list all client companies for taxi company
    Method.GET / "api" / "client-companies" -> RouteHelpers.authHandler("ClientCompany") { (user, _) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[ClientCompanyRepository]
        companies <- repo.findByTaxiCompany(companyId)
      } yield Response.json(companies.toJson)
    },

    // POST /api/client-companies — create a new client company
    Method.POST / "api" / "client-companies" -> RouteHelpers.authHandler("ClientCompany") { (user, request) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[CreateClientCompanyRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo      <- ZIO.service[ClientCompanyRepository]
        company    = ClientCompany(
                       id = ClientCompanyId.generate(),
                       name = req.name,
                       taxiCompanyId = companyId,
                       email = req.email,
                       phone = req.phone,
                       address = req.address
                     )
        created   <- repo.create(company)
      } yield Response.json(created.toJson).status(Status.Created)
    },

    // GET /api/client-companies/:id — get a client company by id
    Method.GET / "api" / "client-companies" / string("id") -> RouteHelpers.authPathHandler("ClientCompany") {
      (user, id: String, _) =>
        for {
          _               <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
          taxiCompanyId   <- UuidParser.requireCompanyId(user.companyId)
          clientCompanyId <- UuidParser.parseClientCompanyId(id)
          repo            <- ZIO.service[ClientCompanyRepository]
          company         <- repo
                               .findById(clientCompanyId)
                               .flatMap(ZIO.fromOption(_).mapError(_ => new RuntimeException(s"ClientCompany not found: $id")))
          _               <-
            ZIO.when(company.taxiCompanyId != taxiCompanyId)(
              ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
            )
        } yield Response.json(company.toJson)
    },

    // PUT /api/client-companies/:id — update a client company
    Method.PUT / "api" / "client-companies" / string("id") -> RouteHelpers.authPathHandler("ClientCompany") {
      (user, id: String, request) =>
        for {
          _               <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          taxiCompanyId   <- UuidParser.requireCompanyId(user.companyId)
          clientCompanyId <- UuidParser.parseClientCompanyId(id)
          bodyStr         <- request.body.asString
          req             <- ZIO
                               .fromEither(bodyStr.fromJson[CreateClientCompanyRequest])
                               .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          repo            <- ZIO.service[ClientCompanyRepository]
          existing        <- repo
                               .findById(clientCompanyId)
                               .flatMap(ZIO.fromOption(_).mapError(_ => new RuntimeException(s"ClientCompany not found: $id")))
          _               <-
            ZIO.when(existing.taxiCompanyId != taxiCompanyId)(
              ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
            )
          updated         <- repo.update(
                               existing.copy(
                                 name = req.name,
                                 email = req.email,
                                 phone = req.phone,
                                 address = req.address
                               )
                             )
        } yield Response.json(updated.toJson)
    },

    // DELETE /api/client-companies/:id — delete a client company
    Method.DELETE / "api" / "client-companies" / string("id") -> RouteHelpers.authPathHandler("ClientCompany") {
      (user, id: String, _) =>
        for {
          _               <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          taxiCompanyId   <- UuidParser.requireCompanyId(user.companyId)
          clientCompanyId <- UuidParser.parseClientCompanyId(id)
          repo            <- ZIO.service[ClientCompanyRepository]
          existing        <- repo
                               .findById(clientCompanyId)
                               .flatMap(ZIO.fromOption(_).mapError(_ => new RuntimeException(s"ClientCompany not found: $id")))
          _               <-
            ZIO.when(existing.taxiCompanyId != taxiCompanyId)(
              ZIO.fail(Response(Status.Forbidden, body = Body.fromString("""{"error":"Access denied"}""")))
            )
          personRepo      <- ZIO.service[PersonRepository]
          members         <- personRepo.findByClientCompany(clientCompanyId)
          _               <-
            ZIO.when(members.nonEmpty)(
              ZIO.fail(
                Response(
                  Status.Conflict,
                  body = Body.fromString(s"""{"error":"Cannot delete company with ${members.size} active members"}""")
                )
              )
            )
          deleted         <- repo.delete(clientCompanyId)
        } yield if deleted then Response.status(Status.NoContent) else Response.status(Status.NotFound)
    },

    // GET /api/client-companies/:id/members — list persons belonging to a client company
    Method.GET / "api" / "client-companies" / string("id") / "members" -> RouteHelpers.authPathHandler(
      "ClientCompany"
    ) { (user, id: String, _) =>
      for {
        _               <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        taxiCompanyId   <- UuidParser.requireCompanyId(user.companyId)
        clientCompanyId <- UuidParser.parseClientCompanyId(id)
        repo            <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: only expose members of a client company that
        // belongs to the caller's taxi company. Otherwise NotFound to avoid
        // leaking cross-tenant existence.
        clientCompany   <- repo.findById(clientCompanyId)
        response        <-
          clientCompany.filter(_.taxiCompanyId == taxiCompanyId) match {
            case None    => ZIO.succeed(Response.status(Status.NotFound))
            case Some(_) =>
              for {
                personRepo <- ZIO.service[PersonRepository]
                members    <- personRepo.findByClientCompany(clientCompanyId)
                dtos        = members.map(PersonDto.fromPerson)
              } yield Response.json(dtos.toJson)
          }
      } yield response
    }
  )
