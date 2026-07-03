package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import java.time.{LocalDate, LocalTime, ZoneId}

/**
 * Pure parser for the Munich Airport flight-board HTML fragment returned by `/flightsearch/{departures,arrivals}`.
 *
 * Kept free of any effect/HTTP so it is fully unit-testable against saved fixtures. The board is HTML (not JSON), so we
 * extract by row (`<tr data-flight-id=...>`) and by cell CSS class. This is inherently coupled to the airport's markup
 * and will need updating if they restyle the board — the fixture-based tests are the guard.
 *
 * Times on the board are local wall-clock `HH:mm` at [[ZoneId]] "Europe/Berlin"; they are combined with the query date
 * to produce absolute instants. The "MUC" time cell carries `planned | expected` (expected is blank once the value is
 * final or not yet estimated).
 */
object MucFlightParser:

  private val BerlinZone = ZoneId.of("Europe/Berlin")

  // First flight row in the fragment. The board returns the best match first; a number-filtered query returns exactly
  // one row. Non-greedy up to the closing </tr>.
  private val RowRegex = "(?s)<tr[^>]*data-flight-id=\"[^\"]*\"[^>]*>(.*?)</tr>".r

  private def cellRegex(cls: String) =
    ("(?s)<td[^>]*class=\"[^\"]*\\b" + java.util.regex.Pattern.quote(cls) + "\\b[^\"]*\"[^>]*>(.*?)</td>").r

  /**
   * Strip all tags, unescape the handful of entities the board uses, collapse whitespace.
   */
  private def textOf(html: String): String =
    val noTags    = html.replaceAll("(?s)<[^>]*>", " ")
    val unescaped = noTags
      .replace("&nbsp;", " ")
      .replace("&amp;", "&")
      .replace("&lt;", "<")
      .replace("&gt;", ">")
      .replace("&#39;", "'")
      .replace("&quot;", "\"")
    unescaped.replaceAll("\\s+", " ").trim

  private def cell(rowHtml: String, cls: String): Option[String] = cellRegex(cls)
    .findFirstMatchIn(rowHtml)
    .map(m => textOf(m.group(1)))

  /**
   * Extract the IATA code from a "City (XXX)" airport label.
   */
  private def iataOf(airportLabel: String): Option[String] = "\\(([A-Z]{3})\\)".r
    .findFirstMatchIn(airportLabel)
    .map(_.group(1))

  /**
   * Normalize a flight number for comparison/output: drop all whitespace, upper-case ("4Y 1410" -> "4Y1410").
   */
  def normalizeFlightNumber(s: String): String = s.replaceAll("\\s+", "").toUpperCase

  /**
   * The number cell reads like "4Y 1410 (A320)" — take everything before the aircraft-type parenthesis.
   */
  private def flightNumberOf(numberCell: String): Option[String] =
    val beforeType = numberCell.replaceAll("\\(.*?\\)", "").trim
    Option.when(beforeType.nonEmpty)(beforeType)

  /**
   * Parse a single "HH:mm" cell half into a local wall-clock time (None when blank/unparseable).
   */
  private def localTimeOf(hhmm: String): Option[LocalTime] =
    val t = hhmm.trim
    if t.isEmpty then None
    else scala.util.Try(LocalTime.parse(t)).toOption

  /**
   * Anchor a local wall-clock time to `date` at Europe/Berlin.
   */
  private def atBerlin(date: LocalDate, lt: LocalTime): java.time.Instant = date.atTime(lt).atZone(BerlinZone).toInstant

  /**
   * Parse the first flight row of `html`.
   *
   * @param html
   *   the board HTML fragment
   * @param date
   *   the query date (used to anchor the local HH:mm times)
   * @param isArrival
   *   the direction the fragment was requested for (the board doesn't restate it per row)
   * @return
   *   the parsed flight, or None when the fragment has no flight rows (e.g. `data-total-results="0"`)
   */
  def parse(html: String, date: LocalDate, isArrival: Boolean): Option[FlightInfo] = RowRegex
    .findFirstMatchIn(html)
    .flatMap(rowMatch => parseRow(rowMatch.group(1), date, isArrival))

  /**
   * Parse EVERY flight row of `html` — the whole board, in board order. Used by the arrivals/departures board (an
   * unfiltered query returns many rows). Rows without a parseable flight number are skipped. Gate is not populated (it
   * lives on each flight's detail page; the board view does not expose it and fetching N detail pages would be far too
   * slow for a list).
   */
  def parseAll(html: String, date: LocalDate, isArrival: Boolean): List[FlightInfo] =
    RowRegex
      .findAllMatchIn(html)
      .flatMap(rowMatch => parseRow(rowMatch.group(1), date, isArrival))
      .toList

  /**
   * Parse a single `<tr>` flight row into a [[FlightInfo]] (None when the row has no flight number).
   */
  private def parseRow(row: String, date: LocalDate, isArrival: Boolean): Option[FlightInfo] = flightNumberOf(
    cell(row, "fp-flight-number").getOrElse("")
  ).map { rawNumber =>
    val statusLabel = cell(row, "fp-flight-status").getOrElse("")

    // The MUC time cell is "planned | expected"; the "other" cell is the time at the other airport.
    val mucTimeCell = cell(row, "fp-flight-time-muc").getOrElse("")
    val parts       = mucTimeCell.split("\\|", -1).map(_.trim)
    val plannedRaw  = parts.lift(0).getOrElse("")
    val expectedRaw = parts.lift(1).getOrElse("")

    val terminal = cell(row, "fp-flight-area").map(_.trim).filter(_.nonEmpty)
    val airline  = cell(row, "fp-flight-airline").filter(_.nonEmpty)
    val other    = cell(row, "fp-flight-airport").flatMap(iataOf)

    // The "other airport" time cell: for an ARRIVAL this is the origin's take-off, for a departure it is the
    // arrival at the destination. Only the arrival's take-off is meaningful for the en-route progress window.
    val otherTimeLt = localTimeOf(cell(row, "fp-flight-time-other").getOrElse(""))

    val plannedLt    = localTimeOf(plannedRaw)
    val expectedLt   = localTimeOf(expectedRaw)
    // Both halves are bare wall-clock HH:mm on the request date. A late-evening flight slipping past midnight
    // renders as e.g. "23:50 | 00:15" — the expected half belongs to the NEXT day. Anchoring it to the same
    // date would put the estimate ~23.5h BEFORE the schedule (a bogus negative delay), so when expected is
    // earlier than planned by more than 12h of wall clock we roll it to the next day. (The reverse — planned
    // just after midnight with an expected the previous evening — does not occur on the board.)
    val expectedDate =
      (plannedLt, expectedLt) match
        case (Some(p), Some(e)) if e.isBefore(p) && java.time.Duration.between(e, p).toHours > 12 => date.plusDays(1)
        case _                                                                                    => date

    // For an arrival, the origin take-off (the start of the en-route window the card animates). The board gives only
    // wall-clock time, not the origin date: a long-haul that departs the previous evening reads as e.g. "22:55" against
    // a "05:15" MUC arrival — i.e. the take-off is LATER in the day than the landing, which only makes sense a day
    // earlier. So when the departure time is after the MUC arrival time, roll it back one day. (Detail-page lookup
    // refines this with the origin's own date later; this list value is the reliable primary so the plane always shows.)
    val departureDate =
      (otherTimeLt, plannedLt) match
        case (Some(dep), Some(arr)) if dep.isAfter(arr) => date.minusDays(1)
        case _                                          => date
    val departureTime = if isArrival then otherTimeLt.map(atBerlin(departureDate, _)) else None

    FlightInfo(
      flightNumber = normalizeFlightNumber(rawNumber),
      isArrival = isArrival,
      status = FlightStatus.fromMuc(statusLabel),
      scheduledTime = plannedLt.map(atBerlin(date, _)),
      estimatedTime = expectedLt.map(atBerlin(expectedDate, _)),
      terminal = terminal,
      airline = airline,
      otherAirport = other,
      departureTime = departureTime
    )
  }

  /**
   * The relative URL of the first flight's detail page, taken from the list fragment's first `href`
   * (`/flugdetailseite-NNNNN?flight_id=X.Y`). The detail page is where the gate lives. None when the fragment has no
   * flight rows.
   */
  def detailHref(html: String): Option[String] = RowRegex.findFirstMatchIn(html).flatMap { rowMatch =>
    "href=\"(/flugdetailseite-[^\"]*flight_id=[^\"]+)\"".r.findFirstMatchIn(rowMatch.group(1)).map(_.group(1))
  }

  // A flight detail page renders two airport blocks (origin + destination). We want the gate of the MUC block —
  // i.e. the `flight-box-area` inside the block whose `flight-box-airport` contains "(MUC)". On a departure that is
  // the first block; on an arrival, the second. So we split the page into blocks and pick the MUC one rather than
  // assuming a position (see `mucArea`).

  /**
   * Extract the MUC gate code (e.g. "G35") from a flight detail page. Reads the `flight-box-area` of the block whose
   * airport is MUC (text like "T2 - Gate G35"), and returns just the gate token after "Gate". None when no gate is
   * published. Also exposes the terminal as a fallback for the list value.
   *
   * "Gate REMOTE" is a remote (bus) stand, not a passenger gate. It is kept (normalised to upper-case "REMOTE") rather
   * than dropped: the driver still needs to know the passenger arrives by apron bus (so it takes longer), and the
   * walk-buffer logic recognises "REMOTE" as the longest buffer. The terminal is still read separately.
   */
  def parseGate(detailHtml: String): Option[String] = mucArea(detailHtml).flatMap { area =>
    // area reads like "T2 - Gate G35" → take the token after "Gate".
    "(?i)gate\\s+(\\S+)".r
      .findFirstMatchIn(area)
      .map(_.group(1).trim)
      .filter(_.nonEmpty)
      .map(g => if g.equalsIgnoreCase("remote") then "REMOTE" else g)
  }

  /**
   * The terminal as printed on the detail page's MUC block (e.g. "T2" from "T2 - Gate G35").
   */
  def parseDetailTerminal(detailHtml: String): Option[String] = mucArea(detailHtml).flatMap { area =>
    "^(T\\d[A-Z]?)".r.findFirstMatchIn(area.trim).map(_.group(1))
  }

  // On the detail page each airport block renders `flight-box-airport">…</span>` followed (within the same block) by
  // `flight-box-area">…<`. We scan those (airport, area) pairs in order and pick the one whose airport label mentions
  // "(MUC)" — that is the MUC side regardless of departure/arrival ordering.
  private val AirportAreaRegex = "(?s)flight-box-airport\">(.*?)</span>(.*?)flight-box-area\">([^<]*)<".r

  /**
   * The `flight-box-area` text of the block whose airport label contains "(MUC)".
   */
  private def mucArea(detailHtml: String): Option[String] = AirportAreaRegex
    .findAllMatchIn(detailHtml)
    .find(m => textOf(m.group(1)).contains("(MUC)"))
    .map(m => textOf(m.group(3)))

  // The detail page's first overview block is the departure side (`departure-box`); for an arrival into MUC that is the
  // ORIGIN airport's take-off. We isolate that block (non-greedy up to the arrival block / overview end) so the date and
  // time we read are the origin's, not MUC's. Each block carries its OWN `flight-box-date` (dd.MM.yyyy), so a long-haul
  // that departs the previous calendar day (e.g. SIN 25.06 22:45 → MUC 26.06 05:20) reconstructs correctly.
  private val DepartureBlockRegex = "(?s)departure-box\"(.*?)(?:arrival-box\"|</div>\\s*</div>\\s*</div>\\s*$)".r
  private val FlightBoxDateRegex  = "(?s)flight-box-date\">\\s*(\\d{2})\\.(\\d{2})\\.(\\d{4})".r

  // A `<dt>Geplant:</dt>`/`<dt>Erwartet:</dt>` label followed by its `<dd>HH:mm</dd>`. Prefer "Erwartet" (live) over
  // "Geplant" (scheduled) when both are present, mirroring how `flightTime` prefers the estimated instant.
  private def labelledTime(block: String, label: String): Option[String] =
    ("(?s)<dt>\\s*" + label + ":\\s*</dt>\\s*<dd>\\s*(\\d{2}:\\d{2})\\s*</dd>").r
      .findFirstMatchIn(block)
      .map(_.group(1))

  /**
   * The flight's DEPARTURE instant from its origin airport, read off the detail page's departure block. For an arrival
   * into MUC this is when the aircraft took off elsewhere — the start of the en-route window the card animates against.
   * Prefers the live "Erwartet" time over scheduled "Geplant"; anchors it to the block's own date so a flight that
   * departed the previous day is still ordered before the MUC arrival. None when the page has no departure block/time.
   */
  def parseDepartureInstant(detailHtml: String): Option[java.time.Instant] =
    for
      block         <- DepartureBlockRegex.findFirstMatchIn(detailHtml).map(_.group(1))
      dateMatch     <- FlightBoxDateRegex.findFirstMatchIn(block)
      hhmm          <- labelledTime(block, "Erwartet").orElse(labelledTime(block, "Geplant"))
      (day, mon, yr) = (dateMatch.group(1).toInt, dateMatch.group(2).toInt, dateMatch.group(3).toInt)
      lt            <- scala.util.Try(LocalTime.parse(hhmm)).toOption
      ld            <- scala.util.Try(LocalDate.of(yr, mon, day)).toOption
    yield ld.atTime(lt).atZone(BerlinZone).toInstant
