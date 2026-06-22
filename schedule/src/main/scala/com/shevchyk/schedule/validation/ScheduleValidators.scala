package com.shevchyk.schedule.validation

import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.*
import java.time.Instant
import com.shevchyk.schedule.validation.Validator
import zio.*
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import scala.util.Try

given createScheduleDayApiRequestValidator: Validator[CreateScheduleDayApiRequest] with
  type Error = ScheduleError

  def validate(request: CreateScheduleDayApiRequest): IO[ScheduleError, CreateScheduleDayApiRequest] =
    for {
      _ <- validateUuid(request.driverId, "Driver ID")
      _ <- validateDate(request.date)
      _ <- validateTime(request.startTime, "Start time")
      _ <- validateTime(request.endTime, "End time")
      _ <- validateTimeOrder(request.startTime, request.endTime)
    } yield request

given createScheduleBatchApiRequestValidator: Validator[CreateScheduleBatchApiRequest] with
  type Error = ScheduleError

  def validate(request: CreateScheduleBatchApiRequest): IO[ScheduleError, CreateScheduleBatchApiRequest] =
    for {
      _ <- validateUuid(request.driverId, "Driver ID")
      _ <-
        ZIO.when(request.days.isEmpty)(
          ZIO.fail(ScheduleError.ValidationError("At least one day is required"))
        )
      _ <-
        ZIO.foreach(request.days) { day =>
          for {
            _ <- validateDate(day.date)
            _ <- validateTime(day.startTime, "Start time")
            _ <- validateTime(day.endTime, "End time")
            _ <- validateTimeOrder(day.startTime, day.endTime)
          } yield ()
        }
    } yield request

given updateScheduleDayApiRequestValidator: Validator[UpdateScheduleDayApiRequest] with
  type Error = ScheduleError

  def validate(request: UpdateScheduleDayApiRequest): IO[ScheduleError, UpdateScheduleDayApiRequest] =
    for {
      _ <- request.startTime.map(t => validateTime(t, "Start time")).getOrElse(ZIO.unit)
      _ <- request.endTime.map(t => validateTime(t, "End time")).getOrElse(ZIO.unit)
      _ <-
        (request.startTime, request.endTime) match
          case (Some(start), Some(end)) => validateTimeOrder(start, end)
          case _                        => ZIO.unit
      _ <- request.status.map(validateStatus).getOrElse(ZIO.unit)
    } yield request

given createDriverUnavailabilityApiRequestValidator: Validator[CreateDriverUnavailabilityApiRequest] with
  type Error = ScheduleError

  def validate(
      request: CreateDriverUnavailabilityApiRequest
  ): IO[ScheduleError, CreateDriverUnavailabilityApiRequest] =
    for {
      _ <- validateUuid(request.driverId, "Driver ID")
      _ <- validateInstant(request.fromTime, "fromTime")
      _ <- validateInstant(request.toTime, "toTime")
      _ <- validateInstantOrder(request.fromTime, request.toTime)
      _ <- validateUnavailabilityReason(request.reason)
    } yield request

private def validateUuid(value: String, fieldName: String): IO[ScheduleError, Unit] =
  ZIO
    .attempt(UUID.fromString(value))
    .orElseFail(ScheduleError.ValidationError(s"Invalid $fieldName format: $value"))
    .unit

private def validateDate(date: String): IO[ScheduleError, Unit] =
  ZIO
    .attempt(LocalDate.parse(date))
    .orElseFail(ScheduleError.ValidationError(s"Invalid date format: $date. Expected ISO format (yyyy-MM-dd)"))
    .unit

private def validateTime(time: String, fieldName: String): IO[ScheduleError, Unit] =
  ZIO
    .attempt(LocalTime.parse(time))
    .orElseFail(ScheduleError.ValidationError(s"Invalid $fieldName format: $time. Expected HH:mm format"))
    .unit

private def validateTimeOrder(startTime: String, endTime: String): IO[ScheduleError, Unit] =
  val result =
    for {
      start <- Try(LocalTime.parse(startTime)).toOption
      end   <- Try(LocalTime.parse(endTime)).toOption
    } yield start.isBefore(end)

  ZIO
    .when(result.contains(false))(
      ZIO.fail(ScheduleError.ValidationError("Start time must be before end time"))
    )
    .unit

private def validateStatus(status: String): IO[ScheduleError, Unit] =
  Try(ScheduleDayStatus.valueOf(status)) match
    case scala.util.Success(_) => ZIO.unit
    case scala.util.Failure(_) =>
      ZIO.fail(
        ScheduleError.ValidationError(
          s"Invalid status: $status. Valid values: ${ScheduleDayStatus.values.mkString(", ")}"
        )
      )

private def validateInstant(value: String, fieldName: String): IO[ScheduleError, Unit] =
  ZIO
    .attempt(Instant.parse(value))
    .orElseFail(ScheduleError.ValidationError(s"Invalid $fieldName format: $value. Expected ISO-8601 instant"))
    .unit

private def validateInstantOrder(fromStr: String, toStr: String): IO[ScheduleError, Unit] =
  val result =
    for {
      from <- Try(Instant.parse(fromStr)).toOption
      to   <- Try(Instant.parse(toStr)).toOption
    } yield from.isBefore(to)

  ZIO
    .when(result.contains(false))(
      ZIO.fail(ScheduleError.ValidationError("fromTime must be before toTime"))
    )
    .unit

private def validateUnavailabilityReason(reason: String): IO[ScheduleError, Unit] =
  Try(DriverUnavailabilityReason.valueOf(reason)) match
    case scala.util.Success(_) => ZIO.unit
    case scala.util.Failure(_) =>
      ZIO.fail(
        ScheduleError.ValidationError(
          s"Invalid reason: $reason. Valid values: ${DriverUnavailabilityReason.values.mkString(", ")}"
        )
      )
