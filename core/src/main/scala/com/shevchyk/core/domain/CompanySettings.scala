package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant

final case class CompanySettings(
    companyId: CompanyId,
    commissionRate: BigDecimal = BigDecimal(15.00),
    workingHoursStart: String = "06:00",
    workingHoursEnd: String = "22:00",
    defaultCurrency: String = "EUR",
    cancellationFeeDefault: BigDecimal = BigDecimal(0),
    noShowFee: BigDecimal = BigDecimal(0),
    autoAssignEnabled: Boolean = false,
    updatedAt: Instant = Instant.now(),
    datevBeraternummer: Option[String] = None,
    datevMandantennummer: Option[String] = None,
    datevSachkontenlaenge: Option[Int] = None,
    // Airport departure pickup timing overrides (NULL = use global default).
    airportBufferMinutes: Option[Int] = None,
    airportCheckInCloseMinutes: Option[Int] = None
) derives JsonCodec

final case class UpdateCompanySettingsRequest(
    commissionRate: Option[BigDecimal] = None,
    workingHoursStart: Option[String] = None,
    workingHoursEnd: Option[String] = None,
    defaultCurrency: Option[String] = None,
    cancellationFeeDefault: Option[BigDecimal] = None,
    noShowFee: Option[BigDecimal] = None,
    autoAssignEnabled: Option[Boolean] = None,
    datevBeraternummer: Option[String] = None,
    datevMandantennummer: Option[String] = None,
    datevSachkontenlaenge: Option[Int] = None,
    // Airport departure pickup timing overrides (absent = leave unchanged).
    airportBufferMinutes: Option[Int] = None,
    airportCheckInCloseMinutes: Option[Int] = None
) derives JsonCodec:

  /**
   * Apply the patch onto an existing settings object. Unset fields keep their current value; `updatedAt` is refreshed.
   */
  def applyTo(current: CompanySettings): CompanySettings = current.copy(
    commissionRate = commissionRate.getOrElse(current.commissionRate),
    workingHoursStart = workingHoursStart.getOrElse(current.workingHoursStart),
    workingHoursEnd = workingHoursEnd.getOrElse(current.workingHoursEnd),
    defaultCurrency = defaultCurrency.getOrElse(current.defaultCurrency),
    cancellationFeeDefault = cancellationFeeDefault.getOrElse(current.cancellationFeeDefault),
    noShowFee = noShowFee.getOrElse(current.noShowFee),
    autoAssignEnabled = autoAssignEnabled.getOrElse(current.autoAssignEnabled),
    datevBeraternummer = datevBeraternummer.orElse(current.datevBeraternummer),
    datevMandantennummer = datevMandantennummer.orElse(current.datevMandantennummer),
    datevSachkontenlaenge = datevSachkontenlaenge.orElse(current.datevSachkontenlaenge),
    airportBufferMinutes = airportBufferMinutes.orElse(current.airportBufferMinutes),
    airportCheckInCloseMinutes = airportCheckInCloseMinutes.orElse(current.airportCheckInCloseMinutes),
    updatedAt = Instant.now()
  )
