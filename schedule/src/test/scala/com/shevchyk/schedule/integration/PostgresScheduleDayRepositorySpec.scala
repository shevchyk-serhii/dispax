package com.shevchyk.schedule.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.{ScheduleDay, ScheduleDayStatus}
import com.shevchyk.schedule.repository.PostgresScheduleDayRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

/**
 * Integration tests for PostgresScheduleDayRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresScheduleDayRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000010-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000010-0000-0000-0000-000000000002"))
  val driverId       = PersonId(UUID.fromString("00000020-0000-0000-0000-000000000001"))
  val otherDriverId  = PersonId(UUID.fromString("00000020-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'sched-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'sched-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Test Driver', 'sched-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherDriverId.value}, 'Other Driver', 'sched-other-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanScheduleDays(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM schedule_days".update.run.transact(xa).unit

  private def makeDay(
      id: ScheduleDayId = ScheduleDayId(UUID.randomUUID()),
      driver: PersonId = driverId,
      company: CompanyId = testCompanyId,
      date: LocalDate = LocalDate.of(2026, 6, 15),
      startTime: LocalTime = LocalTime.of(8, 0),
      endTime: LocalTime = LocalTime.of(16, 0),
      status: ScheduleDayStatus = ScheduleDayStatus.Scheduled,
      notes: Option[String] = None
  ): ScheduleDay = {
    val now = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS)
    ScheduleDay(
      id = id,
      driverId = driver,
      companyId = company,
      date = date,
      startTime = startTime,
      endTime = endTime,
      status = status,
      notes = notes,
      createdAt = now,
      updatedAt = now
    )
  }

  def spec =
    suite("PostgresScheduleDayRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanScheduleDays(xa)
          repo   = PostgresScheduleDayRepository(xa)
          day    = makeDay(notes = Some("Morning shift"))
          _     <- repo.create(day)
          found <- repo.findById(day.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == day.id,
          found.get.driverId == driverId,
          found.get.companyId == testCompanyId,
          found.get.date == day.date,
          found.get.startTime == LocalTime.of(8, 0),
          found.get.endTime == LocalTime.of(16, 0),
          found.get.status == ScheduleDayStatus.Scheduled,
          found.get.notes.contains("Morning shift")
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanScheduleDays(xa)
          repo   = PostgresScheduleDayRepository(xa)
          found <- repo.findById(ScheduleDayId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("findByDriverId returns only that driver's days") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanScheduleDays(xa)
          repo  = PostgresScheduleDayRepository(xa)
          d1    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 15))
          d2    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 16))
          d3    = makeDay(driver = otherDriverId, date = LocalDate.of(2026, 6, 15))
          _    <- repo.create(d1)
          _    <- repo.create(d2)
          _    <- repo.create(d3)
          mine <- repo.findByDriverId(driverId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.driverId == driverId),
          mine.map(_.id).toSet == Set(d1.id, d2.id)
        )
      },
      test("findByDriverAndDate returns the matching day") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanScheduleDays(xa)
          repo  = PostgresScheduleDayRepository(xa)
          d1    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 15))
          d2    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 16))
          _    <- repo.create(d1)
          _    <- repo.create(d2)
          hit  <- repo.findByDriverAndDate(driverId, LocalDate.of(2026, 6, 15))
          miss <- repo.findByDriverAndDate(driverId, LocalDate.of(2026, 6, 20))
        } yield assertTrue(
          hit.isDefined,
          hit.get.id == d1.id,
          miss.isEmpty
        )
      },
      test("findByCompanyAndDate returns all company days for that date") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanScheduleDays(xa)
          repo  = PostgresScheduleDayRepository(xa)
          d1    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 15), startTime = LocalTime.of(8, 0))
          d2    = makeDay(driver = otherDriverId, date = LocalDate.of(2026, 6, 15), startTime = LocalTime.of(10, 0))
          d3    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 16))
          _    <- repo.create(d1)
          _    <- repo.create(d2)
          _    <- repo.create(d3)
          days <- repo.findByCompanyAndDate(testCompanyId, LocalDate.of(2026, 6, 15))
        } yield assertTrue(
          days.length == 2,
          days.forall(_.companyId == testCompanyId),
          days.map(_.id).toSet == Set(d1.id, d2.id),
          days.map(_.startTime) == List(LocalTime.of(8, 0), LocalTime.of(10, 0)) // ordered by start_time ASC
        )
      },
      test("findByCompanyAndDateRange respects the inclusive range bounds") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanScheduleDays(xa)
          repo     = PostgresScheduleDayRepository(xa)
          before   = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 10))
          fromDay  = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 15))
          midDay   = makeDay(driver = otherDriverId, date = LocalDate.of(2026, 6, 17))
          toDay    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 20))
          after    = makeDay(driver = driverId, date = LocalDate.of(2026, 6, 25))
          _       <- repo.create(before)
          _       <- repo.create(fromDay)
          _       <- repo.create(midDay)
          _       <- repo.create(toDay)
          _       <- repo.create(after)
          inRange <- repo.findByCompanyAndDateRange(
                       testCompanyId,
                       LocalDate.of(2026, 6, 15),
                       LocalDate.of(2026, 6, 20)
                     )
        } yield assertTrue(
          inRange.map(_.id).toSet == Set(fromDay.id, midDay.id, toDay.id),
          inRange.map(_.date) == List( // ordered by date ASC
            LocalDate.of(2026, 6, 15),
            LocalDate.of(2026, 6, 17),
            LocalDate.of(2026, 6, 20)
          )
        )
      },
      test("findByCompanyAndDate excludes other companies' days") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanScheduleDays(xa)
          repo   = PostgresScheduleDayRepository(xa)
          mine   = makeDay(company = testCompanyId, driver = driverId, date = LocalDate.of(2026, 6, 15))
          _     <- repo.create(mine)
          other <- repo.findByCompanyAndDate(otherCompanyId, LocalDate.of(2026, 6, 15))
        } yield assertTrue(other.isEmpty)
      },
      test("update changes mutable fields") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanScheduleDays(xa)
          repo    = PostgresScheduleDayRepository(xa)
          day     = makeDay(notes = Some("original"))
          _      <- repo.create(day)
          updated = day.copy(
                      startTime = LocalTime.of(9, 30),
                      endTime = LocalTime.of(17, 30),
                      status = ScheduleDayStatus.Active,
                      notes = Some("updated")
                    )
          _      <- repo.update(updated)
          found  <- repo.findById(day.id)
        } yield assertTrue(
          found.get.startTime == LocalTime.of(9, 30),
          found.get.endTime == LocalTime.of(17, 30),
          found.get.status == ScheduleDayStatus.Active,
          found.get.notes.contains("updated")
        )
      },
      test("delete removes the schedule day") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanScheduleDays(xa)
          repo   = PostgresScheduleDayRepository(xa)
          day    = makeDay()
          _     <- repo.create(day)
          _     <- repo.delete(day.id)
          found <- repo.findById(day.id)
        } yield assertTrue(found.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
