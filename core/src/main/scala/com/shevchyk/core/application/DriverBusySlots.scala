package com.shevchyk.core.application

import com.shevchyk.core.domain.PersonId
import zio.*

import java.time.Instant

/**
 * A PII-free time interval during which a driver is occupied by a ride. Deliberately carries nothing but the two
 * instants — client, addresses and price never cross the module boundary through this port.
 */
final case class BusySlot(start: Instant, end: Instant)

/**
 * Port (defined in core) for deriving a driver's busy intervals from their rides. Implemented in the ride module
 * (`RideBusySlotAdapter`) and injected into the schedule module's CalendarShareService via DI in Application.scala.
 * This keeps the schedule↔ride sibling boundary clean: schedule depends only on core, not ride (mirrors
 * [[ScheduleDayLookup]] in the opposite direction).
 */
trait DriverBusySlots:

  /**
   * Busy intervals for the driver's rides whose pickup falls in the half-open window [from, to). Cancelled rides are
   * excluded. Rides without a recorded end get a default duration applied by the implementation.
   */
  def slots(driverId: PersonId, from: Instant, to: Instant): Task[List[BusySlot]]
