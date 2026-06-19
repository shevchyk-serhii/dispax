package com.shevchyk.ride.domain

import com.shevchyk.core.domain.CompanyId

/**
 * Pricing configuration for a company, read from the `tariffs` table.
 *
 * All amounts are in the company's default currency (EUR in the MVP). Legacy rows and missing tariff entries fall back
 * to zero-based defaults so the estimate endpoint never fails due to an absent tariff row.
 */
final case class CompanyTariff(
    companyId: CompanyId,
    basePriceAmount: BigDecimal,
    pricePerKmAmount: BigDecimal,
    airportSurchargeAmount: BigDecimal,
    nightSurchargeAmount: BigDecimal,
    currency: String = "EUR"
):

  /**
   * Estimate a fare for a given distance, optionally applying the airport surcharge, and scaled by the vehicle-class
   * price multiplier.
   *
   * Formula: (basePriceAmount + pricePerKmAmount × distanceKm + (isAirport ? airportSurchargeAmount : 0)) ×
   * vehicleClass.priceMultiplier
   */
  def estimate(distanceKm: Double, isAirportTransfer: Boolean, vehicleClass: VehicleClass): BigDecimal =
    val base     = basePriceAmount
    val perKm    = pricePerKmAmount * BigDecimal(distanceKm)
    val airport  = if isAirportTransfer then airportSurchargeAmount else BigDecimal(0)
    val subtotal = base + perKm + airport
    (subtotal * vehicleClass.priceMultiplier).setScale(2, BigDecimal.RoundingMode.HALF_UP)

object CompanyTariff:

  /**
   * Fallback tariff used when no row exists in the `tariffs` table for a company.
   */
  def default(companyId: CompanyId): CompanyTariff = CompanyTariff(
    companyId = companyId,
    basePriceAmount = BigDecimal(5.0),
    pricePerKmAmount = BigDecimal(2.5),
    airportSurchargeAmount = BigDecimal(10.0),
    nightSurchargeAmount = BigDecimal(5.0)
  )
