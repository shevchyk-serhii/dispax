package com.shevchyk.core.domain

import zio.json.*
import java.time.{Instant, LocalTime}
import java.util.UUID

final case class CompanySettings(
    companyId: CompanyId,
    commissionRate: BigDecimal = BigDecimal(15.00),
    workingHoursStart: String = "06:00",
    workingHoursEnd: String = "22:00",
    defaultCurrency: String = "EUR",
    cancellationFeeDefault: BigDecimal = BigDecimal(0),
    noShowFee: BigDecimal = BigDecimal(0),
    autoAssignEnabled: Boolean = false,
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class UpdateCompanySettingsRequest(
    commissionRate: Option[BigDecimal] = None,
    workingHoursStart: Option[String] = None,
    workingHoursEnd: Option[String] = None,
    defaultCurrency: Option[String] = None,
    cancellationFeeDefault: Option[BigDecimal] = None,
    noShowFee: Option[BigDecimal] = None,
    autoAssignEnabled: Option[Boolean] = None
) derives JsonCodec
