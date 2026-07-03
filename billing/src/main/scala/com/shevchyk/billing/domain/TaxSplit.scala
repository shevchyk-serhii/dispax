package com.shevchyk.billing.domain

/**
 * Single source of truth for the Brutto-in tax split used across billing.
 *
 * Ride prices are GROSS (Brutto, incl. MwSt), so Netto and MwSt are DERIVED from the gross amount: `net = gross / (1 +
 * rate/100)`, `tax = gross - net`, all rounded to 2 decimals HALF_UP. Both the stored invoice totals
 * (`InvoiceService.recalculate`) and the PDF receipt (`PdfGenerator`) MUST use this one function — two independent
 * copies previously risked the PDF and the persisted invoice drifting apart by cents on a rounding change.
 */
object TaxSplit:

  /**
   * Result of splitting a gross amount: `gross == net + tax` (up to the 2-decimal rounding of each part).
   */
  final case class Split(net: BigDecimal, tax: BigDecimal, gross: BigDecimal)

  /**
   * Split a GROSS amount into Netto/MwSt for the given tax rate in percent.
   *
   * The caller must guarantee `taxRatePct` is within [0, 100] (validated at the API boundary; `recalculate` clamps a
   * corrupt stored rate before calling). `gross` is normalised to 2 decimals HALF_UP first, matching the invoice/PDF
   * output scale.
   */
  def fromGross(grossAmount: BigDecimal, taxRatePct: BigDecimal): Split =
    val gross = grossAmount.setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val net   = (gross / (1 + taxRatePct / 100)).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val tax   = (gross - net).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    Split(net = net, tax = tax, gross = gross)
