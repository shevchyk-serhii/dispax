package com.shevchyk.schedule.application

import com.shevchyk.core.application.{ScheduleDayLookup, ScheduleDaySnapshot}
import com.shevchyk.core.domain.ScheduleDayId
import com.shevchyk.schedule.domain.ScheduleDayStatus
import com.shevchyk.schedule.repository.ScheduleDayRepository
import zio.*

/**
 * Schedule-module implementation of the core port `ScheduleDayLookup`. Delegates to `ScheduleDayRepository.findById`
 * and maps the `ScheduleDay` domain object to the minimal `ScheduleDaySnapshot` value defined in core — no schedule
 * domain types leak across the module boundary.
 *
 * A day counts as `active` unless it was cancelled.
 */
final class ScheduleDayLookupAdapter(repo: ScheduleDayRepository) extends ScheduleDayLookup:

  override def find(id: ScheduleDayId): Task[Option[ScheduleDaySnapshot]] = repo
    .findById(id)
    .map(
      _.map(day =>
        ScheduleDaySnapshot(
          id = day.id,
          driverId = day.driverId,
          companyId = day.companyId,
          active = day.status != ScheduleDayStatus.Cancelled
        )
      )
    )

object ScheduleDayLookupAdapter:

  val layer: ZLayer[ScheduleDayRepository, Nothing, ScheduleDayLookup] = ZLayer.fromFunction(
    ScheduleDayLookupAdapter.apply
  )
