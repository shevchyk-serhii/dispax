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
      )
    )
