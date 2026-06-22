package com.shevchyk.ride.domain

import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId}
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for: A) vehicle_class round-trip via the in-memory repository (create → fetch verifies the field survives)
 * D) estimate price calculation for Business vs Van vehicle classes
 */
object VehicleClassEstimateSpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val clientId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))

  private def baseRide(vc: VehicleClass) = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    pickupLocation = Location("Munich Airport", Some(48.3537), Some(11.7750)),
    dropoffLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    pickupDateTime = Instant.now().plusSeconds(3600),
    vehicleClass = vc
  )

  def spec =
    suite("VehicleClass + CompanyTariff")(
      suite("VehicleClass enum")(
        test("fromString round-trips all variants") {
          assertTrue(
            VehicleClass.fromString("business").contains(VehicleClass.Business),
            VehicleClass.fromString("van").contains(VehicleClass.Van),
            VehicleClass.fromString("BUSINESS").contains(VehicleClass.Business),
            VehicleClass.fromString("VAN").contains(VehicleClass.Van),
            VehicleClass.fromString("unknown").isEmpty
          )
        },
        test("toDbString produces expected strings") {
          assertTrue(
            VehicleClass.toDbString(VehicleClass.Business) == "business",
            VehicleClass.toDbString(VehicleClass.Van) == "van"
          )
        },
        test("Business has priceMultiplier 1.0, Van 1.4") {
          assertTrue(
            VehicleClass.Business.priceMultiplier == BigDecimal(1.0),
            VehicleClass.Van.priceMultiplier == BigDecimal(1.4)
          )
        },
        test("Default is Business") {
          assertTrue(VehicleClass.Default == VehicleClass.Business)
        }
      ),
      suite("vehicle_class round-trip via InMemoryRideRepository")(
        test("create with Business and fetch returns Business") {
          val repo = new InMemoryRideRepository()
          for {
            created <- repo.create(baseRide(VehicleClass.Business))
            found   <- repo.findById(created.id)
          } yield assertTrue(
            found.isDefined,
            found.get.vehicleClass == VehicleClass.Business
          )
        },
        test("create with Van and fetch returns Van") {
          val repo = new InMemoryRideRepository()
          for {
            created <- repo.create(baseRide(VehicleClass.Van))
            found   <- repo.findById(created.id)
          } yield assertTrue(
            found.isDefined,
            found.get.vehicleClass == VehicleClass.Van
          )
        },
        test("default vehicleClass is Business when not specified") {
          val repo        = new InMemoryRideRepository()
          val rideDefault = Ride(
            id = RideId.generate(),
            clientId = clientId,
            creatorId = clientId,
            companyId = companyId,
            pickupLocation = Location("A"),
            dropoffLocation = Location("B"),
            pickupDateTime = Instant.now().plusSeconds(3600)
            // vehicleClass uses default = Business
          )
          for {
            created <- repo.create(rideDefault)
            found   <- repo.findById(created.id)
          } yield assertTrue(found.get.vehicleClass == VehicleClass.Business)
        }
      ),
      suite("CompanyTariff.estimate price calculation")(
        test("Business ride: (base + perKm*dist + 0) * 1.0") {
          // base=5, perKm=2.5, dist=10 km, no airport → 5 + 25 = 30.00 EUR
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val price  = tariff.estimate(10.0, isAirportTransfer = false, VehicleClass.Business)
          assertTrue(price == BigDecimal("30.00"))
        },
        test("Van ride: (base + perKm*dist) * 1.4") {
          // base=5, perKm=2.5, dist=10 km, no airport → (5 + 25) * 1.4 = 42.00 EUR
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val price  = tariff.estimate(10.0, isAirportTransfer = false, VehicleClass.Van)
          assertTrue(price == BigDecimal("42.00"))
        },
        test("airport surcharge added when isAirportTransfer=true") {
          // base=5, perKm=2.5, dist=10km, airport=10 → (5 + 25 + 10) * 1.0 = 40.00
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val price  = tariff.estimate(10.0, isAirportTransfer = true, VehicleClass.Business)
          assertTrue(price == BigDecimal("40.00"))
        },
        test("Van airport: (base + perKm*dist + airport) * 1.4") {
          // (5 + 25 + 10) * 1.4 = 56.00
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val price  = tariff.estimate(10.0, isAirportTransfer = true, VehicleClass.Van)
          assertTrue(price == BigDecimal("56.00"))
        },
        test("Van multiplier is 40% higher than Business for same inputs") {
          val tariff        = CompanyTariff.default(companyId)
          val businessPrice = tariff.estimate(20.0, isAirportTransfer = false, VehicleClass.Business)
          val vanPrice      = tariff.estimate(20.0, isAirportTransfer = false, VehicleClass.Van)
          // van / business should equal 1.4
          val ratio         = vanPrice / businessPrice
          assertTrue((ratio - BigDecimal(1.4)).abs < BigDecimal("0.001"))
        },
        test("night surcharge added when isNight=true") {
          // base=5, perKm=2.5, dist=10km, night=5 → (5 + 25 + 5) * 1.0 = 35.00
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val day    = tariff.estimate(10.0, isAirportTransfer = false, VehicleClass.Business, isNight = false)
          val night  = tariff.estimate(10.0, isAirportTransfer = false, VehicleClass.Business, isNight = true)
          assertTrue(day == BigDecimal("30.00"), night == BigDecimal("35.00"))
        },
        test("airport + night surcharges stack and scale by vehicle class") {
          // (5 + 25 + 10 + 5) * 1.4 = 63.00
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5.0),
            pricePerKmAmount = BigDecimal(2.5),
            airportSurchargeAmount = BigDecimal(10.0),
            nightSurchargeAmount = BigDecimal(5.0)
          )
          val price  = tariff.estimate(10.0, isAirportTransfer = true, VehicleClass.Van, isNight = true)
          assertTrue(price == BigDecimal("63.00"))
        }
      ),
      suite("CompanyTariff.default numeric values")(
        // [HIGH] basePriceAmount 5.0→99.0, pricePerKmAmount 2.5→7.7 survive because no test checks the
        // exact default amounts.  Pin every field so any single mutation is caught.
        test("default() has exact canonical amounts: base=5.0, perKm=2.5, airportSurcharge=10.0, nightSurcharge=5.0") {
          val t = CompanyTariff.default(companyId)
          assertTrue(
            t.basePriceAmount == BigDecimal(5.0),
            t.pricePerKmAmount == BigDecimal(2.5),
            t.airportSurchargeAmount == BigDecimal(10.0),
            t.nightSurchargeAmount == BigDecimal(5.0)
          )
        },
        test("default() currency is EUR") {
          assertTrue(CompanyTariff.default(companyId).currency == "EUR")
        }
      ),
      suite("CompanyTariff.estimate rounding")(
        // [MEDIUM] setScale(2,HALF_UP) → setScale(0,...) or HALF_UP→DOWN.
        // Choose a distance that produces a fractional cent whose rounding differs between HALF_UP and DOWN,
        // and between 2 decimal places and 0 decimal places.
        // dist = 0.1 km, perKm = 2.5 → 0.25; base = 5.0 → subtotal = 5.25; × 1.0 → 5.25
        // setScale(0, HALF_UP) → 5;  setScale(2, DOWN) = 5.25 (same here so we need a subtly different case)
        // Use dist = 0.3 km → perKm = 0.75; base = 5.0 → subtotal = 5.75; × 1.0 = 5.75
        //   setScale(0, HALF_UP) → 6  (different from 5.75) ← catches scale mutation
        //   setScale(2, DOWN)    → 5.75 (same as HALF_UP for .75) — need a .X5 case for DOWN vs HALF_UP
        // Use perKm=0.015 (1.5 cents/km, dist=1.0) → subtotal base=0 + 0.015 = 0.015; ×1.0 = 0.015
        //   HALF_UP(2) → 0.02;  DOWN(2) → 0.01 ← catches rounding-mode mutation
        test("rounds to 2 decimal places using HALF_UP (not DOWN)") {
          // 0.015 rounds up to 0.02 with HALF_UP, but down to 0.01 with DOWN
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(0),
            pricePerKmAmount = BigDecimal("0.015"),
            airportSurchargeAmount = BigDecimal(0),
            nightSurchargeAmount = BigDecimal(0)
          )
          val price  = tariff.estimate(1.0, isAirportTransfer = false, VehicleClass.Business)
          assertTrue(price == BigDecimal("0.02"))
        },
        test("rounds to exactly 2 decimal places (not 0)") {
          // base=5, perKm=2.5, dist=0.3 → subtotal=5.75; setScale(0,HALF_UP)=6, setScale(2,HALF_UP)=5.75
          val tariff = CompanyTariff(
            companyId = companyId,
            basePriceAmount = BigDecimal(5),
            pricePerKmAmount = BigDecimal("2.5"),
            airportSurchargeAmount = BigDecimal(0),
            nightSurchargeAmount = BigDecimal(0)
          )
          val price  = tariff.estimate(0.3, isAirportTransfer = false, VehicleClass.Business)
          assertTrue(price == BigDecimal("5.75"))
        }
      )
    )
