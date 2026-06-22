package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.*
import java.time.Instant

enum DriverUnavailabilityReason:
  case Lunch, Vacation, Personal

final case class DriverUnavailability(
    id: DriverUnavailabilityId,
    driverId: PersonId,
    companyId: CompanyId,
    fromTime: Instant,
    toTime: Instant,
    reason: DriverUnavailabilityReason,
    note: Option[String],
    createdAt: Instant
)

final case class CreateDriverUnavailabilityRequest(
    driverId: PersonId,
    companyId: CompanyId,
    fromTime: Instant,
    toTime: Instant,
    reason: DriverUnavailabilityReason,
    note: Option[String] = None
)
