package com.shevchyk.core.application

import com.shevchyk.core.domain.{CompanyId, PersonId}
import zio.*
import java.time.Instant

/**
 * A minimal value returned by the availability checker — does NOT leak the schedule domain class into core or ride. The
 * schedule module implements this port and maps its domain into these.
 */
final case class UnavailabilitySlot(
    from: Instant,
    to: Instant,
    reason: String
)

/**
 * Port (defined in core) for checking driver unavailability windows. Implemented in the schedule module
 * (`ScheduleAvailabilityChecker`) and injected into RideService via DI in Application.scala. This keeps the
 * ride↔schedule sibling boundary clean: ride depends only on core, not schedule.
 */
trait DriverAvailabilityChecker:

  /**
   * Returns all manually-set unavailability windows for the given driver that overlap the half-open interval [from,
   * to). Tenant-scoped by companyId.
   */
  def overlappingUnavailability(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[UnavailabilitySlot]]
