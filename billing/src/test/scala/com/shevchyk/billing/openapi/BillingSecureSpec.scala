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
    InvoiceError.RideNotBillable(UUID.randomUUID()),
    InvoiceError.NoRecipientEmail(invoiceId),
    InvoiceError.InvalidTaxRate(BigDecimal("-100")),
    InvoiceError.DatabaseError(new RuntimeException("boom")),
    InvoiceError.PdfGenerationError(new RuntimeException("boom"))
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
      test("InvalidTaxRate maps to 400") {
        val (code, _) = BillingSecure.fromInvoiceError(InvoiceError.InvalidTaxRate(BigDecimal("-100")))
        assertTrue(code == StatusCode.BadRequest)
      }
    )
