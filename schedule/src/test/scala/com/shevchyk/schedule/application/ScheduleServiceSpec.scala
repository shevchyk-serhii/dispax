package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.repository.PersonRepository
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.repository.InMemoryScheduleDayRepository
import zio.test.*
import zio.*
import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

object ScheduleServiceSpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val testDriverId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val otherDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))

  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val otherCompanyDriver = Person(
    id = otherDriverId,
    name = "Other Driver",
    email = "other@example.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
  )

  val clientPerson = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000003")),
    name = "Client Person",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  final case class TestPersonRepository(persons: Map[PersonId, Person]) extends PersonRepository:
    override def create(person: Person): Task[Person]                   = ZIO.succeed(person)
    override def findById(id: PersonId): Task[Option[Person]]           = ZIO.succeed(persons.get(id))
    override def findByEmail(email: String): Task[Option[Person]]       = ZIO.succeed(persons.values.find(_.email == email))
    override def findByRole(role: PersonRole): Task[List[Person]]       = ZIO.succeed(persons.values.filter(_.role == role).toList)
    override def findByCompanyId(companyId: CompanyId): Task[List[Person]] =
      ZIO.succeed(persons.values.filter(_.companyId.contains(companyId)).toList)
    override def findAll(): Task[List[Person]]                          = ZIO.succeed(persons.values.toList)
    override def update(person: Person): Task[Person]                   = ZIO.succeed(person)
    override def delete(id: PersonId): Task[Unit]                       = ZIO.unit

  val testPersonRepo = TestPersonRepository(
    Map(
      testDriver.id       -> testDriver,
      otherCompanyDriver.id -> otherCompanyDriver,
      clientPerson.id     -> clientPerson
    )
  )

  val standardLayers =
    InMemoryScheduleDayRepository.layer ++ ZLayer.succeed[PersonRepository](testPersonRepo) >>> ScheduleService.layer

  val futureDate = LocalDate.now().plusDays(5)

  def spec = suite("ScheduleService")(
    suite("createScheduleDay")(
      test("happy path: creates a schedule day") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate,
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
        } yield assertTrue(
          day.driverId == testDriverId &&
          day.companyId == testCompanyId &&
          day.date == futureDate &&
          day.startTime == LocalTime.of(8, 0) &&
          day.endTime == LocalTime.of(17, 0) &&
          day.status == ScheduleDayStatus.Scheduled
        )
      }.provide(standardLayers),

      test("should fail for duplicate driver+date") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(10),
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          result <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(10),
              startTime = LocalTime.of(9, 0),
              endTime = LocalTime.of(18, 0)
            )
          ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists(_.isInstanceOf[ScheduleError.DuplicateScheduleDay])
          case _ => false
        })
      }.provide(standardLayers),

      test("should fail when driver not found") {
        val unknownDriverId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
        for {
          service <- ZIO.service[ScheduleService]
          result  <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = unknownDriverId,
              companyId = testCompanyId,
              date = futureDate,
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists(_.isInstanceOf[ScheduleError.DriverNotFound])
          case _ => false
        })
      }.provide(standardLayers),

      test("should fail when start time is after end time") {
        for {
          service <- ZIO.service[ScheduleService]
          result  <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate,
              startTime = LocalTime.of(17, 0),
              endTime = LocalTime.of(8, 0)
            )
          ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists {
              case ScheduleError.ValidationError(msg) => msg.contains("before")
              case _                                  => false
            }
          case _ => false
        })
      }.provide(standardLayers),

      test("should fail when person is not a driver") {
        for {
          service <- ZIO.service[ScheduleService]
          result  <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = clientPerson.id,
              companyId = testCompanyId,
              date = futureDate,
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists {
              case ScheduleError.ValidationError(msg) => msg.contains("not a driver")
              case _                                  => false
            }
          case _ => false
        })
      }.provide(standardLayers)
    ),

    suite("getScheduleForDate")(
      test("returns correct data for company") {
        for {
          service <- ZIO.service[ScheduleService]
          date     = futureDate.plusDays(20)
          _       <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = date,
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          days <- service.getScheduleForDate(testCompanyId, date)
        } yield assertTrue(
          days.size == 1 &&
          days.head.driverId == testDriverId
        )
      }.provide(standardLayers),

      test("company isolation — other company sees nothing") {
        for {
          service <- ZIO.service[ScheduleService]
          date     = futureDate.plusDays(21)
          _       <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = date,
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          days <- service.getScheduleForDate(otherCompanyId, date)
        } yield assertTrue(days.isEmpty)
      }.provide(standardLayers)
    ),

    suite("cancelScheduleDay")(
      test("can cancel a Scheduled day") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(30),
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          cancelled <- service.cancelScheduleDay(day.id, testCompanyId)
        } yield assertTrue(cancelled.status == ScheduleDayStatus.Cancelled)
      }.provide(standardLayers),

      test("should fail for company mismatch") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(31),
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          result <- service.cancelScheduleDay(day.id, otherCompanyId).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
          case _ => false
        })
      }.provide(standardLayers)
    ),

    suite("updateScheduleDay")(
      test("partial update — change notes only") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(40),
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          updated <- service.updateScheduleDay(
            day.id,
            UpdateScheduleDayRequest(notes = Some("Updated notes")),
            testCompanyId
          )
        } yield assertTrue(
          updated.notes.contains("Updated notes") &&
          updated.startTime == LocalTime.of(8, 0) &&
          updated.endTime == LocalTime.of(17, 0)
        )
      }.provide(standardLayers),

      test("should fail with invalid status transition") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
            CreateScheduleDayRequest(
              driverId = testDriverId,
              companyId = testCompanyId,
              date = futureDate.plusDays(41),
              startTime = LocalTime.of(8, 0),
              endTime = LocalTime.of(17, 0)
            )
          )
          // Scheduled -> Completed is not valid
          result <- service.updateScheduleDay(
            day.id,
            UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
            testCompanyId
          ).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _ => false
        })
      }.provide(standardLayers)
    )
  )
}
