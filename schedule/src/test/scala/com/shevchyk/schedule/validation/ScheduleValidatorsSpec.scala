package com.shevchyk.schedule.validation

import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.*
import zio.test.*
import zio.*
import java.util.UUID

object ScheduleValidatorsSpec extends ZIOSpecDefault {

  val validDriverId = UUID.randomUUID().toString
  val validDate     = "2026-06-15"
  val validStart    = "08:00"
  val validEnd      = "17:00"

  def validCreateRequest(
      driverId: String = validDriverId,
      date: String = validDate,
      startTime: String = validStart,
      endTime: String = validEnd
  ) = CreateScheduleDayApiRequest(
    driverId = driverId,
    date = date,
    startTime = startTime,
    endTime = endTime
  )

  def suite_createScheduleDay = suite("CreateScheduleDayApiRequest validator")(
    test("accepts valid request") {
      val req = validCreateRequest()
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("rejects invalid driver UUID") {
      val req = validCreateRequest(driverId = "not-a-uuid")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Driver ID"))
      }
    },
    test("rejects invalid date format") {
      val req = validCreateRequest(date = "15.06.2026")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Invalid date"))
      }
    },
    test("rejects date with wrong separator") {
      val req = validCreateRequest(date = "2026/06/15")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects invalid month") {
      val req = validCreateRequest(date = "2026-13-01")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects invalid start time format") {
      val req = validCreateRequest(startTime = "8:00 AM")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Start time"))
      }
    },
    test("rejects invalid end time format") {
      val req = validCreateRequest(endTime = "5pm")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("End time"))
      }
    },
    test("rejects start time equal to end time") {
      val req = validCreateRequest(startTime = "10:00", endTime = "10:00")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Start time must be before end time"))
      }
    },
    test("rejects start time after end time") {
      val req = validCreateRequest(startTime = "18:00", endTime = "09:00")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Start time must be before end time"))
      }
    },
    test("accepts midnight crossing not detected (23:00 to 07:00 is before)") {
      val req = validCreateRequest(startTime = "00:00", endTime = "23:59")
      summon[Validator[CreateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    }
  )

  def suite_createScheduleBatch = suite("CreateScheduleBatchApiRequest validator")(
    test("accepts valid batch request") {
      val req = CreateScheduleBatchApiRequest(
        driverId = validDriverId,
        days = List(
          ScheduleBatchDayApiRequest(date = "2026-06-15", startTime = "08:00", endTime = "16:00"),
          ScheduleBatchDayApiRequest(date = "2026-06-16", startTime = "09:00", endTime = "17:00")
        )
      )
      summon[Validator[CreateScheduleBatchApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("rejects empty days list") {
      val req = CreateScheduleBatchApiRequest(driverId = validDriverId, days = List.empty)
      summon[Validator[CreateScheduleBatchApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("At least one day"))
      }
    },
    test("rejects invalid driver UUID") {
      val req = CreateScheduleBatchApiRequest(
        driverId = "bad",
        days = List(ScheduleBatchDayApiRequest(date = validDate, startTime = validStart, endTime = validEnd))
      )
      summon[Validator[CreateScheduleBatchApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects batch with invalid date in one day") {
      val req = CreateScheduleBatchApiRequest(
        driverId = validDriverId,
        days = List(ScheduleBatchDayApiRequest(date = "bad-date", startTime = validStart, endTime = validEnd))
      )
      summon[Validator[CreateScheduleBatchApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects batch with bad time order in one day") {
      val req = CreateScheduleBatchApiRequest(
        driverId = validDriverId,
        days = List(ScheduleBatchDayApiRequest(date = validDate, startTime = "20:00", endTime = "08:00"))
      )
      summon[Validator[CreateScheduleBatchApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Start time must be before end time"))
      }
    }
  )

  def suite_updateScheduleDay = suite("UpdateScheduleDayApiRequest validator")(
    test("accepts empty update (all None)") {
      val req = UpdateScheduleDayApiRequest()
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("accepts valid start time only") {
      val req = UpdateScheduleDayApiRequest(startTime = Some("09:30"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("rejects invalid start time") {
      val req = UpdateScheduleDayApiRequest(startTime = Some("9am"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects invalid end time") {
      val req = UpdateScheduleDayApiRequest(endTime = Some("not-time"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.isInstanceOf[ScheduleError.ValidationError])
      }
    },
    test("rejects start after end when both provided") {
      val req = UpdateScheduleDayApiRequest(startTime = Some("20:00"), endTime = Some("10:00"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Start time must be before end time"))
      }
    },
    test("skips time order check when only start provided") {
      val req = UpdateScheduleDayApiRequest(startTime = Some("22:00"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("skips time order check when only end provided") {
      val req = UpdateScheduleDayApiRequest(endTime = Some("06:00"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("accepts valid status Scheduled") {
      val req = UpdateScheduleDayApiRequest(status = Some("Scheduled"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("accepts valid status Active") {
      val req = UpdateScheduleDayApiRequest(status = Some("Active"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("accepts valid status Completed") {
      val req = UpdateScheduleDayApiRequest(status = Some("Completed"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("accepts valid status Cancelled") {
      val req = UpdateScheduleDayApiRequest(status = Some("Cancelled"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).map(r => assertTrue(r == req))
    },
    test("rejects invalid status") {
      val req = UpdateScheduleDayApiRequest(status = Some("UNKNOWN"))
      summon[Validator[UpdateScheduleDayApiRequest]].validate(req).flip.map { err =>
        assertTrue(err.asInstanceOf[ScheduleError.ValidationError].message.contains("Invalid status"))
      }
    }
  )

  def spec = suite("ScheduleValidators")(
    suite_createScheduleDay,
    suite_createScheduleBatch,
    suite_updateScheduleDay
  )
}
