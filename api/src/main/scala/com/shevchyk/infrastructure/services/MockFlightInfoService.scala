package com.shevchyk.infrastructure.services

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{FlightInfoService, FlightError}
import zio.*
import java.time.{LocalDate, LocalDateTime}


case class MockFlightInfoService() extends FlightInfoService:

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
      FlightInfo("BA456", from.plusHours(1), Some("B7"), Some("1"), "Delayed", isArrival = true),
      FlightInfo("AF789", from.plusHours(3), Some("C3"), Some("2"), "On Time", isArrival = true),
      FlightInfo("KL101", from.plusHours(5), Some("A5"), Some("1"), "On Time", isArrival = true)
    ).filter(flight => flight.flightTime.isAfter(from) && flight.flightTime.isBefore(to))

    ZIO.succeed(mockArrivals)

  override def getAirportDepartures(
      airportCode: String,
      from: LocalDateTime,
      to: LocalDateTime
  ): IO[FlightError, List[FlightInfo]] =
    
    val mockDepartures = List(
      FlightInfo("LH123", from.plusHours(2), Some("A12"), Some("2"), "On Time", isArrival = false),
      FlightInfo("OS555", from.plusHours(4), Some("D8"), Some("1"), "Boarding", isArrival = false),
      FlightInfo("TK999", from.plusHours(6), Some("B15"), Some("2"), "On Time", isArrival = false)
    ).filter(flight => flight.flightTime.isAfter(from) && flight.flightTime.isBefore(to))

    ZIO.succeed(mockDepartures)

object MockFlightInfoService:
  val layer: ZLayer[Any, Nothing, FlightInfoService] = ZLayer.succeed(MockFlightInfoService())
