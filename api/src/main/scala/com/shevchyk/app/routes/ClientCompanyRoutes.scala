package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{ClientCompanyRepository, PersonRepository}
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

object ClientCompanyRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("ClientCompany")(ex)

  val authenticatedRoutes: Routes[ClientCompanyRepository & PersonRepository & JwtService, Response] = Routes(
    // GET /api/client-companies — list all client companies for taxi company
    Method.GET / "api" / "client-companies" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[ClientCompanyRepository]
        companies <- repo.findByTaxiCompany(companyId)
      } yield Response.json(companies.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // POST /api/client-companies — create a new client company
    Method.POST / "api" / "client-companies" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
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
      } yield Response.json(created.toJson).status(Status.Created)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // GET /api/client-companies/:id — get a client company by id
    Method.GET / "api" / "client-companies" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user            <- AuthMiddleware.authenticateRequest(request)
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
      } yield Response.json(company.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // PUT /api/client-companies/:id — update a client company
    Method.PUT / "api" / "client-companies" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user            <- AuthMiddleware.authenticateRequest(request)
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
      } yield Response.json(updated.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // DELETE /api/client-companies/:id — delete a client company
    Method.DELETE / "api" / "client-companies" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user            <- AuthMiddleware.authenticateRequest(request)
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
        response         =
          if deleted then Response.status(Status.NoContent)
          else Response.status(Status.NotFound)
      } yield response).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // GET /api/client-companies/:id/members — list persons belonging to a client company
    Method.GET / "api" / "client-companies" / string("id") / "members" -> handler { (id: String, request: Request) =>
      (for {
        user            <- AuthMiddleware.authenticateRequest(request)
        _               <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        clientCompanyId <- UuidParser.parseClientCompanyId(id)
        personRepo      <- ZIO.service[PersonRepository]
        members         <- personRepo.findByClientCompany(clientCompanyId)
        dtos             = members.map(PersonDto.fromPerson)
      } yield Response.json(dtos.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
