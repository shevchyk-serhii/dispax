package com.shevchyk.ride.application.service

import com.shevchyk.core.config.MucFlightConfig
import com.shevchyk.ride.domain.FlightInfo
import zio.*
import zio.cache.{Cache, Lookup}
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
final class MucFlightStatusProvider(
    config: MucFlightConfig,
    client: Client,
    boardCache: Cache[(LocalDate, Boolean), Throwable, List[FlightInfo]]
) extends FlightStatusProvider:

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

  override def list(date: LocalDate, isArrival: Boolean): Task[List[FlightInfo]] =
    if !config.enabled then ZIO.logDebug("MUC flight provider disabled").as(Nil)
    else
      // Serve from the TTL cache (it dedups concurrent dispatchers hitting the same board). A scrape failure is
      // surfaced through the cache's error channel, NOT cached, and degrades to an empty list here — so a transient
      // MUC outage neither poisons the cache nor fails the request.
      boardCache
        .get((date, isArrival))
        .catchAll(err =>
          ZIO.logWarning(s"MUC flight board error ($date arrival=$isArrival): ${err.getMessage}").as(Nil)
        )

  /**
   * Fetch the detail page for `href` and merge its gate (and terminal fallback) into `info`. Detail failures are
   * swallowed — a missing gate must not lose the list data we already have. For arrivals we also read the origin's
   * take-off instant from the same page so the card can show how far along the flight is.
   */
  private def enrichWithGate(info: FlightInfo, href: String): Task[Option[FlightInfo]] = httpGet(
    s"${config.baseUrl}$href"
  )
    .map { detailBody =>
      Some(
        info.copy(
          gate = MucFlightParser.parseGate(detailBody),
          terminal = info.terminal.orElse(MucFlightParser.parseDetailTerminal(detailBody)),
          // Only an arrival's origin take-off is meaningful for the en-route progress; a departure's block is MUC itself.
          departureTime = if info.isArrival then MucFlightParser.parseDepartureInstant(detailBody) else None
        )
      )
    }
    .catchAll(err => ZIO.logDebug(s"MUC gate fetch failed for $href: ${err.getMessage}").as(Some(info)))

  /**
   * GET a MUC page with browser-like headers. Delegates to the companion so the cache lookup (which has no instance)
   * can reuse the same request logic.
   */
  private def httpGet(url: String): Task[String] = MucFlightStatusProvider.httpGet(client, url)

object MucFlightStatusProvider:

  // A realistic desktop UA: without it the MUC server returns a near-empty stub page (verified — a bare-UA GET of a
  // detail page returns ~248 bytes, a browser UA returns the full ~40 KB page with the gate).
  private val BrowserUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"

  // How long a scraped board stays fresh. The board's statuses/times move on a minutes scale, so a short TTL keeps it
  // current while collapsing bursts of dispatcher refreshes into a single MUC scrape.
  private val BoardCacheTtl: Duration = 60.seconds

  /**
   * GET a MUC page with the browser-like headers the server requires (a bare UA returns a near-empty stub).
   */
  private def httpGet(client: Client, url: String): Task[String] = ZIO.scoped {
    for
      decoded  <- ZIO.fromEither(URL.decode(url)).mapError(e => new RuntimeException(s"Bad MUC url: $e"))
      response <- client.request(
                    Request
                      .get(decoded)
                      .addHeader(Header.Custom("User-Agent", BrowserUserAgent))
                      .addHeader(Header.Custom("Accept", "text/html,application/xhtml+xml"))
                      .addHeader(Header.Custom("Accept-Language", "de-DE,de;q=0.9"))
                      .addHeader(Header.Custom("X-Requested-With", "XMLHttpRequest"))
                  )
      body     <- response.body.asString
    yield body
  }

  // The board paginates server-side and IGNORES per_page (~one ~4h window per page), so a single page only covers the
  // morning. We walk pages 0,1,2,… until one comes back empty (or the safety cap), to cover the whole day. Cap is
  // generous: a day is ~5 pages today, 12 leaves headroom without risking a runaway if the markup changes.
  private val MaxBoardPages = 12

  /**
   * Stable dedup of the concatenated board pages by (flightNumber, scheduledTime), preserving board order. A flight
   * never legitimately spans two pages; this only guards against an overlap at a page boundary. Package-private for
   * unit testing.
   */
  private[service] def dedupBoard(all: List[FlightInfo]): List[FlightInfo] =
    val seen = scala.collection.mutable.LinkedHashMap.empty[(String, Option[java.time.Instant]), FlightInfo]
    all.foreach(f => seen.getOrElseUpdate((f.flightNumber, f.scheduledTime), f))
    seen.values.toList

  /**
   * One board page (no flight-number filter).
   */
  private def fetchPage(
      config: MucFlightConfig,
      client: Client,
      date: LocalDate,
      isArrival: Boolean,
      page: Int
  ): Task[List[FlightInfo]] =
    val path      = if isArrival then "arrivals" else "departures"
    val dirParam  = if isArrival then "flight_to_muc" else "flight_from_muc"
    val dateParam = if isArrival then "flight_date_to_muc" else "flight_date_from_muc"
    val q         =
      s"flight_search_presenter%5B$dirParam%5D=1" +
        s"&flight_search_presenter%5B$dateParam%5D=$date" +
        s"&flight_search_presenter%5Blocale%5D=de" +
        s"&page=$page&per_page=100&allow_pagination=1"
    val listUrl   = s"${config.baseUrl}/flightsearch/$path?$q"
    httpGet(client, listUrl).map(body => MucFlightParser.parseAll(body, date, isArrival))

  /**
   * Raw, uncached whole-DAY board scrape — the cache's lookup. Walks pages until one is empty (server ignores per_page,
   * paginating ~4h windows), concatenates in board order and dedups by (flightNumber, scheduledTime) — a flight never
   * spans two pages but the dedup guards against an overlap on the page boundary. The gate is not fetched per row (too
   * slow). Fails on HTTP/parse error so failures are not cached.
   */
  private def fetchBoard(
      config: MucFlightConfig,
      client: Client,
      date: LocalDate,
      isArrival: Boolean
  ): Task[List[FlightInfo]] =
    def loop(page: Int, acc: List[FlightInfo]): Task[List[FlightInfo]] =
      if page >= MaxBoardPages then ZIO.succeed(acc)
      else
        fetchPage(config, client, date, isArrival, page).flatMap { rows =>
          if rows.isEmpty then ZIO.succeed(acc)
          else loop(page + 1, acc ++ rows)
        }
    loop(0, Nil).map(dedupBoard)

  // Scoped because the cache lives for the app's lifetime. The TTL cache also dedups concurrent lookups of the same
  // (date, direction) key, so simultaneous dispatcher refreshes trigger a single MUC scrape.
  val layer: ZLayer[MucFlightConfig & Client, Nothing, FlightStatusProvider] = ZLayer.scoped {
    for
      config <- ZIO.service[MucFlightConfig]
      client <- ZIO.service[Client]
      cache  <- Cache.make[(LocalDate, Boolean), Any, Throwable, List[FlightInfo]](
                  capacity = 64,
                  timeToLive = BoardCacheTtl,
                  lookup = Lookup { case (date, isArrival) => fetchBoard(config, client, date, isArrival) }
                )
    yield new MucFlightStatusProvider(config, client, cache)
  }
