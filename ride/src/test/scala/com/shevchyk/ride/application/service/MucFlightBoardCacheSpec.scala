package com.shevchyk.ride.application.service

import com.shevchyk.core.config.MucFlightConfig
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.*
import zio.cache.Lookup
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

  // A provider whose cache's lookup counts scrapes instead of hitting the network. Built through the SAME
  // `makeBoardCache` factory the production layer uses, so the cache behaviour under test is identical.
  private def providerWithLookup(
      lookup: Lookup[(LocalDate, Boolean), Any, Throwable, List[FlightInfo]]
  ): ZIO[Any, Nothing, MucFlightStatusProvider] =
    for
      cache       <- MucFlightStatusProvider.makeBoardCache(lookup)
      lookupCache <- MucFlightStatusProvider.makeLookupCache(
                       Lookup { case (_, _, _) => ZIO.dieMessage("per-flight lookup is not under test here") }
                     )
    yield new MucFlightStatusProvider(MucFlightConfig(enabled = true), cache, lookupCache)

  private def cachedProvider(calls: Ref[Int]): ZIO[Any, Nothing, MucFlightStatusProvider] = providerWithLookup(Lookup {
    case (_, _) => calls.update(_ + 1).as(List(flight("LH1751")))
  })

  // First scrape fails (MUC down), every later one succeeds — for the failure-is-not-cached tests.
  private def failingFirstProvider(calls: Ref[Int]): ZIO[Any, Nothing, MucFlightStatusProvider] = providerWithLookup(
    Lookup { case (_, _) =>
      calls
        .updateAndGet(_ + 1)
        .flatMap(n =>
          if n == 1 then ZIO.fail(new RuntimeException("MUC down")) else ZIO.succeed(List(flight("LH1751")))
        )
    }
  )

  def spec =
    suite("MucFlightStatusProvider board cache")(
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
      test("a failed scrape is NOT cached — the next list() within the TTL hits the source again") {
        // A transient MUC outage degrades that one call to Nil but must not poison the board for the whole TTL:
        // the very next list() re-scrapes and can succeed.
        for
          calls    <- Ref.make(0)
          provider <- failingFirstProvider(calls)
          r1       <- provider.list(theDate, isArrival = true) // scrape fails → degrades to Nil
          _        <- TestClock.adjust(1.second)               // well within the 60s TTL
          r2       <- provider.list(theDate, isArrival = true) // must hit the source again, not the cached failure
          n        <- calls.get
        yield assertTrue(r1.isEmpty, r2.map(_.flightNumber) == List("LH1751"), n == 2)
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
    )
