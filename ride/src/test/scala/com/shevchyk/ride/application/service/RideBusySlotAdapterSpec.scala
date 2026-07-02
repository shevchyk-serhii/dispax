package com.shevchyk.ride.application.service

import com.shevchyk.core.application.BusySlot
import com.shevchyk.core.domain.{CompanyId, Location, PersonId}
import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.*
import zio.test.*

import java.time.{Duration, Instant}
import java.util.UUID

/**
 * Unit tests for the busy-slot adapter: only bare time pairs cross the module boundary, the window filter and the
 * cancelled exclusion come from the repository method, and open-ended rides get the default duration.
 */
object RideBusySlotAdapterSpec extends ZIOSpecDefault {

  private val driverId    = PersonId(UUID.fromString("00000050-0000-0000-0000-000000000001"))
  private val otherDriver = PersonId(UUID.fromString("00000050-0000-0000-0000-000000000002"))
  private val companyId   = CompanyId(UUID.fromString("00000051-0000-0000-0000-000000000001"))

  private val windowFrom = Instant.parse("2026-07-01T00:00:00Z")
  private val windowTo   = Instant.parse("2026-07-08T00:00:00Z")

  private def makeRide(
      driver: Option[PersonId],
      pickup: Instant,
      end: Option[Instant] = None,
      status: RideStatus = RideStatus.Assigned
  ): Ride = Ride(
    id = com.shevchyk.core.domain.RideId.generate(),
    clientId = PersonId(UUID.randomUUID()),
    creatorId = PersonId(UUID.randomUUID()),
    companyId = companyId,
    driverId = driver,
    status = status,
    pickupLocation = Location("Marienplatz 1, München"),
    dropoffLocation = Location("Flughafen München"),
    pickupDateTime = pickup,
    endTime = end
  )

  def spec =
    suite("RideBusySlotAdapterSpec")(
      test("maps rides to bare time pairs; a ride with a recorded end keeps it") {
        val pickup = Instant.parse("2026-07-02T08:00:00Z")
        val end    = Instant.parse("2026-07-02T09:30:00Z")
        for {
          repo   <- ZIO.succeed(new InMemoryRideRepository)
          _      <- repo.create(makeRide(Some(driverId), pickup, end = Some(end)))
          adapter = RideBusySlotAdapter(repo)
          slots  <- adapter.slots(driverId, windowFrom, windowTo)
        } yield assertTrue(slots == List(BusySlot(pickup, end)))
      },
      test("an open-ended ride falls back to the default duration after pickup") {
        val pickup = Instant.parse("2026-07-02T08:00:00Z")
        for {
          repo   <- ZIO.succeed(new InMemoryRideRepository)
          _      <- repo.create(makeRide(Some(driverId), pickup))
          adapter = RideBusySlotAdapter(repo, defaultRideDuration = Duration.ofMinutes(45))
          slots  <- adapter.slots(driverId, windowFrom, windowTo)
        } yield assertTrue(slots == List(BusySlot(pickup, pickup.plus(Duration.ofMinutes(45)))))
      },
      test("cancelled rides, other drivers and rides outside the window are excluded") {
        for {
          repo   <- ZIO.succeed(new InMemoryRideRepository)
          _      <- repo.create(
                      makeRide(Some(driverId), Instant.parse("2026-07-02T08:00:00Z"), status = RideStatus.Cancelled)
                    )
          _      <- repo.create(makeRide(Some(otherDriver), Instant.parse("2026-07-02T10:00:00Z")))
          _      <- repo.create(makeRide(Some(driverId), Instant.parse("2026-06-01T08:00:00Z")))
          _      <- repo.create(makeRide(None, Instant.parse("2026-07-02T11:00:00Z")))
          adapter = RideBusySlotAdapter(repo)
          slots  <- adapter.slots(driverId, windowFrom, windowTo)
        } yield assertTrue(slots.isEmpty)
      }
    )
}
