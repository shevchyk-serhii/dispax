package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.{LocalDate, LocalTime}
import java.util.UUID

object ScheduleMapperSpec extends ZIOSpecDefault {

  private val driverId  = PersonId(UUID.randomUUID())
  private val companyId = CompanyId(UUID.randomUUID())
  private val date      = LocalDate.of(2026, 6, 15)
  private val startTime = LocalTime.of(8, 0)
  private val endTime   = LocalTime.of(17, 0)

  private def makeRequest(notes: Option[String] = None) = CreateScheduleDayRequest(
    driverId = driverId,
    companyId = companyId,
    date = date,
    startTime = startTime,
    endTime = endTime,
    notes = notes
  )

  def spec =
    suite("ScheduleMapper")(
      test("maps driverId and companyId correctly") {
        val day = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(day.driverId == driverId && day.companyId == companyId)
      },
      test("maps date, startTime, endTime correctly") {
        val day = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(day.date == date && day.startTime == startTime && day.endTime == endTime)
      },
      test("initialises status as Scheduled") {
        val day = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(day.status == ScheduleDayStatus.Scheduled)
      },
      test("maps notes when provided") {
        val day = ScheduleMapper.fromRequest(makeRequest(notes = Some("Morning shift")))
        assertTrue(day.notes.contains("Morning shift"))
      },
      test("notes is None when not provided") {
        val day = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(day.notes.isEmpty)
      },
      test("generates unique id for each call") {
        val d1 = ScheduleMapper.fromRequest(makeRequest())
        val d2 = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(d1.id != d2.id)
      },
      test("createdAt and updatedAt are equal on creation") {
        val day = ScheduleMapper.fromRequest(makeRequest())
        assertTrue(day.createdAt == day.updatedAt)
      }
    )
}
