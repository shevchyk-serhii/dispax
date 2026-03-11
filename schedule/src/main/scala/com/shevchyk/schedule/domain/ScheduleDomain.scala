package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.*
import java.time.{Instant, LocalDate, LocalTime}

enum ScheduleDayStatus:
  case Scheduled, Active, Completed, Cancelled

final case class ScheduleDay(
    id: ScheduleDayId,
    driverId: PersonId,
    companyId: CompanyId,
    date: LocalDate,
    startTime: LocalTime,
    endTime: LocalTime,
    status: ScheduleDayStatus,
    notes: Option[String],
    createdAt: Instant,
    updatedAt: Instant
)

final case class CreateScheduleDayRequest(
    driverId: PersonId,
    companyId: CompanyId,
    date: LocalDate,
    startTime: LocalTime,
    endTime: LocalTime,
    notes: Option[String] = None
)

final case class CreateScheduleBatchRequest(
    driverId: PersonId,
    companyId: CompanyId,
    days: List[CreateScheduleBatchDay]
)

final case class CreateScheduleBatchDay(
    date: LocalDate,
    startTime: LocalTime,
    endTime: LocalTime,
    notes: Option[String] = None
)

final case class UpdateScheduleDayRequest(
    startTime: Option[LocalTime] = None,
    endTime: Option[LocalTime] = None,
    status: Option[ScheduleDayStatus] = None,
    notes: Option[String] = None
)

enum ScheduleError extends Throwable:
  case ValidationError(message: String)
  case ScheduleDayNotFound(id: ScheduleDayId)
  case DriverNotFound(id: PersonId)
  case DuplicateScheduleDay(driverId: PersonId, date: LocalDate)
  case InvalidStatusTransition(from: ScheduleDayStatus, to: ScheduleDayStatus)
  case CompanyMismatch(expected: CompanyId, actual: CompanyId)
  case DatabaseError(cause: Throwable)

object ScheduleError
