package com.shevchyk.schedule.infrastructure.http.dto

import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.schedule.domain.{
  CreateScheduleBatchDay,
  CreateScheduleBatchRequest,
  CreateScheduleDayRequest,
  ScheduleDay,
  ScheduleDayStatus
}
import zio.json.*
import java.time.{LocalDate, LocalTime}
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

object ScheduleDayDto:

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

  def toDomain(request: CreateScheduleDayApiRequest, companyId: CompanyId): CreateScheduleDayRequest =
    CreateScheduleDayRequest(
      driverId = PersonId(UUID.fromString(request.driverId)),
      companyId = companyId,
      date = LocalDate.parse(request.date),
      startTime = LocalTime.parse(request.startTime),
      endTime = LocalTime.parse(request.endTime),
      notes = request.notes
    )

object CreateScheduleBatchApiRequest:

  def toDomain(request: CreateScheduleBatchApiRequest, companyId: CompanyId): CreateScheduleBatchRequest =
    CreateScheduleBatchRequest(
      driverId = PersonId(UUID.fromString(request.driverId)),
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

object UpdateScheduleDayApiRequest:

  def toDomain(request: UpdateScheduleDayApiRequest): com.shevchyk.schedule.domain.UpdateScheduleDayRequest =
    com.shevchyk.schedule.domain.UpdateScheduleDayRequest(
      startTime = request.startTime.map(LocalTime.parse),
      endTime = request.endTime.map(LocalTime.parse),
      status = request.status.map(ScheduleDayStatus.valueOf),
      notes = request.notes
    )
