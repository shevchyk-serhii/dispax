package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import zio.*
import zio.test.*
import zio.test.Assertion.*
import java.time.{LocalDate, LocalDateTime}

object FlightApplicationServiceSpec extends ZIOSpecDefault:

  def spec = suite("FlightApplicationService")(
    suite("getMunichArrivals")(
      test("should return arrival flights for valid time range") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime + 3600
          result <- service.getMunichArrivals(beginTime, endTime)
        yield assertTrue(
          result.nonEmpty,
          result.exists(_.callsign == "BA456"),
          result.exists(_.callsign == "AF789"),
          result.forall(_.estArrivalAirport == "EDDM")
        )
      },

      test("should fail with invalid time range") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime - 3600
          result <- service.getMunichArrivals(beginTime, endTime).exit
        yield assert(result)(fails(isSubtype[FlightApplicationError.InvalidTimeRange](anything)))
      }
    ),

    suite("getMunichDepartures")(
      test("should return departure flights for valid time range") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime + 3600
          result <- service.getMunichDepartures(beginTime, endTime)
        yield assertTrue(
          result.nonEmpty,
          result.exists(_.callsign == "LH123"),
          result.exists(_.callsign == "OS555"),
          result.forall(_.estDepartureAirport == "EDDM")
        )
      },

      test("should fail with invalid time range") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime - 1800
          result <- service.getMunichDepartures(beginTime, endTime).exit
        yield assert(result)(fails(isSubtype[FlightApplicationError.InvalidTimeRange](anything)))
      }
    ),

    suite("getFlightInfo")(
      test("should return flight info for existing flight") {
        for
          service <- ZIO.service[FlightApplicationService]
          today = LocalDate.now()
          result <- service.getFlightInfo("LH123", today)
        yield assertTrue(
          result.isDefined,
          result.get.flightNumber == "LH123",
          result.get.status == "On Time",
          result.get.isArrival == false
        )
      },

      test("should return None for non-existing flight") {
        for
          service <- ZIO.service[FlightApplicationService]
          today = LocalDate.now()
          result <- service.getFlightInfo("XX999", today)
        yield assertTrue(result.isEmpty)
      },

      test("should fail with empty flight number") {
        for
          service <- ZIO.service[FlightApplicationService]
          today = LocalDate.now()
          result <- service.getFlightInfo("", today).exit
        yield assert(result)(fails(isSubtype[FlightApplicationError.FlightNotFound](anything)))
      },

      test("should fail with whitespace-only flight number") {
        for
          service <- ZIO.service[FlightApplicationService]
          today = LocalDate.now()
          result <- service.getFlightInfo("   ", today).exit
        yield assert(result)(fails(isSubtype[FlightApplicationError.FlightNotFound](anything)))
      }
    ),

    suite("time validation")(
      test("should accept valid time ranges") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = 1000L
          endTime = 2000L
          result <- service.getMunichArrivals(beginTime, endTime)
        yield assertTrue(result.isInstanceOf[List[FlightData]])
      },

      test("should reject equal begin and end times") {
        for
          service <- ZIO.service[FlightApplicationService]
          time = java.lang.System.currentTimeMillis() / 1000
          result <- service.getMunichArrivals(time, time).exit
        yield assert(result)(fails(isSubtype[FlightApplicationError.InvalidTimeRange](anything)))
      }
    ),

    suite("flight data conversion")(
      test("should convert arrival flights correctly") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime + 3600
          result <- service.getMunichArrivals(beginTime, endTime)
          arrivalFlight = result.find(_.callsign == "BA456")
        yield assertTrue(
          arrivalFlight.isDefined,
          arrivalFlight.get.estArrivalAirport == "EDDM",
          arrivalFlight.get.icao24.startsWith("sim")
        )
      },

      test("should convert departure flights correctly") {
        for
          service <- ZIO.service[FlightApplicationService]
          beginTime = java.lang.System.currentTimeMillis() / 1000
          endTime = beginTime + 3600
          result <- service.getMunichDepartures(beginTime, endTime)
          departureFlight = result.find(_.callsign == "LH123")
        yield assertTrue(
          departureFlight.isDefined,
          departureFlight.get.estDepartureAirport == "EDDM",
          departureFlight.get.icao24.startsWith("sim")
        )
      }
    )
  ).provide(
    FlightApplicationService.layer,
    FlightMockFlightInfoService.layer
  )

case class FlightMockFlightInfoService() extends FlightInfoService:

  override def getFlightInfo(flightNumber: String, date: LocalDate): IO[FlightError, Option[FlightInfo]] =
    val mockFlights = Map(
      "LH123" -> FlightInfo(
        flightNumber = "LH123",
        flightTime = date.atTime(14, 30),
        gate = Some("A12"),
        terminal = Some("2"),
        status = "On Time",
        isArrival = false
      ),
      "BA456" -> FlightInfo(
        flightNumber = "BA456",
        flightTime = date.atTime(16, 45),
        gate = Some("B7"),
        terminal = Some("1"),
        status = "Delayed",
        isArrival = true
      ),
      "AF789" -> FlightInfo(
        flightNumber = "AF789",
        flightTime = date.atTime(11, 15),
        gate = Some("C3"),
        terminal = Some("2"),
        status = "On Time",
        isArrival = true
      )
    )

    ZIO.succeed(mockFlights.get(flightNumber.toUpperCase))

  override def getAirportArrivals(
      airportCode: String,
      from: LocalDateTime,
      to: LocalDateTime
  ): IO[FlightError, List[FlightInfo]] =
    val mockArrivals = List(
      FlightInfo("BA456", from.plusMinutes(30), Some("B7"), Some("1"), "Delayed", isArrival = true),
      FlightInfo("AF789", from.plusMinutes(45), Some("C3"), Some("2"), "On Time", isArrival = true),
      FlightInfo("KL101", from.plusMinutes(50), Some("A5"), Some("1"), "On Time", isArrival = true)
    )

    ZIO.succeed(mockArrivals)

  override def getAirportDepartures(
      airportCode: String,
      from: LocalDateTime,
      to: LocalDateTime
  ): IO[FlightError, List[FlightInfo]] =
    val mockDepartures = List(
      FlightInfo("LH123", from.plusMinutes(20), Some("A12"), Some("2"), "On Time", isArrival = false),
      FlightInfo("OS555", from.plusMinutes(35), Some("D8"), Some("1"), "Boarding", isArrival = false),
      FlightInfo("TK999", from.plusMinutes(55), Some("B15"), Some("2"), "On Time", isArrival = false)
    )

    ZIO.succeed(mockDepartures)

object FlightMockFlightInfoService:
  val layer: ZLayer[Any, Nothing, FlightInfoService] = 
    ZLayer.succeed(FlightMockFlightInfoService())