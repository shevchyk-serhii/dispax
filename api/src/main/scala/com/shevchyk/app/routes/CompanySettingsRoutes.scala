package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.CompanySettingsRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object CompanySettingsRoutes:

  val authenticatedRoutes: Routes[CompanySettingsRepository & JwtService, Response] = Routes(
    // GET /api/company/settings
    Method.GET / "api" / "company" / "settings" -> RouteHelpers.authHandler("CompanySettings") { (user, _) =>
      for {
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        settings  <- repo.findByCompanyId(companyId)
        result     = settings.getOrElse(CompanySettings(companyId = companyId))
      } yield Response.json(result.toJson)
    },

    // PUT /api/company/settings
    Method.PUT / "api" / "company" / "settings" -> RouteHelpers.authHandler("CompanySettings") { (user, request) =>
      for {
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
      } yield Response.json(saved.toJson)
    },

    // GET /api/company/tariff
    Method.GET / "api" / "company" / "tariff" -> RouteHelpers.authHandler("CompanySettings") { (user, _) =>
      for {
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
      } yield Response.json(tariffJson)
    },

    // PUT /api/company/tariff
    Method.PUT / "api" / "company" / "tariff" -> RouteHelpers.authHandler("CompanySettings") { (user, request) =>
      for {
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
      } yield Response.json(saved.toJson)
    }
  )
