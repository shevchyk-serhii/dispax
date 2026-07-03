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

object ScheduleServiceSpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val testDriverId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val otherDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))

  val testDriverId2     = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000010"))
  val pureDispatcherId2 = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000020"))

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

  // Dispatcher who also holds the Driver role.
  val dispatcherDriver = Person(
    id = testDriverId2,
    name = "Dispatcher Driver",
    email = "dispdrv@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId),
    roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
  )

  // Pure dispatcher — only the Dispatcher role.
  val pureDispatcher = Person(
    id = pureDispatcherId2,
    name = "Pure Dispatcher",
    email = "puredisp2@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId),
    roles = Set(PersonRole.Dispatcher)
  )

  val testPersonRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer {
    for {
      repo <- ZIO.succeed(new InMemoryPersonRepository)
      _    <- repo.create(testDriver).orDie
      _    <- repo.create(otherCompanyDriver).orDie
      _    <- repo.create(clientPerson).orDie
      _    <- repo.create(dispatcherDriver).orDie
      _    <- repo.create(pureDispatcher).orDie
    } yield repo
  }

  val standardLayers =
    InMemoryScheduleDayRepository.layer ++
      InMemoryDriverScheduleVisibilityRepository.layer ++
      InMemoryDriverUnavailabilityRepository.layer ++
      testPersonRepoLayer >>>
      ScheduleService.layer

  val futureDate = LocalDate.now().plusDays(5)

  def spec =
    suite("ScheduleService")(
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
        test("should fail for overlapping shift on the same driver+date") {
          // Two shifts on the same date that overlap (08:00–17:00 then 09:00–18:00).
          // The application-layer overlap check fires before the repository duplicate guard.
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
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = testDriverId,
                    companyId = testCompanyId,
                    date = futureDate.plusDays(10),
                    startTime = LocalTime.of(9, 0),
                    endTime = LocalTime.of(18, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.OverlapConflict])
            case _                   => false
          })
        }.provide(standardLayers),
        test("overlap check does not false-positive on a different date") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(200),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            // Same overlapping clock times, but a different date — must succeed.
            day     <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(201),
                           startTime = LocalTime.of(9, 0),
                           endTime = LocalTime.of(18, 0)
                         )
                       )
          } yield assertTrue(day.date == futureDate.plusDays(201))
        }.provide(standardLayers),
        test("overlap check does not false-positive across drivers") {
          for {
            service <- ZIO.service[ScheduleService]
            date     = futureDate.plusDays(202)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            // A different driver with overlapping clock times on the same date — must succeed.
            day     <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId2,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(9, 0),
                           endTime = LocalTime.of(18, 0)
                         )
                       )
          } yield assertTrue(day.driverId == testDriverId2)
        }.provide(standardLayers),
        test("back-to-back (touching) shifts on the same date are both created") {
          // 09:00–12:00 and 12:00–15:00 share only the boundary point, so the half-open
          // interval check must NOT flag them, and (since the one-shift-per-date DB
          // constraint was relaxed) the second shift is persisted alongside the first.
          for {
            service <- ZIO.service[ScheduleService]
            date     = futureDate.plusDays(203)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(9, 0),
                           endTime = LocalTime.of(12, 0)
                         )
                       )
            second  <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(12, 0),
                           endTime = LocalTime.of(15, 0)
                         )
                       )
            allDays <- service.getDriverSchedule(testDriverId, testCompanyId)
          } yield assertTrue(
            second.startTime == LocalTime.of(12, 0),
            allDays.count(_.date == date) == 2
          )
        }.provide(standardLayers),
        test("cancelled shift frees its day for a new shift") {
          // Cancelling is a soft-delete (row stays with status Cancelled); a new shift with
          // the same times on the same day must be creatable afterwards.
          for {
            service   <- ZIO.service[ScheduleService]
            date       = futureDate.plusDays(204)
            first     <- service.createScheduleDay(
                           CreateScheduleDayRequest(
                             driverId = testDriverId,
                             companyId = testCompanyId,
                             date = date,
                             startTime = LocalTime.of(8, 0),
                             endTime = LocalTime.of(16, 0)
                           )
                         )
            _         <- service.cancelScheduleDay(first.id, testCompanyId)
            recreated <- service.createScheduleDay(
                           CreateScheduleDayRequest(
                             driverId = testDriverId,
                             companyId = testCompanyId,
                             date = date,
                             startTime = LocalTime.of(8, 0),
                             endTime = LocalTime.of(16, 0)
                           )
                         )
          } yield assertTrue(
            recreated.date == date,
            recreated.status == ScheduleDayStatus.Scheduled
          )
        }.provide(standardLayers),
        test("should fail when driver not found") {
          val unknownDriverId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = unknownDriverId,
                    companyId = testCompanyId,
                    date = futureDate,
                    startTime = LocalTime.of(8, 0),
                    endTime = LocalTime.of(17, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.DriverNotFound])
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when start time is after end time") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = testDriverId,
                    companyId = testCompanyId,
                    date = futureDate,
                    startTime = LocalTime.of(17, 0),
                    endTime = LocalTime.of(8, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when person is not a driver") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = clientPerson.id,
                    companyId = testCompanyId,
                    date = futureDate,
                    startTime = LocalTime.of(8, 0),
                    endTime = LocalTime.of(17, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("not a driver")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        // ── multi-role (dispatcher-can-drive) ──────────────────────────────
        test("dispatcher-driver (roles={Dispatcher,Driver}) can create schedule day") {
          for {
            service <- ZIO.service[ScheduleService]
            day     <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId2,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(20),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(16, 0)
                         )
                       )
          } yield assertTrue(
            day.driverId == testDriverId2 &&
              day.status == ScheduleDayStatus.Scheduled
          )
        }.provide(standardLayers),
        test("pure dispatcher (roles={Dispatcher}) cannot create schedule day") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = pureDispatcherId2,
                    companyId = testCompanyId,
                    date = futureDate.plusDays(21),
                    startTime = LocalTime.of(8, 0),
                    endTime = LocalTime.of(16, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("not a driver")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when driver belongs to a different company (cross-company attempt)") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = otherDriverId,
                    companyId = testCompanyId,
                    date = futureDate.plusDays(22),
                    startTime = LocalTime.of(8, 0),
                    endTime = LocalTime.of(17, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when driver has no company (companyId = None)") {
          val noCompanyDriverId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = noCompanyDriverId,
                    companyId = testCompanyId,
                    date = futureDate.plusDays(23),
                    startTime = LocalTime.of(8, 0),
                    endTime = LocalTime.of(17, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
            case _                   => false
          })
        }.provide(
          InMemoryScheduleDayRepository.layer ++
            InMemoryDriverScheduleVisibilityRepository.layer ++
            InMemoryDriverUnavailabilityRepository.layer ++
            ZLayer {
              for {
                repo <- ZIO.succeed(new InMemoryPersonRepository)
                _    <- repo.create(testDriver).orDie
                _    <-
                  repo
                    .create(
                      Person(
                        id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099")),
                        name = "No Company Driver",
                        email = "nocompany@example.com",
                        role = PersonRole.Driver,
                        companyId = None
                      )
                    )
                    .orDie
              } yield repo
            } >>>
            ScheduleService.layer
        ),
        test("start time equal to end time fails validation") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createScheduleDay(
                  CreateScheduleDayRequest(
                    driverId = testDriverId,
                    companyId = testCompanyId,
                    date = futureDate.plusDays(24),
                    startTime = LocalTime.of(9, 0),
                    endTime = LocalTime.of(9, 0)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("createBatch")(
        test("creates multiple schedule days") {
          for {
            service <- ZIO.service[ScheduleService]
            days    <- service.createBatch(
                         CreateScheduleBatchRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           days = List(
                             CreateScheduleBatchDay(
                               futureDate.plusDays(80),
                               LocalTime.of(8, 0),
                               LocalTime.of(12, 0),
                               None
                             ),
                             CreateScheduleBatchDay(
                               futureDate.plusDays(81),
                               LocalTime.of(9, 0),
                               LocalTime.of(17, 0),
                               Some("Afternoon shift")
                             )
                           )
                         )
                       )
          } yield assertTrue(
            days.size == 2,
            days.head.date == futureDate.plusDays(80),
            days(1).notes.contains("Afternoon shift")
          )
        }.provide(standardLayers),
        test("fails if any day has invalid time range") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createBatch(
                  CreateScheduleBatchRequest(
                    driverId = testDriverId,
                    companyId = testCompanyId,
                    days = List(
                      CreateScheduleBatchDay(futureDate.plusDays(82), LocalTime.of(8, 0), LocalTime.of(12, 0), None),
                      CreateScheduleBatchDay(
                        futureDate.plusDays(83),
                        LocalTime.of(17, 0),
                        LocalTime.of(8, 0),
                        None
                      ) // invalid
                    )
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when batch driver belongs to a different company") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createBatch(
                  CreateScheduleBatchRequest(
                    driverId = otherDriverId,
                    companyId = testCompanyId,
                    days = List(
                      CreateScheduleBatchDay(futureDate.plusDays(84), LocalTime.of(8, 0), LocalTime.of(17, 0), None)
                    )
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
            case _                   => false
          })
        }.provide(standardLayers),
        test("partial failure: first day persists when second day overlaps an existing shift (non-atomic semantics)") {
          // BUG: createBatch is not atomic — day 1 persists even when day 2 fails.
          // Fix tracked as a separate run: wrap createBatch in a transactional boundary or
          // collect all records first and emit them in a single multi-row INSERT.
          for {
            service     <- ZIO.service[ScheduleService]
            existingDate = futureDate.plusDays(150)
            // Pre-create a day so that the second batch entry triggers OverlapConflict
            _           <- service.createScheduleDay(
                             CreateScheduleDayRequest(
                               driverId = testDriverId,
                               companyId = testCompanyId,
                               date = existingDate,
                               startTime = LocalTime.of(8, 0),
                               endTime = LocalTime.of(12, 0)
                             )
                           )
            // Batch: batchNewDate (new) succeeds first, then existingDate overlap causes failure
            batchNewDate = futureDate.plusDays(151)
            batchResult <-
              service
                .createBatch(
                  CreateScheduleBatchRequest(
                    driverId = testDriverId,
                    companyId = testCompanyId,
                    days = List(
                      CreateScheduleBatchDay(batchNewDate, LocalTime.of(8, 0), LocalTime.of(12, 0), None),
                      // Overlaps the pre-created 08:00–12:00 shift on the same date.
                      CreateScheduleBatchDay(
                        existingDate,
                        LocalTime.of(10, 0),
                        LocalTime.of(17, 0),
                        None
                      )
                    )
                  )
                )
                .exit
            // Verify via the service (not the raw repo) — both approaches work here
            allDays     <- service.getDriverSchedule(testDriverId, testCompanyId)
          } yield assertTrue(
            // The batch must fail with OverlapConflict
            (batchResult match {
              case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.OverlapConflict])
              case _                   => false
            }) &&
              // BUG: batchNewDate was already persisted by the first iteration despite the batch failure
              allDays.exists(_.date == batchNewDate)
          )
        }.provide(standardLayers)
      ),
      suite("getScheduleDay")(
        test("returns existing schedule day by ID") {
          for {
            service <- ZIO.service[ScheduleService]
            created <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(90),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            found   <- service.getScheduleDay(created.id)
          } yield assertTrue(
            found.id == created.id,
            found.driverId == testDriverId
          )
        }.provide(standardLayers),
        test("fails for non-existent ID") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <- service.getScheduleDay(ScheduleDayId.generate()).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.ScheduleDayNotFound])
            case _                   => false
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
            days    <- service.getScheduleForDate(testCompanyId, date)
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
            days    <- service.getScheduleForDate(otherCompanyId, date)
          } yield assertTrue(days.isEmpty)
        }.provide(standardLayers)
      ),
      suite("cancelScheduleDay")(
        test("can cancel a Scheduled day") {
          for {
            service   <- ZIO.service[ScheduleService]
            day       <- service.createScheduleDay(
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
            result  <- service.cancelScheduleDay(day.id, otherCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
            case _                   => false
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
            result  <-
              service
                .updateScheduleDay(
                  day.id,
                  UpdateScheduleDayRequest(status = Some(ScheduleDayStatus.Completed)),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists(_.isInstanceOf[ScheduleError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("update to an inverted time range is rejected") {
          for {
            service <- ZIO.service[ScheduleService]
            day     <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(42),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            // new startTime (18:00) is after the existing endTime (17:00)
            result  <-
              service
                .updateScheduleDay(
                  day.id,
                  UpdateScheduleDayRequest(startTime = Some(LocalTime.of(18, 0))),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("update under another company is rejected (tenant isolation)") {
          for {
            service <- ZIO.service[ScheduleService]
            day     <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = futureDate.plusDays(43),
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            result  <-
              service
                .updateScheduleDay(
                  day.id,
                  UpdateScheduleDayRequest(notes = Some("hijack")),
                  otherCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("getScheduleForDateRange")(
        test("returns days in range") {
          for {
            service <- ZIO.service[ScheduleService]
            date1    = futureDate.plusDays(50)
            date2    = futureDate.plusDays(51)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date1,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date2,
                           startTime = LocalTime.of(9, 0),
                           endTime = LocalTime.of(18, 0)
                         )
                       )
            days    <- service.getScheduleForDateRange(testCompanyId, date1, date2)
          } yield assertTrue(days.size == 2)
        }.provide(standardLayers),
        test("empty for no schedules in range") {
          for {
            service <- ZIO.service[ScheduleService]
            farDate  = futureDate.plusDays(100)
            days    <- service.getScheduleForDateRange(testCompanyId, farDate, farDate.plusDays(1))
          } yield assertTrue(days.isEmpty)
        }.provide(standardLayers),
        test("returns empty list when from > to (no error, silent empty result)") {
          for {
            service <- ZIO.service[ScheduleService]
            days    <- service.getScheduleForDateRange(
                         testCompanyId,
                         futureDate.plusDays(120),
                         futureDate.plusDays(110)
                       )
          } yield assertTrue(days.isEmpty)
        }.provide(standardLayers),
        test("single-day range (from == to) returns that day") {
          for {
            service <- ZIO.service[ScheduleService]
            dayDate  = futureDate.plusDays(130)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = dayDate,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            days    <- service.getScheduleForDateRange(testCompanyId, dayDate, dayDate)
          } yield assertTrue(days.size == 1 && days.head.date == dayDate)
        }.provide(standardLayers)
      ),
      suite("getDriverSchedule")(
        test("returns driver's days") {
          for {
            service <- ZIO.service[ScheduleService]
            date     = futureDate.plusDays(60)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            days    <- service.getDriverSchedule(testDriverId, testCompanyId)
          } yield assertTrue(
            days.nonEmpty &&
              days.forall(_.driverId == testDriverId)
          )
        }.provide(standardLayers),
        test("respects company filter") {
          for {
            service <- ZIO.service[ScheduleService]
            date     = futureDate.plusDays(70)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = otherDriverId,
                           companyId = otherCompanyId,
                           date = date,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            days    <- service.getDriverSchedule(otherDriverId, testCompanyId)
          } yield assertTrue(days.isEmpty)
        }.provide(standardLayers),
        // ── Mutant 1: tenant-filter guard ──────────────────────────────────────
        // Verifies that removing `.filter(_.companyId == companyId)` is caught:
        // a schedule created for testDriverId under testCompanyId must NOT be
        // visible when the same driverId is queried with otherCompanyId.
        test("tenant isolation: own-company schedule is invisible to other company") {
          for {
            service <- ZIO.service[ScheduleService]
            date     = futureDate.plusDays(71)
            _       <- service.createScheduleDay(
                         CreateScheduleDayRequest(
                           driverId = testDriverId,
                           companyId = testCompanyId,
                           date = date,
                           startTime = LocalTime.of(8, 0),
                           endTime = LocalTime.of(17, 0)
                         )
                       )
            // Same driverId, but queried under the OTHER company — must return nothing
            days    <- service.getDriverSchedule(testDriverId, otherCompanyId)
          } yield assertTrue(days.isEmpty)
        }.provide(standardLayers)
      )
    )
}
