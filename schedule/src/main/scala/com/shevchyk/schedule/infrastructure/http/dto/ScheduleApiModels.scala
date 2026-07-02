package com.shevchyk.schedule.infrastructure.http.dto

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.schedule.domain.{
  CreateDriverUnavailabilityRequest,
  CreateScheduleBatchDay,
  CreateScheduleBatchRequest,
  CreateScheduleDayRequest,
  DriverUnavailability,
  DriverUnavailabilityReason,
  DriverScheduleVisibility,
  ScheduleDay,
  ScheduleDayStatus,
  ScheduleError
}
import sttp.tapir.Schema
import zio.*
import zio.json.*
import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

case class ScheduleDayDto(
    id: String,
    driverId: String,
    companyId: String,
    date: String,
    startTime: String,
    endTime: String,
    status: String,
    notes: Option[String],
    createdAt: String,
    updatedAt: String
) derives JsonCodec

case class CreateScheduleDayApiRequest(
    driverId: String,
    date: String,
    startTime: String,
    endTime: String,
    notes: Option[String] = None
) derives JsonCodec

case class CreateScheduleBatchApiRequest(
    driverId: String,
    days: List[ScheduleBatchDayApiRequest]
) derives JsonCodec

case class ScheduleBatchDayApiRequest(
    date: String,
    startTime: String,
    endTime: String,
    notes: Option[String] = None
) derives JsonCodec

case class UpdateScheduleDayApiRequest(
    startTime: Option[String] = None,
    endTime: Option[String] = None,
    status: Option[String] = None,
    notes: Option[String] = None
) derives JsonCodec

object ScheduleBatchDayApiRequest:
  given Schema[ScheduleBatchDayApiRequest] = Schema.derived[ScheduleBatchDayApiRequest]

object ScheduleDayDto:

  given Schema[ScheduleDayDto] = Schema.derived[ScheduleDayDto]

  def fromDomain(day: ScheduleDay): ScheduleDayDto = ScheduleDayDto(
    id = day.id.value.toString,
    driverId = day.driverId.value.toString,
    companyId = day.companyId.value.toString,
    date = day.date.toString,
    startTime = day.startTime.toString,
    endTime = day.endTime.toString,
    status = day.status.toString,
    notes = day.notes,
    createdAt = day.createdAt.toString,
    updatedAt = day.updatedAt.toString
  )

object CreateScheduleDayApiRequest:

  given Schema[CreateScheduleDayApiRequest] = Schema.derived[CreateScheduleDayApiRequest]

  def toDomain(
      request: CreateScheduleDayApiRequest,
      companyId: CompanyId
  ): IO[ScheduleError, CreateScheduleDayRequest] = ZIO
    .attempt(UUID.fromString(request.driverId))
    .mapError(_ => ScheduleError.ValidationError(s"Invalid driver UUID format: ${request.driverId}"))
    .map { uuid =>
      CreateScheduleDayRequest(
        driverId = PersonId(uuid),
        companyId = companyId,
        date = LocalDate.parse(request.date),
        startTime = LocalTime.parse(request.startTime),
        endTime = LocalTime.parse(request.endTime),
        notes = request.notes
      )
    }

object CreateScheduleBatchApiRequest:

  given Schema[CreateScheduleBatchApiRequest] = Schema.derived[CreateScheduleBatchApiRequest]

  def toDomain(
      request: CreateScheduleBatchApiRequest,
      companyId: CompanyId
  ): IO[ScheduleError, CreateScheduleBatchRequest] = ZIO
    .attempt(UUID.fromString(request.driverId))
    .mapError(_ => ScheduleError.ValidationError(s"Invalid driver UUID format: ${request.driverId}"))
    .map { uuid =>
      CreateScheduleBatchRequest(
        driverId = PersonId(uuid),
        companyId = companyId,
        days = request.days.map { day =>
          CreateScheduleBatchDay(
            date = LocalDate.parse(day.date),
            startTime = LocalTime.parse(day.startTime),
            endTime = LocalTime.parse(day.endTime),
            notes = day.notes
          )
        }
      )
    }

object UpdateScheduleDayApiRequest:

  given Schema[UpdateScheduleDayApiRequest] = Schema.derived[UpdateScheduleDayApiRequest]

  def toDomain(request: UpdateScheduleDayApiRequest): com.shevchyk.schedule.domain.UpdateScheduleDayRequest =
    com.shevchyk.schedule.domain.UpdateScheduleDayRequest(
      startTime = request.startTime.map(LocalTime.parse),
      endTime = request.endTime.map(LocalTime.parse),
      status = request.status.map(ScheduleDayStatus.valueOf),
      notes = request.notes
    )

// -- Driver schedule visibility DTOs ----------------------------------------

/**
 * Response DTO for a single driver's schedule-visibility setting.
 */
case class DriverScheduleVisibilityDto(
    driverId: String,
    companyId: String,
    canViewOtherSchedules: Boolean,
    updatedAt: String
) derives JsonCodec

object DriverScheduleVisibilityDto:

  given Schema[DriverScheduleVisibilityDto] = Schema.derived[DriverScheduleVisibilityDto]

  def fromDomain(v: DriverScheduleVisibility): DriverScheduleVisibilityDto = DriverScheduleVisibilityDto(
    driverId = v.driverId.value.toString,
    companyId = v.companyId.value.toString,
    canViewOtherSchedules = v.canViewOtherSchedules,
    updatedAt = v.updatedAt.toString
  )

/**
 * Request DTO to update a driver's visibility flag (PUT body).
 */
case class SetDriverVisibilityRequest(canViewOtherSchedules: Boolean) derives JsonCodec

object SetDriverVisibilityRequest:
  given Schema[SetDriverVisibilityRequest] = Schema.derived[SetDriverVisibilityRequest]

// -- Driver unavailability DTOs ------------------------------------------------

/**
 * Response DTO for a single driver unavailability window.
 */
case class DriverUnavailabilityDto(
    id: String,
    driverId: String,
    companyId: String,
    fromTime: String,
    toTime: String,
    reason: String,
    note: Option[String],
    createdAt: String
) derives JsonCodec

object DriverUnavailabilityDto:

  given Schema[DriverUnavailabilityDto] = Schema.derived[DriverUnavailabilityDto]

  def fromDomain(u: DriverUnavailability): DriverUnavailabilityDto = DriverUnavailabilityDto(
    id = u.id.value.toString,
    driverId = u.driverId.value.toString,
    companyId = u.companyId.value.toString,
    fromTime = u.fromTime.toString,
    toTime = u.toTime.toString,
    reason = u.reason.toString,
    note = u.note,
    createdAt = u.createdAt.toString
  )

/**
 * Request DTO for creating a driver unavailability window. fromTime and toTime are ISO-8601 instant strings; reason
 * must be one of Lunch | Vacation | Personal.
 */
case class CreateDriverUnavailabilityApiRequest(
    driverId: String,
    fromTime: String,
    toTime: String,
    reason: String,
    note: Option[String] = None
) derives JsonCodec

object CreateDriverUnavailabilityApiRequest:

  given Schema[CreateDriverUnavailabilityApiRequest] = Schema.derived[CreateDriverUnavailabilityApiRequest]

  def toDomain(
      request: CreateDriverUnavailabilityApiRequest,
      companyId: CompanyId
  ): IO[ScheduleError, CreateDriverUnavailabilityRequest] =
    for {
      driverUuid <- ZIO
                      .attempt(UUID.fromString(request.driverId))
                      .orElseFail(ScheduleError.ValidationError(s"Invalid driver UUID: ${request.driverId}"))
      from       <- ZIO
                      .attempt(Instant.parse(request.fromTime))
                      .orElseFail(ScheduleError.ValidationError(s"Invalid fromTime format: ${request.fromTime}"))
      to         <- ZIO
                      .attempt(Instant.parse(request.toTime))
                      .orElseFail(ScheduleError.ValidationError(s"Invalid toTime format: ${request.toTime}"))
      reason     <- ZIO
                      .attempt(DriverUnavailabilityReason.valueOf(request.reason))
                      .orElseFail(
                        ScheduleError.ValidationError(
                          s"Invalid reason: ${request.reason}. Valid values: ${DriverUnavailabilityReason.values.mkString(", ")}"
                        )
                      )
    } yield CreateDriverUnavailabilityRequest(
      driverId = PersonId(driverUuid),
      companyId = companyId,
      fromTime = from,
      toTime = to,
      reason = reason,
      note = request.note
    )
