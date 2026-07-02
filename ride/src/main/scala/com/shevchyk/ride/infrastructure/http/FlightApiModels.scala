package com.shevchyk.ride.infrastructure.http

import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.json.*

/**
 * Wire representation of a single flight on the dispatcher arrivals board.
 *
 * All times are rendered as ISO-8601 strings (the absolute instants from [[FlightInfo]] via `Instant.toString`) so the
 * payload stays trivially serializable. `status` is the canonical wire string ([[FlightStatus.toWire]]); `origin` is
 * the other airport (where an arrival is coming from), i.e. [[FlightInfo.otherAirport]].
 */
case class FlightDto(
    flightNumber: String,
    status: String,
    scheduledTime: Option[String] = None,
    estimatedTime: Option[String] = None,
    terminal: Option[String] = None,
    gate: Option[String] = None,
    airline: Option[String] = None,
    origin: Option[String] = None
) derives JsonCodec

object FlightDto:

  def fromDomain(info: FlightInfo): FlightDto = FlightDto(
    flightNumber = info.flightNumber,
    status = FlightStatus.toWire(info.status),
    scheduledTime = info.scheduledTime.map(_.toString),
    estimatedTime = info.estimatedTime.map(_.toString),
    terminal = info.terminal,
    gate = info.gate,
    airline = info.airline,
    origin = info.otherAirport
  )
