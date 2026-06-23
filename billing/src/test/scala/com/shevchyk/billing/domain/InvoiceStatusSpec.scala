package com.shevchyk.billing.domain

import zio.test.*

object InvoiceStatusSpec extends ZIOSpecDefault {

  def spec =
    suite("InvoiceStatus.fromString")(
      test("parses all valid status strings (case-insensitive)") {
        assertTrue(
          InvoiceStatus.fromString("draft").contains(InvoiceStatus.Draft),
          InvoiceStatus.fromString("DRAFT").contains(InvoiceStatus.Draft),
          InvoiceStatus.fromString("sent").contains(InvoiceStatus.Sent),
          InvoiceStatus.fromString("Sent").contains(InvoiceStatus.Sent),
          InvoiceStatus.fromString("paid").contains(InvoiceStatus.Paid),
          InvoiceStatus.fromString("PAID").contains(InvoiceStatus.Paid),
          InvoiceStatus.fromString("cancelled").contains(InvoiceStatus.Cancelled),
          InvoiceStatus.fromString("Cancelled").contains(InvoiceStatus.Cancelled)
        )
      },
      test("round-trips through asString for every status") {
        check(Gen.fromIterable(InvoiceStatus.values.toList)) { status =>
          assertTrue(InvoiceStatus.fromString(InvoiceStatus.asString(status)).contains(status))
        }
      },
      test("an unknown status is None, not Draft") {
        // Regression: a corrupted/unknown status must NOT be silently coerced to
        // Draft. A paid invoice read back as a draft is a data-integrity incident.
        assertTrue(
          InvoiceStatus.fromString("paidd").isEmpty,
          InvoiceStatus.fromString("overdue").isEmpty,
          InvoiceStatus.fromString("").isEmpty,
          InvoiceStatus.fromString("garbage").isEmpty,
          !InvoiceStatus.fromString("garbage").contains(InvoiceStatus.Draft)
        )
      }
    )
}
