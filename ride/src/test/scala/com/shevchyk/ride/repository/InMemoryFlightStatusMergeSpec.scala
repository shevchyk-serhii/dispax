package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Merge semantics of `updateFlightStatus` on the in-memory double — it must mirror the Postgres COALESCE behaviour: a
 * scrape that could not read the gate/terminal/scheduled/departure values (None) must NOT erase previously stored ones,
 * while status and flight time (the live estimate) are authoritative on every tick.
 */
object InMemoryFlightStatusMergeSpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  private val clientId  = PersonId(UUID.fromString("22222222-0000-0000-0000-000000000001"))
  private val rideId    = RideId(UUID.fromString("11111111-0000-0000-0000-000000000001"))

  private val t1 = Instant.parse("2026-06-26T08:20:00Z")
  private val t2 = Instant.parse("2026-06-26T08:45:00Z")
  private val s1 = Instant.parse("2026-06-26T08:00:00Z")
  private val d1 = Instant.parse("2026-06-25T20:45:00Z")

  private def ride(): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = None,
    status = RideStatus.Requested,
    pickupLocation = Location("MUC Airport", Some(48.3537), Some(11.7750)),
    dropoffLocation = Location("Munich", Some(48.1351), Some(11.5820)),
    pickupDateTime = t1,
    specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH123"), isArrival = true))
  )

  def spec =
    suite("InMemoryRideRepository updateFlightStatus merge")(
      test("a partial update (gate/terminal/scheduled/departure unknown) keeps the stored values") {
        val repo = new InMemoryRideRepository
        for
          created <- repo.create(ride()) // the in-memory create assigns a fresh id
          id       = created.id
          _       <- repo.updateFlightStatus(id, Some("G35"), Some("T2"), Some("delayed"), Some(t1), Some(s1), Some(d1))
          // Next tick: the board row is there (status + live time) but the detail page failed → no gate, no
          // terminal; the scheduled/departure instants could not be parsed either.
          _       <- repo.updateFlightStatus(id, None, None, Some("landed"), Some(t2), None, None)
          row     <- repo.findFlightStatus(id)
        yield assertTrue(
          row.contains(FlightStatusRow(Some("G35"), Some("T2"), Some("landed"), Some(t2), Some(s1), Some(d1)))
        )
      },
      test("a freshly scraped value overrides the stored one") {
        val repo = new InMemoryRideRepository
        for
          created <- repo.create(ride())
          id       = created.id
          _       <- repo.updateFlightStatus(id, Some("G35"), Some("T2"), Some("delayed"), Some(t1), Some(s1), Some(d1))
          _       <- repo.updateFlightStatus(id, Some("K12"), Some("T2"), Some("landed"), Some(t2), Some(s1), Some(d1))
          row     <- repo.findFlightStatus(id)
        yield assertTrue(row.exists(_.gate.contains("K12")))
      },
      test("updateFlightStatus on an unknown ride still reports false") {
        val repo = new InMemoryRideRepository
        for ok <- repo.updateFlightStatus(rideId, Some("G35"), None, Some("landed"), None, None, None)
        yield assertTrue(!ok)
      }
    )
