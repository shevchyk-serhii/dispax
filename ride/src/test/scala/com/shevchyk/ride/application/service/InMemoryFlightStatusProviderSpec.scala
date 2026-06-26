package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.test.*

import java.time.LocalDate

/**
 * Sanity tests for the in-memory FlightStatusProvider double used by other specs.
 */
object InMemoryFlightStatusProviderSpec extends ZIOSpecDefault:

  private val date = LocalDate.of(2026, 6, 26)

  def spec =
    suite("InMemoryFlightStatusProvider")(
      test("returns a seeded flight, matching on normalized number + direction") {
        for
          provider <- InMemoryFlightStatusProvider.make
          info      = FlightInfo("LH 123", isArrival = true, FlightStatus.Landed, terminal = Some("T2"))
          _        <- provider.seed(info)
          // Lookup with differently-spaced number → still matches (normalization).
          found    <- provider.lookup("lh123", date, isArrival = true)
          wrongDir <- provider.lookup("LH123", date, isArrival = false)
        yield assertTrue(
          found.exists(_.terminal.contains("T2")),
          wrongDir.isEmpty
        )
      },
      test("returns None when nothing is seeded") {
        for
          provider <- InMemoryFlightStatusProvider.make
          found    <- provider.lookup("LH999", date, isArrival = false)
        yield assertTrue(found.isEmpty)
      }
    )
