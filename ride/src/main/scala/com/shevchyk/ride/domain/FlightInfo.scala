package com.shevchyk.ride.domain

import java.time.Instant
import zio.json.*

/**
 * Live status of a flight, normalized from an external flight-data source.
 *
 * The Munich Airport board reports the status as a German free-text label that is NOT localized (it stays German even
 * when the request asks for `locale=en`), so [[fromMuc]] is the single source of truth mapping those labels onto this
 * closed enum. Unknown / unmapped labels collapse to [[Unknown]] rather than failing — a new label the airport invents
 * must never break ingestion.
 */
enum FlightStatus:
  case Scheduled, Boarding, Departed, EnRoute, Landed, Delayed, Cancelled, Diverted, Unknown

object FlightStatus:

  /**
   * Map a Munich Airport status label (German, case-insensitive) onto a [[FlightStatus]]. Anything unrecognized maps to
   * [[Unknown]] so ingestion is resilient to new/extra labels.
   */
  def fromMuc(label: String): FlightStatus =
    label.trim.toLowerCase match
      case ""                                                                                                         => Unknown
      // The list view labels an on-time flight "geplant" (not "planmäßig"); a departure with an open check-in
      // desk shows "Check-In". Both mean the flight is still on schedule.
      case s
          if s.contains("planmäßig") || s.contains("planmaessig") || s.contains("planmassig") ||
            s.contains("geplant") || s.contains("check-in") || s.contains("check in") =>
        Scheduled
      case s if s.contains("boarding") || s.contains("einstieg")                                                      => Boarding
      case s if s.contains("gestartet") || s.contains("abgeflogen")                                                   => Departed
      // An arrival close to landing shows "im Anflug" (on approach) — the aircraft is still in the air.
      case s if s.contains("unterwegs") || s.contains("en route") || s.contains("anflug")                             => EnRoute
      // A completed arrival shows on the MUC board as "beendet" (finished/processed) or "Gepäck" (baggage on the
      // belt). Both mean the plane is down — without "gepäck" the status flickered Unknown between board updates.
      case s
          if s.contains("gelandet") || s.contains("angekommen") || s.contains("beendet") || s.contains("gepäck") ||
            s.contains("gepaeck") =>
        Landed
      case s if s.contains("verspätet") || s.contains("verspaetet") || s.contains("verspatet") || s.contains("delay") =>
        Delayed
      case s if s.contains("gestrichen") || s.contains("annulliert") || s.contains("cancel")                          => Cancelled
      case s if s.contains("umgeleitet") || s.contains("diverted")                                                    => Diverted
      case _                                                                                                          => Unknown

  /**
   * Canonical wire string persisted in `flight_status` and sent over WebSocket.
   */
  def toWire(s: FlightStatus): String =
    s match
      case Scheduled => "scheduled"
      case Boarding  => "boarding"
      case Departed  => "departed"
      case EnRoute   => "en_route"
      case Landed    => "landed"
      case Delayed   => "delayed"
      case Cancelled => "cancelled"
      case Diverted  => "diverted"
      case Unknown   => "unknown"

  def fromWire(s: String): Option[FlightStatus] =
    s.trim.toLowerCase match
      case "scheduled" => Some(Scheduled)
      case "boarding"  => Some(Boarding)
      case "departed"  => Some(Departed)
      case "en_route"  => Some(EnRoute)
      case "landed"    => Some(Landed)
      case "delayed"   => Some(Delayed)
      case "cancelled" => Some(Cancelled)
      case "diverted"  => Some(Diverted)
      case "unknown"   => Some(Unknown)
      case _           => None

  given JsonCodec[FlightStatus] = JsonCodec.string.transformOrFail(
    s => fromWire(s).toRight(s"Unknown flight status: $s"),
    toWire
  )

/**
 * Live data for a single flight, returned by a [[com.shevchyk.ride.application.service.FlightStatusProvider]].
 *
 * `scheduledTime` / `estimatedTime` are absolute instants (the source reports local `HH:mm`, combined with the query
 * date at the airport's zone). `terminal` is the terminal/area label as printed on the board (e.g. "T2", "T1D"); the
 * board does not expose a gate in the list view, so gate is intentionally absent here.
 */
final case class FlightInfo(
    flightNumber: String,
    isArrival: Boolean,
    status: FlightStatus,
    scheduledTime: Option[Instant] = None,
    estimatedTime: Option[Instant] = None,
    terminal: Option[String] = None,
    // The MUC gate (e.g. "G35", "H14"), scraped from the flight's detail page — the list view does not
    // expose it. None when the detail lookup is skipped, fails, or no gate is published yet.
    gate: Option[String] = None,
    airline: Option[String] = None,
    otherAirport: Option[String] = None,
    // The flight's take-off instant from its ORIGIN airport (for an arrival, when the aircraft left elsewhere),
    // scraped from the detail page's departure block. The start of the en-route window the card animates against.
    // None until the detail lookup runs / the page has no departure time.
    departureTime: Option[Instant] = None
) derives JsonCodec

/**
 * The flight-tracking columns persisted on a ride (`flight_gate`, `flight_terminal`, `flight_status`, `flight_time`).
 *
 * These are written by the background flight monitor via `RideRepository.updateFlightStatus` and read back via
 * `findFlightStatus` — they are intentionally NOT part of the [[Ride]] domain object (which carries only the booking
 * intent), so the heavy `Read[Ride]` mapping stays untouched. `flightStatus` is the canonical wire string
 * ([[FlightStatus.toWire]]); `flightTime` is the latest known (estimated, else scheduled) instant.
 */
final case class FlightStatusRow(
    gate: Option[String] = None,
    terminal: Option[String] = None,
    flightStatus: Option[String] = None,
    flightTime: Option[Instant] = None,
    // The scheduled (on-time) arrival/departure instant, tracked separately from `flightTime` (the latest
    // known, i.e. estimated) so a delay can be shown as `flightTime - scheduledTime`. None until the monitor
    // has fetched flight data.
    scheduledTime: Option[Instant] = None,
    // The origin take-off instant (for arrivals), so the card can animate the en-route progress as
    // `(now - departureTime) / (flightTime - departureTime)`. None until the detail lookup runs.
    departureTime: Option[Instant] = None
):

  /**
   * True when at least one flight column carries data (nothing to surface otherwise).
   */
  def nonEmpty: Boolean =
    gate.isDefined || terminal.isDefined || flightStatus.isDefined || flightTime.isDefined || scheduledTime.isDefined ||
      departureTime.isDefined
