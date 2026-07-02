package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{PersonRepository, InMemoryPersonRepository}
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.repository.{
  InMemoryDriverUnavailabilityRepository,
  InMemoryScheduleDayRepository,
  InMemoryDriverScheduleVisibilityRepository
}
import zio.test.*
import zio.*
import java.time.{LocalDate, LocalTime}
import java.util.UUID

object ScheduleServiceStatusSpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))

  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val testPersonRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer {
    for {
      repo <- ZIO.succeed(new InMemoryPersonRepository)
      _    <- repo.create(testDriver).orDie
    } yield repo
  }

  val standardLayers =
    InMemoryScheduleDayRepository.layer ++
      InMemoryDriverScheduleVisibilityRepository.layer ++
      InMemoryDriverUnavailabilityRepository.layer ++
      testPersonRepoLayer >>>
      ScheduleService.layer

  val futureDate = LocalDate.now().plusDays(5)

  private def createAndTransition(
      service: ScheduleService,
      date: LocalDate,
      targetStatus: ScheduleDayStatus
  ) =
    for {
      day     <- service.createScheduleDay(
                   CreateScheduleDayRequest(
                     driverId = testDriverId,
                     companyId = testCompanyId,
                     date = date,
                     startTime = LocalTime.of(8, 0),
                     endTime = LocalTime.of(17, 0)
                   )
                 )
      updated <- service.updateScheduleDay(
                   day.id,
                   UpdateScheduleDayRequest(status = Some(targetStatus)),
                   testCompanyId
                 )
    } yield updated

  def spec =
    suite("ScheduleService status transitions")(
      test("Scheduled -> Active is valid") {
        for {
          service <- ZIO.service[ScheduleService]
          updated <- createAndTransition(service, futureDate.plusDays(200), ScheduleDayStatus.Active)
        } yield assertTrue(updated.status == ScheduleDayStatus.Active)
      }.provide(standardLayers),
      test("Active -> Completed is valid") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(201), ScheduleDayStatus.Active)
          completed <- service.updateScheduleDay(
                         active.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
        } yield assertTrue(completed.status == ScheduleDayStatus.Completed)
      }.provide(standardLayers),
      test("Active -> Cancelled is valid") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(202), ScheduleDayStatus.Active)
          cancelled <- service.cancelScheduleDay(active.id, testCompanyId)
        } yield assertTrue(cancelled.status == ScheduleDayStatus.Cancelled)
      }.provide(standardLayers),
      test("Completed -> Active is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(203), ScheduleDayStatus.Active)
          completed <- service.updateScheduleDay(
                         active.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
          result    <-
            service
              .updateScheduleDay(
                completed.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Active)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Cancelled -> Active is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          day       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(204),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
          cancelled <- service.cancelScheduleDay(day.id, testCompanyId)
          result    <-
            service
              .updateScheduleDay(
                cancelled.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Active)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Completed -> Scheduled is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(205), ScheduleDayStatus.Active)
          completed <- service.updateScheduleDay(
                         active.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
          result    <-
            service
              .updateScheduleDay(
                completed.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Scheduled)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Completed -> Cancelled is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(206), ScheduleDayStatus.Active)
          completed <- service.updateScheduleDay(
                         active.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
          result    <- service.cancelScheduleDay(completed.id, testCompanyId).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Cancelled -> Scheduled is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          day       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(207),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
          cancelled <- service.cancelScheduleDay(day.id, testCompanyId)
          result    <-
            service
              .updateScheduleDay(
                cancelled.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Scheduled)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Cancelled -> Completed is invalid") {
        for {
          service   <- ZIO.service[ScheduleService]
          day       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(208),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
          cancelled <- service.cancelScheduleDay(day.id, testCompanyId)
          result    <-
            service
              .updateScheduleDay(
                cancelled.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Completed -> Completed self-transition is allowed") {
        for {
          service   <- ZIO.service[ScheduleService]
          active    <- createAndTransition(service, futureDate.plusDays(209), ScheduleDayStatus.Active)
          completed <- service.updateScheduleDay(
                         active.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
          result    <- service.updateScheduleDay(
                         completed.id,
                         UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                         testCompanyId
                       )
        } yield assertTrue(result.status == ScheduleDayStatus.Completed)
      }.provide(standardLayers),
      test("Cancelled -> Cancelled self-transition is allowed") {
        for {
          service   <- ZIO.service[ScheduleService]
          day       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(210),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
          cancelled <- service.cancelScheduleDay(day.id, testCompanyId)
          result    <- service.cancelScheduleDay(cancelled.id, testCompanyId)
        } yield assertTrue(result.status == ScheduleDayStatus.Cancelled)
      }.provide(standardLayers),
      // ── Mutant 3: explicit invalid transitions ─────────────────────────────
      // These catch mutations that incorrectly mark Active→Scheduled or
      // Scheduled→Completed as valid by adding them as `=> true` cases.
      test("Active -> Scheduled is invalid") {
        for {
          service <- ZIO.service[ScheduleService]
          active  <- createAndTransition(service, futureDate.plusDays(211), ScheduleDayStatus.Active)
          result  <-
            service
              .updateScheduleDay(
                active.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Scheduled)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      test("Scheduled -> Completed is invalid") {
        for {
          service <- ZIO.service[ScheduleService]
          day     <- service.createScheduleDay(
                       CreateScheduleDayRequest(
                         driverId = testDriverId,
                         companyId = testCompanyId,
                         date = futureDate.plusDays(212),
                         startTime = LocalTime.of(8, 0),
                         endTime = LocalTime.of(17, 0)
                       )
                     )
          result  <-
            service
              .updateScheduleDay(
                day.id,
                UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                testCompanyId
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers)
    )
}
