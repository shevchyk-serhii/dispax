package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.{ApiError, ErrorMapper}
import sttp.model.StatusCode
import java.time.{Instant, LocalDate, LocalTime}

/**
 * Per-driver permission to view other drivers' full schedules. Absence of a row means `false`.
 */
final case class DriverScheduleVisibility(
    driverId: PersonId,
    companyId: CompanyId,
    canViewOtherSchedules: Boolean,
    updatedAt: Instant
)

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
):

  /**
   * Apply the patch onto an existing schedule day. The `startTime`, `endTime` and `status` values are passed in already
   * validated by the caller (time range and status-transition checks happen there); `notes` is merged from this request
   * and `updatedAt` is refreshed.
   */
  def applyTo(
      current: ScheduleDay,
      startTime: LocalTime,
      endTime: LocalTime,
      status: ScheduleDayStatus
  ): ScheduleDay = current.copy(
    startTime = startTime,
    endTime = endTime,
    status = status,
    notes = notes.orElse(current.notes),
    updatedAt = Instant.now()
  )

enum ScheduleError extends Throwable:
  case ValidationError(message: String)
  case ScheduleDayNotFound(id: ScheduleDayId)
  case UnavailabilityNotFound(id: DriverUnavailabilityId)
  case DriverNotFound(id: PersonId)
  case DuplicateScheduleDay(driverId: PersonId, date: LocalDate)
  case InvalidStatusTransition(from: ScheduleDayStatus, to: ScheduleDayStatus)
  case CompanyMismatch(expected: CompanyId, actual: CompanyId)
  case AccessDenied(message: String)
  case DatabaseError(cause: Throwable)

object ScheduleError:

  // HTTP status mapping lives next to the error definition; the Tapir endpoints
  // delegate to this via `ErrorMapper.fromThrowable` instead of repeating the match.
  given ErrorMapper[ScheduleError] = ErrorMapper.instance {
    case ValidationError(message)             => (StatusCode.BadRequest, ApiError(message))
    case ScheduleDayNotFound(id)              => (StatusCode.NotFound, ApiError(s"Schedule day not found: ${id.value}"))
    case UnavailabilityNotFound(id)           => (StatusCode.NotFound, ApiError(s"Unavailability not found: ${id.value}"))
    case DriverNotFound(id)                   => (StatusCode.NotFound, ApiError(s"Driver not found: ${id.value}"))
    case DuplicateScheduleDay(driverId, date) =>
      (StatusCode.Conflict, ApiError(s"Driver ${driverId.value} already has a schedule for $date"))
    case InvalidStatusTransition(from, to)    => (StatusCode.Conflict, ApiError(s"Cannot transition from $from to $to"))
    case CompanyMismatch(_, _)                => (StatusCode.Forbidden, ApiError("Schedule day belongs to a different company"))
    case AccessDenied(message)                => (StatusCode.Forbidden, ApiError(message))
    case DatabaseError(_)                     => (StatusCode.InternalServerError, ApiError("Internal server error"))
  }
