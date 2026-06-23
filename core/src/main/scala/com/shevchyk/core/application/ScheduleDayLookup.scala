package com.shevchyk.core.application

import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import zio.*

/**
 * A minimal projection of a schedule day — does NOT leak the schedule domain class into core or ride. The schedule
 * module implements this port and maps its `ScheduleDay` into these values.
 *
 * `active` is `false` when the day was cancelled (or is otherwise no longer usable as the basis for a driver
 * assignment).
 */
final case class ScheduleDaySnapshot(
    id: ScheduleDayId,
    driverId: PersonId,
    companyId: CompanyId,
    active: Boolean
)

/**
 * Port (defined in core) for looking up schedule days. Implemented in the schedule module (`ScheduleDayLookupAdapter`)
 * and injected into RideService via DI in Application.scala. This keeps the ride↔schedule sibling boundary clean: ride
 * depends only on core, not schedule.
 */
trait ScheduleDayLookup:

  /**
   * Returns the schedule day with the given id, or `None` when it does not exist.
   */
  def find(id: ScheduleDayId): Task[Option[ScheduleDaySnapshot]]
