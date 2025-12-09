package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import zio.*
import java.time.{LocalDate, LocalDateTime}

case class FlightData(
    icao24: String,
    firstSeen: Long,
    estDepartureAirport: String,
    lastSeen: Long,
    estArrivalAirport: String,
    callsign: String
) derives zio.json.JsonCodec

enum FlightApplicationError extends Exception:
  case ServiceUnavailable
  case FlightNotFound(flightNumber: String)
  case InvalidTimeRange(msg: String)
  case NetworkError(cause: Throwable)
  case InfrastructureError(cause: FlightError)

  def message: String =
    this match
      case ServiceUnavailable           => "Flight service unavailable"
      case FlightNotFound(flightNumber) => s"Flight not found: $flightNumber"
      case InvalidTimeRange(msg)        => s"Invalid time range: $msg"
      case NetworkError(cause)          => s"Network error: ${cause.getMessage}"
      case InfrastructureError(cause)   => s"Infrastructure error: ${cause.message}"

case class FlightApplicationService(
    flightInfoService: FlightInfoService
):

  def getMunichArrivals(beginTime: Long, endTime: Long): IO[FlightApplicationError, List[FlightData]] =
    for
      _ <- validateTimeRange(beginTime, endTime)

      from = LocalDateTime.ofEpochSecond(beginTime, 0, java.time.ZoneOffset.UTC)
      to   = LocalDateTime.ofEpochSecond(endTime, 0, java.time.ZoneOffset.UTC)

      arrivals <- flightInfoService
                    .getAirportArrivals("EDDM", from, to)
                    .mapError(FlightApplicationError.InfrastructureError.apply)

      flightData = arrivals.map(toFlightData(_, beginTime, endTime))
    yield flightData

  def getMunichDepartures(beginTime: Long, endTime: Long): IO[FlightApplicationError, List[FlightData]] =
    for
      _ <- validateTimeRange(beginTime, endTime)

      from = LocalDateTime.ofEpochSecond(beginTime, 0, java.time.ZoneOffset.UTC)
      to   = LocalDateTime.ofEpochSecond(endTime, 0, java.time.ZoneOffset.UTC)

      departures <- flightInfoService
                      .getAirportDepartures("EDDM", from, to)
                      .mapError(FlightApplicationError.InfrastructureError.apply)

      flightData = departures.map(toFlightData(_, beginTime, endTime))
    yield flightData

  def getFlightInfo(flightNumber: String, date: LocalDate): IO[FlightApplicationError, Option[FlightInfo]] =
    for
      _ <-
        ZIO.when(flightNumber.trim.isEmpty) {
          ZIO.fail(FlightApplicationError.FlightNotFound(flightNumber))
        }

      flightInfo <- flightInfoService
                      .getFlightInfo(flightNumber, date)
                      .mapError(FlightApplicationError.InfrastructureError.apply)
    yield flightInfo

  private def validateTimeRange(beginTime: Long, endTime: Long): IO[FlightApplicationError, Unit] =
    if beginTime >= endTime then ZIO.fail(FlightApplicationError.InvalidTimeRange("Begin time must be before end time"))
    else ZIO.unit

  private def toFlightData(flightInfo: FlightInfo, beginTime: Long, endTime: Long): FlightData =
    val epochTime = flightInfo.flightTime.toEpochSecond(java.time.ZoneOffset.UTC)

    if flightInfo.isArrival then
      FlightData(
        icao24 = s"sim${flightInfo.flightNumber.hashCode.abs.toString}",
        firstSeen = epochTime - 3600,
        estDepartureAirport = "SIMULATED",
        lastSeen = epochTime,
        estArrivalAirport = "EDDM",
        callsign = flightInfo.flightNumber
      )
    else
      FlightData(
        icao24 = s"sim${flightInfo.flightNumber.hashCode.abs.toString}",
        firstSeen = epochTime,
        estDepartureAirport = "EDDM",
        lastSeen = epochTime + 3600,
        estArrivalAirport = "SIMULATED",
        callsign = flightInfo.flightNumber
      )

object FlightApplicationService:

  val layer: ZLayer[FlightInfoService, Nothing, FlightApplicationService] = ZLayer.fromFunction(
    FlightApplicationService.apply
  )
