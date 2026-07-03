package com.shevchyk.billing.application

import java.time.LocalDate
import java.util.UUID

import zio.*
import zio.test.*

import com.shevchyk.billing.domain.{Invoice, InvoiceId, InvoiceStatus}
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}

/**
 * Pins the INTENTIONAL behaviour of the mock [[PaymentChecker]] (audit item: "PaymentChecker — permanent mock").
 *
 * There is no banking integration yet — by design, `mockLayer.isPaid` reports `false` for EVERY invoice, so the
 * reminder scheduler never auto-marks an invoice paid and the manual `markPaid` endpoint stays the only way a payment
 * is recorded. This spec locks that contract in so the mock is never mistaken for a bug (nor silently flipped to
 * `true`, which would make the scheduler mark unpaid invoices as paid). When the real banking-API implementation lands,
 * it must replace `mockLayer` in `Application.scala` and bring its own spec.
 */
object PaymentCheckerSpec extends ZIOSpecDefault:

  private def invoice(status: InvoiceStatus): Invoice = Invoice(
    id = InvoiceId(UUID.randomUUID()),
    number = "INV-2026-00001",
    clientCompanyId = ClientCompanyId(UUID.randomUUID()),
    taxiCompanyId = CompanyId(UUID.randomUUID()),
    status = status,
    periodFrom = LocalDate.parse("2026-06-01"),
    periodTo = LocalDate.parse("2026-06-30"),
    subtotalAmount = BigDecimal("100.00"),
    taxRate = BigDecimal("19.00"),
    taxAmount = BigDecimal("19.00"),
    totalAmount = BigDecimal("119.00"),
    dueDate = Some(LocalDate.parse("2026-07-14"))
  )

  def spec =
    suite("PaymentChecker.mockLayer (intentional stub — no banking integration)")(
      test("isPaid reports false for every invoice regardless of status") {
        for {
          checker <- ZIO.service[PaymentChecker]
          results <- ZIO.foreach(InvoiceStatus.values.toList)(st => checker.isPaid(invoice(st)))
        } yield assertTrue(results.nonEmpty, results.forall(_ == false))
      }.provide(PaymentChecker.mockLayer)
    )
