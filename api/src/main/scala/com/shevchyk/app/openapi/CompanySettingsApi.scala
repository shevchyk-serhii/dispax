package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.CompanySettingsRepository
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the company-settings and tariff endpoints. Replaces the hand-written zio-http
 * handlers in `CompanySettingsRoutes` while preserving paths, role checks, company isolation, default settings, merge
 * semantics, status codes and error mapping.
 */
object CompanySettingsApi:

  import AppSecure.*
  import ApiSchemas.given

  private val settingsTag = "CompanySettings"

  /**
   * Tariff projection returned by GET/PUT /api/company/tariff.
   */
  final case class TariffDto(
      commissionRate: BigDecimal,
      defaultCurrency: String,
      cancellationFeeDefault: BigDecimal,
      noShowFee: BigDecimal
  ) derives JsonCodec

  type CompanySettingsEnv = JwtService & CompanySettingsRepository

  // -- Endpoint descriptions ------------------------------------------------

  val getSettingsEndpoint = secureEndpoint.get
    .in("api" / "company" / "settings")
    .out(jsonBody[CompanySettings])
    .tag(settingsTag)
    .summary("Get company settings (dispatcher, admin)")

  val updateSettingsEndpoint = secureEndpoint.put
    .in("api" / "company" / "settings")
    .in(jsonBody[UpdateCompanySettingsRequest])
    .out(jsonBody[CompanySettings])
    .tag(settingsTag)
    .summary("Update company settings (dispatcher, admin)")

  val getTariffEndpoint = secureEndpoint.get
    .in("api" / "company" / "tariff")
    .out(jsonBody[TariffDto])
    .tag(settingsTag)
    .summary("Get company tariff (all roles)")

  val updateTariffEndpoint = secureEndpoint.put
    .in("api" / "company" / "tariff")
    .in(jsonBody[UpdateCompanySettingsRequest])
    .out(jsonBody[CompanySettings])
    .tag(settingsTag)
    .summary("Update company tariff (dispatcher, admin)")

  val endpoints = List(getSettingsEndpoint, updateSettingsEndpoint, getTariffEndpoint, updateTariffEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val getSettingsServer: ZServerEndpoint[CompanySettingsEnv, Any] = getSettingsEndpoint
    .serverLogic[CompanySettingsEnv] { user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        settings  <- repo.findByCompanyId(companyId).mapError(internal)
      } yield settings.getOrElse(CompanySettings(companyId = companyId))
    }

  private val updateSettingsServer: ZServerEndpoint[CompanySettingsEnv, Any] = updateSettingsEndpoint
    .serverLogic[CompanySettingsEnv] { user => updateReq =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        existing  <- repo.findByCompanyId(companyId).mapError(internal)
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
        saved     <- repo.upsert(updated).mapError(internal)
      } yield saved
    }

  private val getTariffServer: ZServerEndpoint[CompanySettingsEnv, Any] = getTariffEndpoint
    .serverLogic[CompanySettingsEnv] { user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN", "DRIVER", "CLIENT", "SECRETARY")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        settings  <- repo.findByCompanyId(companyId).mapError(internal)
        result     = settings.getOrElse(CompanySettings(companyId = companyId))
      } yield TariffDto(
        commissionRate = result.commissionRate,
        defaultCurrency = result.defaultCurrency,
        cancellationFeeDefault = result.cancellationFeeDefault,
        noShowFee = result.noShowFee
      )
    }

  private val updateTariffServer: ZServerEndpoint[CompanySettingsEnv, Any] = updateTariffEndpoint
    .serverLogic[CompanySettingsEnv] { user => updateReq =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[CompanySettingsRepository]
        existing  <- repo.findByCompanyId(companyId).mapError(internal)
        current    = existing.getOrElse(CompanySettings(companyId = companyId))
        updated    = current.copy(
                       commissionRate = updateReq.commissionRate.getOrElse(current.commissionRate),
                       defaultCurrency = updateReq.defaultCurrency.getOrElse(current.defaultCurrency),
                       cancellationFeeDefault = updateReq.cancellationFeeDefault.getOrElse(current.cancellationFeeDefault),
                       noShowFee = updateReq.noShowFee.getOrElse(current.noShowFee),
                       updatedAt = Instant.now()
                     )
        saved     <- repo.upsert(updated).mapError(internal)
      } yield saved
    }

  val serverEndpoints: List[ZServerEndpoint[CompanySettingsEnv, Any]] = List(
    getSettingsServer,
    updateSettingsServer,
    getTariffServer,
    updateTariffServer
  )
