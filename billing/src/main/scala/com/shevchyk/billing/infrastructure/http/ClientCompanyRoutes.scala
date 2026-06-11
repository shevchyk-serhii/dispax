package com.shevchyk.billing.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.repository.ClientCompanyRepository
import com.shevchyk.core.domain.{ClientCompanyId, CreateClientCompanyRequest}
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

object ClientCompanyRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"ClientCompany error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[ClientCompanyRepository & JwtService, Response] = Routes(
    // GET /api/billing/companies
    Method.GET / "api" / "billing" / "companies" -> authenticatedHandler[ClientCompanyRepository] { (user, _) =>
      (for {
        companyId <- UuidParser.requireCompanyId(user.companyId)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        repo      <- ZIO.service[ClientCompanyRepository]
        companies <- repo.findByTaxiCompany(companyId)
      } yield Response.json(companies.toJson)).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    },

    // POST /api/billing/companies
    Method.POST / "api" / "billing" / "companies" -> authenticatedJsonHandler[
      ClientCompanyRepository,
      CreateClientCompanyRequest
    ] { (user, req) =>
      (for {
        companyId <- UuidParser.requireCompanyId(user.companyId)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[ClientCompanyRepository]
        company   <- repo.create(req, companyId)
      } yield Response(Status.Created, body = Body.fromString(company.toJson))).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    },

    // PUT /api/billing/companies/:id
    Method.PUT / "api" / "billing" / "companies" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        ccId      <- ZIO.attempt(ClientCompanyId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[CreateClientCompanyRequest])
                       .mapError(e => new RuntimeException(s"Invalid JSON: $e"))
        repo      <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: update is not scoped by taxi_company_id, so
        // verify ownership first; a cross-tenant id resolves to NotFound.
        existing  <- repo.findById(ccId)
        result    <-
          existing.filter(_.taxiCompanyId == companyId) match
            case None    => ZIO.none
            case Some(_) => repo.update(ccId, req)
      } yield result match
        case Some(c) => Response.json(c.toJson)
        case None    => Response.status(Status.NotFound)
      ).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    },

    // DELETE /api/billing/companies/:id
    Method.DELETE / "api" / "billing" / "companies" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        ccId      <- ZIO.attempt(ClientCompanyId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        repo      <- ZIO.service[ClientCompanyRepository]
        // Enforce tenant isolation: delete is not scoped by taxi_company_id, so
        // verify ownership first; a cross-tenant id resolves to NotFound.
        existing  <- repo.findById(ccId)
        deleted   <-
          existing.filter(_.taxiCompanyId == companyId) match
            case None    => ZIO.succeed(false)
            case Some(_) => repo.delete(ccId)
        status     = if deleted then Status.NoContent else Status.NotFound
      } yield Response.status(status)).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    }
  )
