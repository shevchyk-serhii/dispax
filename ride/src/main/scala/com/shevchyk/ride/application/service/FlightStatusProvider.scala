package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.FlightInfo
import zio.*
import java.time.LocalDate

/**
 * Abstraction over an external flight-data source: given a flight number, the local date of the flight and its
 * direction, return the flight's live data (status, scheduled/estimated times, terminal).
 *
 * Implementations MUST degrade gracefully: a network error, a parse failure or an unknown flight all resolve to `None`
 * — the effect never fails. This keeps callers (e.g. the background monitor) simple: `None` means "no fresh data this
 * tick", not "abort".
 *
 * The real implementation ([[MucFlightStatusProvider]]) scrapes the Munich Airport board; tests use the in-memory
 * double `InMemoryFlightStatusProvider`.
 */
trait FlightStatusProvider:

  /**
   * Look up a single flight by number + date + direction.
   *
   * @param flightNumber
   *   airline+number, e.g. "LH123" or "4Y 1410" (whitespace is normalized internally)
   * @param date
   *   the local calendar date of the flight at the airport
   * @param isArrival
   *   true = arrival into the airport, false = departure
   * @return
   *   the flight's live data, or None if not found / the source is unavailable
   */
  def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]]
