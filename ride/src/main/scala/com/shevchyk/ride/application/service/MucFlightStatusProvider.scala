package com.shevchyk.ride.application.service

import com.shevchyk.core.config.MucFlightConfig
import com.shevchyk.ride.domain.FlightInfo
import zio.*
import zio.http.*
import java.time.LocalDate

/**
 * [[FlightStatusProvider]] backed by the public Munich Airport (MUC) flight board.
 *
 * Calls `GET /flightsearch/{departures,arrivals}` filtered by flight number + date and parses the returned HTML
 * fragment with the pure [[MucFlightParser]]. No authentication is required (a bare GET returns 200). MVP-scoped to
 * Munich.
 *
 * Pattern mirrors `HereRoutingService`: build URL, `ZIO.scoped` request, parse, and `catchAll` any failure into a
 * logged `None` so the effect never fails (graceful degradation — see [[FlightStatusProvider]]).
 */
final class MucFlightStatusProvider(config: MucFlightConfig, client: Client) extends FlightStatusProvider:

  override def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]] =
    if !config.enabled then ZIO.logDebug("MUC flight provider disabled").as(None)
    else
      val number    = MucFlightParser.normalizeFlightNumber(flightNumber)
      val path      = if isArrival then "arrivals" else "departures"
      val dirParam  = if isArrival then "flight_to_muc" else "flight_from_muc"
      val dateParam = if isArrival then "flight_date_to_muc" else "flight_date_from_muc"

      // Square brackets must be percent-encoded; the board reads form params under the
      // `flight_search_presenter[...]` namespace. locale=de is irrelevant to the status string
      // (it stays German regardless) but keeps the request shape identical to the browser's.
      val q       =
        s"flight_search_presenter%5B$dirParam%5D=1" +
          s"&flight_search_presenter%5B$dateParam%5D=$date" +
          s"&flight_search_presenter%5Bflight_number%5D=$number" +
          s"&flight_search_presenter%5Blocale%5D=de" +
          s"&page=0&per_page=6&allow_pagination=1"
      val listUrl = s"${config.baseUrl}/flightsearch/$path?$q"

      (for
        listBody <- httpGet(listUrl)
        base      = MucFlightParser.parse(listBody, date, isArrival)
        // The gate is only on the flight's detail page; fetch it when the list yielded a flight and a detail link.
        enriched <-
          base match
            case None       => ZIO.none
            case Some(info) =>
              MucFlightParser.detailHref(listBody) match
                case None       => ZIO.some(info)
                case Some(href) => enrichWithGate(info, href)
      yield enriched)
        .catchAll { err =>
          ZIO.logWarning(s"MUC flight lookup error for $number: ${err.getMessage}").as(None)
        }

  /**
   * Fetch the detail page for `href` and merge its gate (and terminal fallback) into `info`. Detail failures are
   * swallowed — a missing gate must not lose the list data we already have.
   */
  private def enrichWithGate(info: FlightInfo, href: String): Task[Option[FlightInfo]] = httpGet(
    s"${config.baseUrl}$href"
  )
    .map { detailBody =>
      Some(
        info.copy(
          gate = MucFlightParser.parseGate(detailBody),
          terminal = info.terminal.orElse(MucFlightParser.parseDetailTerminal(detailBody))
        )
      )
    }
    .catchAll(err => ZIO.logDebug(s"MUC gate fetch failed for $href: ${err.getMessage}").as(Some(info)))

  /**
   * GET a MUC page with browser-like headers. Without a real User-Agent the server returns a stub page (no flight
   * data), so the headers are required, not cosmetic.
   */
  private def httpGet(url: String): Task[String] = ZIO.scoped {
    for
      decoded  <- ZIO.fromEither(URL.decode(url)).mapError(e => new RuntimeException(s"Bad MUC url: $e"))
      response <- client.request(
                    Request
                      .get(decoded)
                      .addHeader(Header.Custom("User-Agent", MucFlightStatusProvider.BrowserUserAgent))
                      .addHeader(Header.Custom("Accept", "text/html,application/xhtml+xml"))
                      .addHeader(Header.Custom("Accept-Language", "de-DE,de;q=0.9"))
                      .addHeader(Header.Custom("X-Requested-With", "XMLHttpRequest"))
                  )
      body     <- response.body.asString
    yield body
  }

object MucFlightStatusProvider:

  // A realistic desktop UA: without it the MUC server returns a near-empty stub page (verified — a bare-UA GET of a
  // detail page returns ~248 bytes, a browser UA returns the full ~40 KB page with the gate).
  private val BrowserUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"

  val layer: ZLayer[MucFlightConfig & Client, Nothing, FlightStatusProvider] = ZLayer.fromFunction(
    new MucFlightStatusProvider(_, _)
  )
