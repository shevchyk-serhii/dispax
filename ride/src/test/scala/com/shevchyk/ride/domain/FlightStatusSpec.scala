package com.shevchyk.ride.domain

import zio.test.*

/**
 * Table tests for the German MUC label → FlightStatus mapping and its wire round-trip.
 */
object FlightStatusSpec extends ZIOSpecDefault:

  def spec =
    suite("FlightStatus")(
      test("fromMuc maps the German board labels") {
        val cases = List(
          "planmäßig"  -> FlightStatus.Scheduled,
          "Boarding"   -> FlightStatus.Boarding,
          "gestartet"  -> FlightStatus.Departed,
          "gelandet"   -> FlightStatus.Landed,
          // Regression: a completed arrival shows as "beendet" on the MUC board (e.g. "LH 1751 … beendet"),
          // which used to fall through to Unknown — the card then showed "unknown" for a landed flight.
          "beendet"    -> FlightStatus.Landed,
          "verspätet"  -> FlightStatus.Delayed,
          "gestrichen" -> FlightStatus.Cancelled,
          "umgeleitet" -> FlightStatus.Diverted
        )
        assertTrue(cases.forall { case (label, expected) => FlightStatus.fromMuc(label) == expected })
      },
      test("fromMuc is case-insensitive and trims") {
        assertTrue(
          FlightStatus.fromMuc("  GESTARTET ") == FlightStatus.Departed,
          FlightStatus.fromMuc("Verspätet") == FlightStatus.Delayed
        )
      },
      test("fromMuc falls back to Unknown for empty / unrecognized labels") {
        assertTrue(
          FlightStatus.fromMuc("") == FlightStatus.Unknown,
          FlightStatus.fromMuc("irgendwas") == FlightStatus.Unknown
        )
      },
      test("toWire / fromWire round-trips every status") {
        assertTrue(
          FlightStatus.values.forall(s => FlightStatus.fromWire(FlightStatus.toWire(s)).contains(s))
        )
      }
    )
