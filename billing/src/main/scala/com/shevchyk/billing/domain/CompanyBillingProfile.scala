package com.shevchyk.billing.domain

import com.shevchyk.core.domain.CompanyId
import zio.json.*

import java.time.Instant

/**
 * Issuer (taxi company) details required to render a legally complete invoice (Rechnung).
 */
final case class CompanyBillingProfile(
    companyId: CompanyId,
    businessType: Option[String] = None,
    legalName: Option[String] = None,
    addressLine1: Option[String] = None,
    addressLine2: Option[String] = None,
    phone: Option[String] = None,
    email: Option[String] = None,
    taxNumber: Option[String] = None,
    vatId: Option[String] = None,
    bankName: Option[String] = None,
    bankAccountNo: Option[String] = None,
    bankCode: Option[String] = None,
    iban: Option[String] = None,
    bic: Option[String] = None,
    paymentTermsDays: Int = 7,
    invoiceIntro: Option[String] = None,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class UpdateCompanyBillingProfileRequest(
    businessType: Option[String] = None,
    legalName: Option[String] = None,
    addressLine1: Option[String] = None,
    addressLine2: Option[String] = None,
    phone: Option[String] = None,
    email: Option[String] = None,
    taxNumber: Option[String] = None,
    vatId: Option[String] = None,
    bankName: Option[String] = None,
    bankAccountNo: Option[String] = None,
    bankCode: Option[String] = None,
    iban: Option[String] = None,
    bic: Option[String] = None,
    paymentTermsDays: Option[Int] = None,
    invoiceIntro: Option[String] = None
) derives JsonCodec
