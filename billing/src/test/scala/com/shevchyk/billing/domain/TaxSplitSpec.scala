package com.shevchyk.billing.domain

import zio.test.*

/**
 * Locks the single Brutto→Netto/MwSt split shared by the stored invoice and the PDF receipt. If the two ever compute
 * tax differently again (the audit finding), this contract test — plus both call sites routing through fromGross —
 * catches the drift.
 */
object TaxSplitSpec extends ZIOSpecDefault:

  def spec =
    suite("TaxSplit.fromGross")(
      test("19% on 119.00 gross → 100.00 net + 19.00 tax") {
        val s = TaxSplit.fromGross(BigDecimal("119.00"), BigDecimal(19))
        assertTrue(s.net == BigDecimal("100.00"), s.tax == BigDecimal("19.00"), s.gross == BigDecimal("119.00"))
      },
      test("net + tax == gross for a rounding-sensitive amount (100.00 @ 19%)") {
        val s = TaxSplit.fromGross(BigDecimal("100.00"), BigDecimal(19))
        // 100 / 1.19 = 84.0336… → 84.03 net, 15.97 tax; parts must still reconstruct the gross.
        assertTrue(s.net == BigDecimal("84.03"), s.tax == BigDecimal("15.97"), s.net + s.tax == s.gross)
      },
      test("0% rate → net equals gross, zero tax") {
        val s = TaxSplit.fromGross(BigDecimal("50.00"), BigDecimal(0))
        assertTrue(s.net == BigDecimal("50.00"), s.tax == BigDecimal("0.00"), s.gross == BigDecimal("50.00"))
      },
      test("normalises an unrounded gross to 2 decimals HALF_UP") {
        val s = TaxSplit.fromGross(BigDecimal("119.005"), BigDecimal(19))
        assertTrue(s.gross == BigDecimal("119.01"))
      }
    )
