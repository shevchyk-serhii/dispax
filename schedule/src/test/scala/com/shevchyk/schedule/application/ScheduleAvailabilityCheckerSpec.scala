package com.shevchyk.schedule.application

import com.shevchyk.core.domain.{CompanyId, DriverUnavailabilityId, PersonId}
import com.shevchyk.schedule.domain.{DriverUnavailability, DriverUnavailabilityReason}
import com.shevchyk.schedule.repository.InMemoryDriverUnavailabilityRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests (in-memory double) for `ScheduleAvailabilityChecker` — the schedule-module implementation of the core port
 * `DriverAvailabilityChecker` that gates driver assignment. Covers the overlap window semantics (half-open intersection
 * via the repository), the tenant/driver filters and the domain → `UnavailabilitySlot` mapping (times + reason string)
 * that RideService renders into the assignment-conflict message.
 */
object ScheduleAvailabilityCheckerSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000a1"))
  private val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000b1"))
  private val driver1  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  private val driver2  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  private val t10 = Instant.parse("2026-07-06T10:00:00Z")
  private val t11 = Instant.parse("2026-07-06T11:00:00Z")
  private val t12 = Instant.parse("2026-07-06T12:00:00Z")
  private val t13 = Instant.parse("2026-07-06T13:00:00Z")
  private val t14 = Instant.parse("2026-07-06T14:00:00Z")

  private def unavailability(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant,
      reason: DriverUnavailabilityReason = DriverUnavailabilityReason.Vacation
  ): DriverUnavailability = DriverUnavailability(
    id = DriverUnavailabilityId(UUID.randomUUID()),
    driverId = driverId,
    companyId = companyId,
    fromTime = from,
    toTime = to,
    reason = reason,
    note = None,
    createdAt = Instant.parse("2026-07-01T00:00:00Z")
  )

  private def makeChecker(slots: DriverUnavailability*): Task[ScheduleAvailabilityChecker] =
    val repo = new InMemoryDriverUnavailabilityRepository
    ZIO.foreachDiscard(slots)(repo.create).as(ScheduleAvailabilityChecker(repo))

  def spec =
    suite("ScheduleAvailabilityChecker (core port implementation)")(
      test("maps an overlapping unavailability to an UnavailabilitySlot with times and reason string") {
        for {
          checker <- makeChecker(
                       unavailability(driver1, companyA, t11, t13, DriverUnavailabilityReason.Lunch)
                     )
          slots   <- checker.overlappingUnavailability(driver1, companyA, t12, t14)
        } yield assertTrue(
          slots.size == 1,
          slots.head.from == t11,
          slots.head.to == t13,
          slots.head.reason == "Lunch"
        )
      },
      test("no overlap: a window strictly after the unavailability yields no slots") {
        for {
          checker <- makeChecker(unavailability(driver1, companyA, t10, t11))
          slots   <- checker.overlappingUnavailability(driver1, companyA, t12, t14)
        } yield assertTrue(slots.isEmpty)
      },
      test("touching boundaries do not overlap (unavailability ends exactly when the window starts)") {
        for {
          checker <- makeChecker(unavailability(driver1, companyA, t10, t12))
          slots   <- checker.overlappingUnavailability(driver1, companyA, t12, t14)
        } yield assertTrue(slots.isEmpty)
      },
      test("window fully inside a longer unavailability overlaps") {
        for {
          checker <- makeChecker(unavailability(driver1, companyA, t10, t14))
          slots   <- checker.overlappingUnavailability(driver1, companyA, t11, t12)
        } yield assertTrue(slots.size == 1)
      },
      test("another driver's unavailability is not returned") {
        for {
          checker <- makeChecker(unavailability(driver2, companyA, t11, t13))
          slots   <- checker.overlappingUnavailability(driver1, companyA, t10, t14)
        } yield assertTrue(slots.isEmpty)
      },
      test("[TENANT ISOLATION] same driver id under another company is not returned") {
        for {
          checker <- makeChecker(unavailability(driver1, companyB, t11, t13))
          slots   <- checker.overlappingUnavailability(driver1, companyA, t10, t14)
        } yield assertTrue(slots.isEmpty)
      },
      test("multiple overlapping unavailabilities are all mapped, ordered by start time") {
        for {
          checker <- makeChecker(
                       unavailability(driver1, companyA, t12, t13, DriverUnavailabilityReason.Personal),
                       unavailability(driver1, companyA, t10, t11, DriverUnavailabilityReason.Lunch)
                     )
          slots   <- checker.overlappingUnavailability(driver1, companyA, t10, t14)
        } yield assertTrue(
          slots.map(_.reason) == List("Lunch", "Personal")
        )
      }
    )
