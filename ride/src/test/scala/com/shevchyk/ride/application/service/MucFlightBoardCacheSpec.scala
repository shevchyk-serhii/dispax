package com.shevchyk.ride.application.service

import com.shevchyk.core.config.MucFlightConfig
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.*
import zio.cache.{Cache, Lookup}
import zio.http.Client
import zio.test.*

import java.time.LocalDate

/**
 * The arrivals/departures board is served through a 60s TTL cache: repeated dispatcher refreshes within the window must
 * NOT re-scrape MUC, and the board must be re-fetched once the TTL lapses. We exercise the exact caching the provider
 * uses by wiring a [[Cache]] with a counting lookup into [[MucFlightStatusProvider]] and driving time via TestClock.
 */
object MucFlightBoardCacheSpec extends ZIOSpecDefault:

  private val theDate = LocalDate.of(2026, 6, 28)

  private def flight(n: String) = FlightInfo(flightNumber = n, isArrival = true, status = FlightStatus.Landed)

  // A provider whose cache's lookup counts scrapes instead of hitting the network. Same TTL (60s) and key shape as the
  // production layer, so the cache behaviour under test is identical.
  private def cachedProvider(
      calls: Ref[Int]
  ): ZIO[Client & Scope, Nothing, MucFlightStatusProvider] =
    for
      client <- ZIO.service[Client]
      cache  <- Cache.make[(LocalDate, Boolean), Any, Throwable, List[FlightInfo]](
                  capacity = 64,
                  timeToLive = 60.seconds,
                  lookup = Lookup { case (_, _) => calls.update(_ + 1).as(List(flight("LH1751"))) }
                )
    yield new MucFlightStatusProvider(MucFlightConfig(enabled = true), client, cache)

  def spec = suite("MucFlightStatusProvider board cache")(
    test("a second list() within the TTL is served from cache (one scrape)") {
      for
        calls    <- Ref.make(0)
        provider <- cachedProvider(calls)
        r1       <- provider.list(theDate, isArrival = true)
        _        <- TestClock.adjust(30.seconds)
        r2       <- provider.list(theDate, isArrival = true)
        n        <- calls.get
      yield assertTrue(r1.map(_.flightNumber) == List("LH1751"), r2 == r1, n == 1)
    },
    test("after the TTL lapses, list() re-scrapes") {
      for
        calls    <- Ref.make(0)
        provider <- cachedProvider(calls)
        _        <- provider.list(theDate, isArrival = true)
        _        <- TestClock.adjust(61.seconds)
        _        <- provider.list(theDate, isArrival = true)
        n        <- calls.get
      yield assertTrue(n == 2)
    },
    test("different keys (date / direction) are cached independently") {
      for
        calls    <- Ref.make(0)
        provider <- cachedProvider(calls)
        _        <- provider.list(theDate, isArrival = true)
        _        <- provider.list(theDate, isArrival = false)
        _        <- provider.list(theDate.plusDays(1), isArrival = true)
        n        <- calls.get
      yield assertTrue(n == 3)
    }
  ).provideSome[Scope](Client.default)
