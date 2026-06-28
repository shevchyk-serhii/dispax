package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}
import zio.test.*

import java.time.Instant

/**
 * The whole-day arrivals board is assembled by walking server-side pages (each a ~4h window) and concatenating them.
 * `dedupBoard` collapses any duplicate that overlaps a page boundary, keyed by (flightNumber, scheduledTime), while
 * preserving board order.
 */
object MucBoardDedupSpec extends ZIOSpecDefault:

  private def f(n: String, t: String) = FlightInfo(
    flightNumber = n,
    isArrival = true,
    status = FlightStatus.Scheduled,
    scheduledTime = Some(Instant.parse(t))
  )

  def spec =
    suite("MucFlightStatusProvider.dedupBoard")(
      test("removes a duplicate (same flight + scheduled time) at a page boundary, keeps order") {
        val page0 = List(f("LH100", "2026-06-28T05:00:00Z"), f("LH200", "2026-06-28T08:55:00Z"))
        val page1 = List(f("LH200", "2026-06-28T08:55:00Z"), f("LH300", "2026-06-28T12:30:00Z"))
        val out   = MucFlightStatusProvider.dedupBoard(page0 ++ page1)
        assertTrue(
          out.map(_.flightNumber) == List("LH100", "LH200", "LH300"), // LH200 once, order preserved
          out.size == 3
        )
      },
      test("keeps the same flight number at different scheduled times (two real legs)") {
        val all = List(f("LH900", "2026-06-28T07:00:00Z"), f("LH900", "2026-06-28T19:00:00Z"))
        val out = MucFlightStatusProvider.dedupBoard(all)
        assertTrue(out.size == 2)
      },
      test("empty stays empty") {
        assertTrue(MucFlightStatusProvider.dedupBoard(Nil).isEmpty)
      }
    )
