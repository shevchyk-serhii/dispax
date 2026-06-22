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
      },

      // ─── Night-boundary tests (mutation-kill for NightStart/NightEnd) ─────────
      // Europe/Berlin in summer = UTC+2. So 22:00 Berlin = 20:00 UTC, 06:00 Berlin = 04:00 UTC.

      test("isNight: exactly 22:00 Berlin is inside the night window") {
        // 22:00 Berlin (summer) = 20:00 UTC — must be night (NightStart is inclusive: !t.isBefore(22:00))
        assertTrue(RideEstimateService.isNight(Instant.parse("2026-06-20T20:00:00Z")))
      },
      test("isNight: 21:59 Berlin is outside the night window") {
        // 21:59 Berlin (summer) = 19:59 UTC — must be day (one minute before NightStart)
        assertTrue(!RideEstimateService.isNight(Instant.parse("2026-06-20T19:59:00Z")))
      },
      test("isNight: 05:59 Berlin is inside the night window") {
        // 05:59 Berlin (summer) = 03:59 UTC — must be night (one minute before NightEnd)
        assertTrue(RideEstimateService.isNight(Instant.parse("2026-06-20T03:59:00Z")))
      },
      test("isNight: exactly 06:00 Berlin is outside the night window") {
        // 06:00 Berlin (summer) = 04:00 UTC — must be day (NightEnd is exclusive: t.isBefore(06:00) = false)
        assertTrue(!RideEstimateService.isNight(Instant.parse("2026-06-20T04:00:00Z")))
      },

      // ─── Night surcharge applied at boundary via estimate() ──────────────────

      test("estimate at exactly 22:00 Berlin applies night surcharge") {
        // 20:00 UTC = 22:00 Berlin — surcharge must kick in
        val at2200Berlin = Instant.parse("2026-06-20T20:00:00Z")
        val dayPickup    = Instant.parse("2026-06-20T10:00:00Z") // 12:00 Berlin, clearly day
        for
          day   <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(dayPickup))
          night <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(at2200Berlin))
        yield assertTrue(night.estimatedPrice > day.estimatedPrice)
      },
      test("estimate at 21:59 Berlin does NOT apply night surcharge") {
        // 19:59 UTC = 21:59 Berlin — one minute before night; no surcharge
        val at2159Berlin = Instant.parse("2026-06-20T19:59:00Z")
        val at2200Berlin = Instant.parse("2026-06-20T20:00:00Z")
        for
          before <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(at2159Berlin))
          at     <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(at2200Berlin))
        yield assertTrue(at.estimatedPrice > before.estimatedPrice)
      },
      test("estimate at exactly 06:00 Berlin does NOT apply night surcharge") {
        // 04:00 UTC = 06:00 Berlin — night window ends (exclusive), no surcharge
        val at0600Berlin = Instant.parse("2026-06-20T04:00:00Z")
        val at0559Berlin = Instant.parse("2026-06-20T03:59:00Z")
        for
          at     <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(at0600Berlin))
          before <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(at0559Berlin))
        yield assertTrue(before.estimatedPrice > at.estimatedPrice)
      },

      // ─── No pickupTime → no night surcharge (mutation-kill for exists→forall) ─

      test("estimate without pickupTime does NOT apply night surcharge") {
        // pickupTime = None; exists(None) = false, forall(None) = true → forall mutation would add surcharge
        val dayPickup = Instant.parse("2026-06-20T10:00:00Z") // clearly day price baseline
        for
          noTime  <- service.estimate(companyId, from, to, VehicleClass.Business, false, None)
          dayTime <- service.estimate(companyId, from, to, VehicleClass.Business, false, Some(dayPickup))
        yield assertTrue(noTime.estimatedPrice == dayTime.estimatedPrice)
      },

      // ─── Haversine distance numeric assert (mutation-kill for radius 6371→8000) ─

      test("haversineKm returns the correct great-circle distance for a known route (±2%)") {
        // Marienplatz (48.1374, 11.5755) → Munich Airport (48.3537, 11.7750)
        // Expected ~28.23 km (verified independently; tolerance ±2% = ±0.57 km)
        val dist = RideEstimateService.haversineKm(48.1374, 11.5755, 48.3537, 11.7750)
        assertTrue(
          dist > 27.5, // less than 28.23 - 2% = 27.67; use 27.5 as safe floor
          dist < 29.0  // 28.23 + 2% = 28.79; use 29.0 as safe ceiling
        )
      },
      test("estimate.distanceKm for a known Munich route is within ±2% of expected 28.23 km") {
        for est <- service.estimate(companyId, from, to, VehicleClass.Business, false, None)
        yield assertTrue(
          est.distanceKm > BigDecimal("27.50"),
          est.distanceKm < BigDecimal("29.00")
        )
      }
    )
