package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.CompanySettingsRepository
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object CompanySettingsRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("CompanySettings")(ex)

  val authenticatedRoutes: Routes[CompanySettingsRepository & JwtService, Response] = Routes(
    // GET /api/company/settings
    Method.GET / "api" / "company" / "settings" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        settings  <- repo.findByCompanyId(companyId)
        result     = settings.getOrElse(CompanySettings(companyId = companyId))
      } yield Response.json(result.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // PUT /api/company/settings
    Method.PUT / "api" / "company" / "settings" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        bodyStr   <- request.body.asString
        updateReq <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateCompanySettingsRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo      <- ZIO.service[CompanySettingsRepository]
        existing  <- repo.findByCompanyId(companyId)
        current    = existing.getOrElse(CompanySettings(companyId = companyId))
        updated    = current.copy(
                       commissionRate = updateReq.commissionRate.getOrElse(current.commissionRate),
                       workingHoursStart = updateReq.workingHoursStart.getOrElse(current.workingHoursStart),
                       workingHoursEnd = updateReq.workingHoursEnd.getOrElse(current.workingHoursEnd),
                       defaultCurrency = updateReq.defaultCurrency.getOrElse(current.defaultCurrency),
                       cancellationFeeDefault = updateReq.cancellationFeeDefault.getOrElse(current.cancellationFeeDefault),
                       noShowFee = updateReq.noShowFee.getOrElse(current.noShowFee),
                       autoAssignEnabled = updateReq.autoAssignEnabled.getOrElse(current.autoAssignEnabled),
                       updatedAt = Instant.now()
                     )
        saved     <- repo.upsert(updated)
      } yield Response.json(saved.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // GET /api/company/tariff
    Method.GET / "api" / "company" / "tariff" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "DRIVER", "CLIENT", "SECRETARY")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        settings  <- repo.findByCompanyId(companyId)
        result     = settings.getOrElse(CompanySettings(companyId = companyId))
        tariffJson =
          s"""{
          "commissionRate": ${result.commissionRate},
          "defaultCurrency": "${result.defaultCurrency}",
          "cancellationFeeDefault": ${result.cancellationFeeDefault},
          "noShowFee": ${result.noShowFee}
        }"""
      } yield Response.json(tariffJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // PUT /api/company/tariff
    Method.PUT / "api" / "company" / "tariff" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        bodyStr   <- request.body.asString
        updateReq <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateCompanySettingsRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo      <- ZIO.service[CompanySettingsRepository]
        existing  <- repo.findByCompanyId(companyId)
        current    = existing.getOrElse(CompanySettings(companyId = companyId))
        updated    = current.copy(
                       commissionRate = updateReq.commissionRate.getOrElse(current.commissionRate),
                       defaultCurrency = updateReq.defaultCurrency.getOrElse(current.defaultCurrency),
                       cancellationFeeDefault = updateReq.cancellationFeeDefault.getOrElse(current.cancellationFeeDefault),
                       noShowFee = updateReq.noShowFee.getOrElse(current.noShowFee),
                       updatedAt = Instant.now()
                     )
        saved     <- repo.upsert(updated)
      } yield Response.json(saved.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
