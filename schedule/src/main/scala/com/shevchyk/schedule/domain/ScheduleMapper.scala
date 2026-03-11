package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.*
import java.time.Instant

object ScheduleMapper:

  def fromRequest(request: CreateScheduleDayRequest): ScheduleDay =
    val now = Instant.now()
    ScheduleDay(
      id = ScheduleDayId.generate(),
      driverId = request.driverId,
      companyId = request.companyId,
      date = request.date,
      startTime = request.startTime,
      endTime = request.endTime,
      status = ScheduleDayStatus.Scheduled,
      notes = request.notes,
      createdAt = now,
      updatedAt = now
    )
