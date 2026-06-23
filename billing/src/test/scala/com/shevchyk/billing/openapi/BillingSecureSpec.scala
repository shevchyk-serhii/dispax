package com.shevchyk.billing.openapi

import com.shevchyk.billing.domain.{InvoiceError, InvoiceId, InvoiceStatus}
import sttp.model.StatusCode
import zio.test.*

import java.util.UUID

/**
 * Guards against regressing `fromInvoiceError` into a partial match: every `InvoiceError` case must map to a status
 * code (previously `RideNotBillable` and `NoRecipientEmail` were missing, crashing the request with a MatchError).
 */
object BillingSecureSpec extends ZIOSpecDefault:

  private val invoiceId = InvoiceId(UUID.randomUUID())

  private val allErrors: List[InvoiceError] = List(
    InvoiceError.NotFound(invoiceId),
    InvoiceError.ClientCompanyNotFound(UUID.randomUUID()),
    InvoiceError.InvalidStatus(InvoiceStatus.Draft, "Sent"),
    InvoiceError.NotDraft(invoiceId),
    InvoiceError.EmptyInvoice(invoiceId),
    InvoiceError.RideNotBillable(UUID.randomUUID()),
    InvoiceError.NoRecipientEmail(invoiceId),
    InvoiceError.InvalidTaxRate(BigDecimal("-100")),
    InvoiceError.DatabaseError(new RuntimeException("boom")),
    InvoiceError.PdfGenerationError(new RuntimeException("boom")),
    InvoiceError.EmailDeliveryError(new RuntimeException("boom"))
  )

  def spec =
    suite("BillingSecure.fromInvoiceError")(
      test("maps every InvoiceError case without throwing") {
        assertTrue(allErrors.map(e => BillingSecure.fromInvoiceError(e)._1).forall(_.code > 0))
      },
      test("RideNotBillable maps to 400") {
        val (code, _) = BillingSecure.fromInvoiceError(InvoiceError.RideNotBillable(UUID.randomUUID()))
        assertTrue(code == StatusCode.BadRequest)
      },
      test("NoRecipientEmail maps to 400") {
        val (code, _) = BillingSecure.fromInvoiceError(InvoiceError.NoRecipientEmail(invoiceId))
        assertTrue(code == StatusCode.BadRequest)
      },
      test("EmptyInvoice maps to 409") {
        val (code, _) = BillingSecure.fromInvoiceError(InvoiceError.EmptyInvoice(invoiceId))
        assertTrue(code == StatusCode.Conflict)
      },
      test("InvalidTaxRate maps to 400") {
        val (code, _) = BillingSecure.fromInvoiceError(InvoiceError.InvalidTaxRate(BigDecimal("-100")))
        assertTrue(code == StatusCode.BadRequest)
      },
      // -- Audit fix: paging clamp used by listInvoices ---------------------------
      test("Paging.clampLimit caps an oversized limit and floors a non-positive one") {
        assertTrue(
          BillingSecure.Paging.clampLimit(999999) == 100,
          BillingSecure.Paging.clampLimit(0) == 1,
          BillingSecure.Paging.clampLimit(-5) == 1,
          BillingSecure.Paging.clampLimit(50) == 50
        )
      },
      test("Paging.clampOffset floors a negative offset to 0") {
        assertTrue(
          BillingSecure.Paging.clampOffset(-5) == 0,
          BillingSecure.Paging.clampOffset(0) == 0,
          BillingSecure.Paging.clampOffset(20) == 20
        )
      }
    )
