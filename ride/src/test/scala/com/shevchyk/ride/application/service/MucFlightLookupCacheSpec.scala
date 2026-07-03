package com.shevchyk.ride.application.service

import com.shevchyk.core.config.MucFlightConfig
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.*
import zio.cache.Lookup
import zio.test.*

import java.time.LocalDate

/**
 * The per-flight lookup() is served through the same 60s TTL cache shape as the board: every uncached lookup costs up
 * to 2 live HTTP requests against the MUC site, so repeated card refreshes for the same flight within the window must
 * NOT re-fetch (IP-ban risk), while a fetch FAILURE must not be retained. We exercise the exact production cache by
 * wiring `makeLookupCache` with a counting lookup into [[MucFlightStatusProvider]] and driving time via TestClock.
 */
object MucFlightLookupCacheSpec extends ZIOSpecDefault:

  private val theDate = LocalDate.of(2026, 6, 28)

  private def flight(n: String) = FlightInfo(
    flightNumber = n,
    isArrival = true,
    status = FlightStatus.Landed,
    gate = Some("G35")
  )

  // An unroutable baseUrl: if the provider ever bypasses the cache it fails fast locally instead of hitting the
  // real MUC site from a test.
  private val config = MucFlightConfig(enabled = true, baseUrl = "http://127.0.0.1:9")

  // A provider whose lookup cache counts upstream fetches instead of hitting the network. Built through the SAME
  // `makeLookupCache` factory the production layer uses, so the cache behaviour under test is identical.
  private def providerWithLookup(
      lookup: Lookup[(String, LocalDate, Boolean), Any, Throwable, Option[FlightInfo]]
  ): ZIO[Any, Nothing, MucFlightStatusProvider] =
    for
      boardCache  <- MucFlightStatusProvider.makeBoardCache(
                       Lookup { case (_, _) => ZIO.dieMessage("the board is not under test here") }
                     )
      lookupCache <- MucFlightStatusProvider.makeLookupCache(lookup)
    yield new MucFlightStatusProvider(config, boardCache, lookupCache)

  private def cachedProvider(calls: Ref[Int]): ZIO[Any, Nothing, MucFlightStatusProvider] = providerWithLookup(Lookup {
    case (number, _, _) => calls.update(_ + 1).as(Some(flight(number)))
  })

  // First fetch fails (MUC down), every later one succeeds — for the failure-is-not-cached test.
  private def failingFirstProvider(calls: Ref[Int]): ZIO[Any, Nothing, MucFlightStatusProvider] = providerWithLookup(
    Lookup { case (number, _, _) =>
      calls
        .updateAndGet(_ + 1)
        .flatMap(n => if n == 1 then ZIO.fail(new RuntimeException("MUC down")) else ZIO.succeed(Some(flight(number))))
    }
  )

  def spec =
    suite("MucFlightStatusProvider lookup cache")(
      test("a second lookup() of the same flight within the TTL is served from cache (one upstream fetch)") {
        for
          calls    <- Ref.make(0)
          provider <- cachedProvider(calls)
          r1       <- provider.lookup("LH 1751", theDate, isArrival = true)
          _        <- TestClock.adjust(30.seconds)
          // A differently-written number ("lh1751") must normalize onto the SAME cache key.
          r2       <- provider.lookup("lh1751", theDate, isArrival = true)
          n        <- calls.get
        yield assertTrue(r1.map(_.flightNumber).contains("LH1751"), r2 == r1, n == 1)
      },
      test("after the TTL lapses, lookup() fetches again") {
        for
          calls    <- Ref.make(0)
          provider <- cachedProvider(calls)
          _        <- provider.lookup("LH1751", theDate, isArrival = true)
          _        <- TestClock.adjust(61.seconds)
          _        <- provider.lookup("LH1751", theDate, isArrival = true)
          n        <- calls.get
        yield assertTrue(n == 2)
      },
      test("a failed fetch is NOT cached — the next lookup() within the TTL hits the source again") {
        for
          calls    <- Ref.make(0)
          provider <- failingFirstProvider(calls)
          r1       <- provider.lookup("LH1751", theDate, isArrival = true) // fetch fails → degrades to None
          _        <- TestClock.adjust(1.second)                           // well within the 60s TTL
          r2       <- provider.lookup("LH1751", theDate, isArrival = true) // must fetch again, not replay the failure
          n        <- calls.get
        yield assertTrue(r1.isEmpty, r2.map(_.flightNumber).contains("LH1751"), n == 2)
      },
      test("different flights / dates / directions are cached independently") {
        for
          calls    <- Ref.make(0)
          provider <- cachedProvider(calls)
          _        <- provider.lookup("LH1751", theDate, isArrival = true)
          _        <- provider.lookup("LH1752", theDate, isArrival = true)
          _        <- provider.lookup("LH1751", theDate.plusDays(1), isArrival = true)
          _        <- provider.lookup("LH1751", theDate, isArrival = false)
          n        <- calls.get
        yield assertTrue(n == 4)
      }
    )
