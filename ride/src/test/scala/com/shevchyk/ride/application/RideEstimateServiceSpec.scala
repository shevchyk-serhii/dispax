package com.shevchyk.ride.application

import com.shevchyk.core.domain.{CompanyId, Location}
import com.shevchyk.ride.application.service.RideEstimateService
import com.shevchyk.ride.application.service.RideEstimateService.EstimateError
import com.shevchyk.ride.domain.VehicleClass
import com.shevchyk.ride.repository.InMemoryTariffRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object RideEstimateServiceSpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.randomUUID())

  // Marienplatz → Munich Airport, ~28.8 km straight-line.
  private val from = Location("Marienplatz", Some(48.1374), Some(11.5755))
  private val to   = Location("Munich Airport", Some(48.3537), Some(11.7750))

  private val service: RideEstimateService = RideEstimateService.Live(new InMemoryTariffRepository())

  def spec =
    suite("RideEstimateService")(
      test("missing from-coordinates fails with MissingCoordinates") {
        for result <-
              service
                .estimate(companyId, Location("X"), to, VehicleClass.Business, false, None)
                .either
        yield assertTrue(result == Left(EstimateError.MissingCoordinates("from.latitude")))
      },
      test("computes a positive distance, duration and price with default tariff") {
        for est <- service.estimate(companyId, from, to, VehicleClass.Business, false, None)
        yield assertTrue(
          est.distanceKm > BigDecimal(20),
          est.distanceKm < BigDecimal(40),
          est.durationMinutes >= 1,
          est.estimatedPrice > BigDecimal(0),
          est.currency == "EUR"
        )
      },
      test("Van costs more than Business for the same route") {
        for
          business <- service.estimate(companyId, from, to, VehicleClass.Business, false, None)
          van      <- service.estimate(companyId, from, to, VehicleClass.Van, false, None)
        yield assertTrue(van.estimatedPrice > business.estimatedPrice)
      },
      test("night pickup costs more than day pickup (default tariff has a night surcharge)") {
        // 2026-06-20 02:00 Europe/Berlin (00:00Z in summer DST = 02:00 local) → night window.
        val nightPickup = Instant.parse("2026-06-20T00:00:00Z")
        // 2026-06-20 12:00 Europe/Berlin → day.
        val dayPickup   = Instant.parse("2026-06-20T10:00:00Z")
        for
          day   <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(dayPickup))
          night <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(nightPickup))
        yield assertTrue(night.estimatedPrice > day.estimatedPrice)
      },
      test("isNight detects the 22:00–06:00 Europe/Berlin window") {
        // 03:00Z = 05:00 Berlin (summer) → night; 12:00Z = 14:00 Berlin → day.
        assertTrue(
          RideEstimateService.isNight(Instant.parse("2026-06-20T03:00:00Z")),
          !RideEstimateService.isNight(Instant.parse("2026-06-20T12:00:00Z"))
        )
      }
    )
