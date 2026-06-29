package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.FlightStatus
import zio.*
import zio.test.*

import java.time.{Instant, LocalDate}
import scala.io.Source

/**
 * Unit tests for the pure Munich Airport board parser. Fixtures under `ride/src/test/resources/muc/` are real fragments
 * captured from the live endpoint (departures, a single number-filtered flight, and a zero-result query).
 */
object MucFlightParserSpec extends ZIOSpecDefault:

  private def fixture(name: String): String =
    val stream = getClass.getClassLoader.getResourceAsStream(s"muc/$name")
    val src    = Source.fromInputStream(stream, "UTF-8")
    try src.mkString
    finally src.close()

  private val theDate = LocalDate.of(2026, 6, 26)

  def spec =
    suite("MucFlightParser")(
      test("parses the single number-filtered departure (4Y 1410)") {
        val info = MucFlightParser.parse(fixture("departure_single.html"), theDate, isArrival = false)
        assertTrue(
          info.isDefined,
          info.get.flightNumber == "4Y1410",
          info.get.status == FlightStatus.Departed, // "gestartet"
          info.get.terminal.contains("T2"),
          info.get.otherAirport.contains("VAR"),
          info.get.isArrival == false,
          // 05:50 Europe/Berlin (CEST, +02:00) on 2026-06-26 == 03:50 UTC
          info.get.scheduledTime.contains(Instant.parse("2026-06-26T03:50:00Z")),
          // expected column is blank → no estimated time
          info.get.estimatedTime.isEmpty
        )
      },
      test("parses the first row of the full departures list") {
        val info = MucFlightParser.parse(fixture("departures_list.html"), theDate, isArrival = false)
        assertTrue(
          info.isDefined,
          info.get.flightNumber.nonEmpty,
          info.get.terminal.isDefined
        )
      },
      test("returns None for a zero-result fragment") {
        val info = MucFlightParser.parse(fixture("empty.html"), theDate, isArrival = false)
        assertTrue(info.isEmpty)
      },
      test("parseAll returns every flight row of the board (not just the first)") {
        val all = MucFlightParser.parseAll(fixture("departures_list.html"), theDate, isArrival = false)
        assertTrue(
          all.size > 1,                    // the whole board, not a single row
          all.forall(_.flightNumber.nonEmpty),
          all.head.flightNumber == MucFlightParser
            .parse(fixture("departures_list.html"), theDate, isArrival = false)
            .get
            .flightNumber,                 // first parsed row matches single-parse
          all.forall(_.isArrival == false) // direction is applied to every row
        )
      },
      test("parseAll returns empty for a zero-result / junk fragment") {
        assertTrue(
          MucFlightParser.parseAll(fixture("empty.html"), theDate, isArrival = true).isEmpty,
          MucFlightParser.parseAll("<div>nothing</div>", theDate, isArrival = true).isEmpty
        )
      },
      test("returns None for empty / junk html") {
        assertTrue(
          MucFlightParser.parse("", theDate, isArrival = false).isEmpty,
          MucFlightParser.parse("<div>no flights here</div>", theDate, isArrival = false).isEmpty
        )
      },
      test("carries the requested direction through to the result") {
        val arr = MucFlightParser.parse(fixture("departure_single.html"), theDate, isArrival = true)
        assertTrue(arr.exists(_.isArrival))
      },
      test("normalizeFlightNumber strips whitespace and upper-cases") {
        assertTrue(
          MucFlightParser.normalizeFlightNumber("4Y 1410") == "4Y1410",
          MucFlightParser.normalizeFlightNumber("  lh 123 ") == "LH123"
        )
      },
      test("detailHref extracts the flight's detail-page link from the list row") {
        val href = MucFlightParser.detailHref(fixture("departure_single.html"))
        assertTrue(href.exists(h => h.startsWith("/flugdetailseite-") && h.contains("flight_id=")))
      },
      test("detailHref is None for a zero-result fragment") {
        assertTrue(MucFlightParser.detailHref(fixture("empty.html")).isEmpty)
      },
      test("parseGate reads the MUC gate from a departure detail page") {
        // departure: MUC is the first flight-box block, gate "G35".
        assertTrue(MucFlightParser.parseGate(fixture("detail_departure.html")).contains("G35"))
      },
      test("parseGate reads the MUC gate from an arrival detail page (second block)") {
        // arrival: MUC is the SECOND block (origin is the other airport); gate "H14".
        assertTrue(MucFlightParser.parseGate(fixture("detail_arrival.html")).contains("H14"))
      },
      test("parseDetailTerminal reads the MUC terminal from the detail page") {
        assertTrue(
          MucFlightParser.parseDetailTerminal(fixture("detail_departure.html")).contains("T2"),
          MucFlightParser.parseDetailTerminal(fixture("detail_arrival.html")).contains("T2")
        )
      },
      test("parseGate is None when the page has no gate") {
        assertTrue(MucFlightParser.parseGate("<div>no detail here</div>").isEmpty)
      },
      test("parseGate keeps a remote stand as the \"REMOTE\" sentinel, plus the terminal") {
        // A remote (bus) stand renders "T2 - Gate REMOTE" (prod: LH1983). It is kept (normalised to "REMOTE") so the
        // driver knows the passenger arrives by apron bus and the walk-buffer logic picks the longest buffer.
        val remoteDetail =
          """<span class="flight-box-airport">Franz Josef Strauß Intl. (MUC)</span>
            |<div class="flight-box-area">T2 - Gate REMOTE</div>""".stripMargin
        assertTrue(
          MucFlightParser.parseGate(remoteDetail).contains("REMOTE"),
          MucFlightParser.parseDetailTerminal(remoteDetail).contains("T2")
        )
      },
      test("parseDepartureInstant reads the origin take-off across a day boundary (arrival)") {
        // Arrival detail: origin Singapur departs 25.06 22:45 (its OWN date), MUC arrives 26.06 05:20. The departure
        // must anchor to 25.06, not the MUC date, so it stays BEFORE the arrival. 22:45 Europe/Berlin (CEST) = 20:45 UTC.
        val dep = MucFlightParser.parseDepartureInstant(fixture("detail_arrival.html"))
        assertTrue(dep.contains(Instant.parse("2026-06-25T20:45:00Z")))
      },
      test("parseDepartureInstant reads the MUC take-off for a departure detail page") {
        // Departure detail: the departure block IS the MUC side, 26.06 05:50 (CEST) = 03:50 UTC.
        val dep = MucFlightParser.parseDepartureInstant(fixture("detail_departure.html"))
        assertTrue(dep.contains(Instant.parse("2026-06-26T03:50:00Z")))
      },
      test("parseDepartureInstant is None when the page has no departure block") {
        assertTrue(MucFlightParser.parseDepartureInstant("<div>no detail here</div>").isEmpty)
      }
    )
