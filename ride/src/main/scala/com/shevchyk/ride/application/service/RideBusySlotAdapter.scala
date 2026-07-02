package com.shevchyk.ride.application.service

import com.shevchyk.core.application.{BusySlot, DriverBusySlots}
import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.{Duration, Instant}

/**
 * Implements the core [[DriverBusySlots]] port from the ride repository. Maps each non-cancelled ride of the driver to
 * a bare time interval — only the two instants leave the ride module, never client, addresses or price. Rides without a
 * recorded `endTime` (not yet finished) fall back to `defaultRideDuration` after pickup.
 */
final class RideBusySlotAdapter(
    rideRepository: RideRepository,
    defaultRideDuration: Duration = RideBusySlotAdapter.DefaultRideDuration
) extends DriverBusySlots:

  override def slots(driverId: PersonId, from: Instant, to: Instant): Task[List[BusySlot]] = rideRepository
    .findByDriverIdInWindow(driverId, from, to)
    .map(_.map { ride =>
      BusySlot(
        start = ride.pickupDateTime,
        end = ride.endTime.getOrElse(ride.pickupDateTime.plus(defaultRideDuration))
      )
    })

object RideBusySlotAdapter:

  /**
   * Fallback duration for rides that have no recorded end yet. One hour is the typical Munich-area transfer; the exact
   * value only affects how long a busy bar renders in a shared calendar, never any assignment logic.
   */
  val DefaultRideDuration: Duration = Duration.ofHours(1)

  val layer: ZLayer[RideRepository, Nothing, DriverBusySlots] = ZLayer.fromFunction((repo: RideRepository) =>
    RideBusySlotAdapter(repo)
  )
