package com.shevchyk.billing.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.domain.{CompanyBillingProfile, UpdateCompanyBillingProfileRequest}
import com.shevchyk.billing.repository.CompanyBillingProfileRepository
import zio.*
import zio.http.*
import zio.json.*

object BillingProfileRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"BillingProfile error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[CompanyBillingProfileRepository & JwtService, Response] = Routes(
    // GET /api/billing/profile — issuer details for the current company's invoices
    Method.GET / "api" / "billing" / "profile" -> authenticatedHandler[CompanyBillingProfileRepository] { (user, _) =>
      (for {
        companyId <- UuidParser.requireCompanyId(user.companyId)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[CompanyBillingProfileRepository]
        profile   <- repo.findByCompany(companyId)
      } yield profile match
        case Some(p) => Response.json(p.toJson)
        case None    => Response.json(CompanyBillingProfile(companyId).toJson)
      ).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    },

    // PUT /api/billing/profile — create or update issuer details
    Method.PUT / "api" / "billing" / "profile" -> authenticatedJsonHandler[
      CompanyBillingProfileRepository,
      UpdateCompanyBillingProfileRequest
    ] { (user, req) =>
      (for {
        companyId <- UuidParser.requireCompanyId(user.companyId)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        repo      <- ZIO.service[CompanyBillingProfileRepository]
        profile   <- repo.upsert(companyId, req)
      } yield Response.json(profile.toJson)).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => handleError(e)
      }
    }
  )
