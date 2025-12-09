package com.shevchyk.infrastructure.services

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{FlightInfoService, FlightError}
import zio.*
import java.time.{LocalDate, LocalDateTime}

case class StubFlightInfoService() extends FlightInfoService:

  def getFlightInfo(flightNumber: String, date: LocalDate): IO[FlightError, Option[FlightInfo]] =
    if flightNumber.trim.isEmpty then ZIO.fail(FlightError.InvalidFlightNumber(flightNumber))
    else
      ZIO.succeed(
        Some(
          FlightInfo(
            flightNumber = flightNumber,
            flightTime = date.atTime(12, 0), // Default to noon
            isArrival = flightNumber.contains("A") || flightNumber.toLowerCase.contains("arr")
          )
        )
      )

  def getAirportArrivals(
      airportCode: String,
      from: LocalDateTime,
      to: LocalDateTime
  ): IO[FlightError, List[FlightInfo]] = ZIO.succeed(List.empty) // Return empty list for now

  def getAirportDepartures(
      airportCode: String,
      from: LocalDateTime,
      to: LocalDateTime
  ): IO[FlightError, List[FlightInfo]] = ZIO.succeed(List.empty) // Return empty list for now

object StubFlightInfoService:
  val layer: ULayer[FlightInfoService] = ZLayer.succeed(StubFlightInfoService())
