package com.shevchyk.billing.repository

import com.shevchyk.billing.domain.{CompanyBillingProfile, UpdateCompanyBillingProfileRequest}
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.domain.CompanyId
import doobie.*
import doobie.implicits.*
import doobie.implicits.javasql.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, OffsetDateTime, ZoneOffset}
import java.util.UUID

trait CompanyBillingProfileRepository:
  def findByCompany(companyId: CompanyId): Task[Option[CompanyBillingProfile]]
  def upsert(companyId: CompanyId, req: UpdateCompanyBillingProfileRequest): Task[CompanyBillingProfile]

object CompanyBillingProfileRepository:

  val layer: ZLayer[Any, Throwable, CompanyBillingProfileRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresCompanyBillingProfileRepository.layer

final class PostgresCompanyBillingProfileRepository(xa: Transactor[Task]) extends CompanyBillingProfileRepository:

  implicit private val instantMeta: Meta[Instant] =
    Meta[OffsetDateTime].imap(_.toInstant)((i: Instant) => i.atOffset(ZoneOffset.UTC))

  private def toProfile(
      companyId: UUID,
      businessType: Option[String],
      legalName: Option[String],
      addressLine1: Option[String],
      addressLine2: Option[String],
      phone: Option[String],
      email: Option[String],
      taxNumber: Option[String],
      vatId: Option[String],
      bankName: Option[String],
      bankAccountNo: Option[String],
      bankCode: Option[String],
      iban: Option[String],
      bic: Option[String],
      paymentTermsDays: Int,
      invoiceIntro: Option[String],
      createdAt: Instant,
      updatedAt: Instant
  ): CompanyBillingProfile = CompanyBillingProfile(
    companyId = CompanyId(companyId),
    businessType = businessType,
    legalName = legalName,
    addressLine1 = addressLine1,
    addressLine2 = addressLine2,
    phone = phone,
    email = email,
    taxNumber = taxNumber,
    vatId = vatId,
    bankName = bankName,
    bankAccountNo = bankAccountNo,
    bankCode = bankCode,
    iban = iban,
    bic = bic,
    paymentTermsDays = paymentTermsDays,
    invoiceIntro = invoiceIntro,
    createdAt = createdAt,
    updatedAt = updatedAt
  )

  private type Row =
    (
        UUID,
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Option[String],
        Int,
        Option[String],
        Instant,
        Instant
    )

  private val selectCols =
    fr"""company_id, business_type, legal_name, address_line1, address_line2,
         phone, email, tax_number, vat_id,
         bank_name, bank_account_no, bank_code, iban, bic, payment_terms_days, invoice_intro,
         created_at, updated_at"""

  override def findByCompany(companyId: CompanyId): Task[Option[CompanyBillingProfile]] =
    (fr"SELECT" ++ selectCols ++ fr"FROM company_billing_profile WHERE company_id = ${companyId.value}")
      .query[Row]
      .option
      .transact(xa)
      .map(_.map(toProfile.tupled))

  override def upsert(companyId: CompanyId, req: UpdateCompanyBillingProfileRequest): Task[CompanyBillingProfile] =
    val termsDays = req.paymentTermsDays.getOrElse(7)
    sql"""
      INSERT INTO company_billing_profile
        (company_id, business_type, legal_name, address_line1, address_line2,
         phone, email, tax_number, vat_id,
         bank_name, bank_account_no, bank_code, iban, bic, payment_terms_days, invoice_intro)
      VALUES
        (${companyId.value}, ${req.businessType}, ${req.legalName}, ${req.addressLine1}, ${req.addressLine2},
         ${req.phone}, ${req.email}, ${req.taxNumber}, ${req.vatId},
         ${req.bankName}, ${req.bankAccountNo}, ${req.bankCode}, ${req.iban}, ${req.bic}, $termsDays,
         ${req.invoiceIntro})
      ON CONFLICT (company_id) DO UPDATE SET
        business_type      = EXCLUDED.business_type,
        legal_name         = EXCLUDED.legal_name,
        address_line1      = EXCLUDED.address_line1,
        address_line2      = EXCLUDED.address_line2,
        phone              = EXCLUDED.phone,
        email              = EXCLUDED.email,
        tax_number         = EXCLUDED.tax_number,
        vat_id             = EXCLUDED.vat_id,
        bank_name          = EXCLUDED.bank_name,
        bank_account_no    = EXCLUDED.bank_account_no,
        bank_code          = EXCLUDED.bank_code,
        iban               = EXCLUDED.iban,
        bic                = EXCLUDED.bic,
        payment_terms_days = EXCLUDED.payment_terms_days,
        invoice_intro      = EXCLUDED.invoice_intro,
        updated_at         = NOW()
    """.update.run
      .transact(xa)
      .zipRight(findByCompany(companyId))
      .flatMap(ZIO.fromOption(_).orElseFail(new RuntimeException("Failed to upsert billing profile")))

object PostgresCompanyBillingProfileRepository:

  val layer: ZLayer[Transactor[Task], Nothing, CompanyBillingProfileRepository] = ZLayer.fromFunction(
    PostgresCompanyBillingProfileRepository(_)
  )
