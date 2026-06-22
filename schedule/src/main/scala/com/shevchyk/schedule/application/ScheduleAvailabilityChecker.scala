package com.shevchyk.schedule.application

import com.shevchyk.core.application.{DriverAvailabilityChecker, UnavailabilitySlot}
import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.schedule.repository.DriverUnavailabilityRepository
import zio.*
import java.time.Instant

/**
 * Schedule-module implementation of the core port `DriverAvailabilityChecker`. Delegates to
 * `DriverUnavailabilityRepository.findOverlapping` and maps domain objects to the minimal `UnavailabilitySlot` value
 * defined in core — no schedule domain types leak across the module boundary.
 */
final class ScheduleAvailabilityChecker(repo: DriverUnavailabilityRepository) extends DriverAvailabilityChecker:

  override def overlappingUnavailability(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[UnavailabilitySlot]] = repo
    .findOverlapping(driverId, companyId, from, to)
    .map(_.map(u => UnavailabilitySlot(from = u.fromTime, to = u.toTime, reason = u.reason.toString)))

object ScheduleAvailabilityChecker:

  val layer: ZLayer[DriverUnavailabilityRepository, Nothing, DriverAvailabilityChecker] = ZLayer.fromFunction(
    ScheduleAvailabilityChecker.apply
  )
