package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.domain.RepositoryExtensions.*
import com.shevchyk.schedule.repository.ScheduleDayRepository
import com.shevchyk.core.repository.PersonRepository
import zio.*
import java.time.{Instant, LocalDate}

trait ScheduleService:
  def createScheduleDay(req: CreateScheduleDayRequest): IO[ScheduleError, ScheduleDay]
  def createBatch(req: CreateScheduleBatchRequest): IO[ScheduleError, List[ScheduleDay]]
  def getScheduleDay(id: ScheduleDayId): IO[ScheduleError, ScheduleDay]
  def getDriverSchedule(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, List[ScheduleDay]]
  def getScheduleForDate(companyId: CompanyId, date: LocalDate): IO[ScheduleError, List[ScheduleDay]]

  def getScheduleForDateRange(
      companyId: CompanyId,
      from: LocalDate,
      to: LocalDate
  ): IO[ScheduleError, List[ScheduleDay]]

  def updateScheduleDay(
      id: ScheduleDayId,
      req: UpdateScheduleDayRequest,
      companyId: CompanyId
  ): IO[ScheduleError, ScheduleDay]
  def cancelScheduleDay(id: ScheduleDayId, companyId: CompanyId): IO[ScheduleError, ScheduleDay]

class ScheduleServiceImpl(
    scheduleDayRepository: ScheduleDayRepository,
    personRepository: PersonRepository
) extends ScheduleService:

  def createScheduleDay(req: CreateScheduleDayRequest): IO[ScheduleError, ScheduleDay] =
    for {
      _ <- validateTimeRange(req.startTime, req.endTime)
      _ <- validateDriverBelongsToCompany(req.driverId, req.companyId)

      scheduleDay = ScheduleMapper.fromRequest(req)
      persisted  <- scheduleDayRepository.create(scheduleDay).mapError {
                      case e: ScheduleError => e
                      case ex               => ScheduleError.DatabaseError(ex)
                    }
    } yield persisted

  def createBatch(req: CreateScheduleBatchRequest): IO[ScheduleError, List[ScheduleDay]] =
    for {
      _       <- validateDriverBelongsToCompany(req.driverId, req.companyId)
      results <-
        ZIO.foreach(req.days) { day =>
          createScheduleDay(
            CreateScheduleDayRequest(
              driverId = req.driverId,
              companyId = req.companyId,
              date = day.date,
              startTime = day.startTime,
              endTime = day.endTime,
              notes = day.notes
            )
          )
        }
    } yield results

  def getScheduleDay(id: ScheduleDayId): IO[ScheduleError, ScheduleDay] = scheduleDayRepository
    .findById(id)
    .mapDatabaseError
    .flatMap {
      case Some(day) => ZIO.succeed(day)
      case None      => ZIO.fail(ScheduleError.ScheduleDayNotFound(id))
    }

  def getDriverSchedule(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, List[ScheduleDay]] =
    scheduleDayRepository
      .findByDriverId(driverId)
      .mapDatabaseError
      .map(_.filter(_.companyId == companyId))

  def getScheduleForDate(companyId: CompanyId, date: LocalDate): IO[ScheduleError, List[ScheduleDay]] =
    scheduleDayRepository
      .findByCompanyAndDate(companyId, date)
      .mapDatabaseError

  def getScheduleForDateRange(
      companyId: CompanyId,
      from: LocalDate,
      to: LocalDate
  ): IO[ScheduleError, List[ScheduleDay]] =
    scheduleDayRepository
      .findByCompanyAndDateRange(companyId, from, to)
      .mapDatabaseError

  def updateScheduleDay(
      id: ScheduleDayId,
      req: UpdateScheduleDayRequest,
      companyId: CompanyId
  ): IO[ScheduleError, ScheduleDay] =
    for {
      existing <- getScheduleDay(id)
      _        <- validateCompanyMatch(existing.companyId, companyId)

      newStartTime = req.startTime.getOrElse(existing.startTime)
      newEndTime   = req.endTime.getOrElse(existing.endTime)
      _           <- validateTimeRange(newStartTime, newEndTime)

      newStatus = req.status.getOrElse(existing.status)
      _        <- validateStatusTransition(existing.status, newStatus)

      updated = req.applyTo(existing, newStartTime, newEndTime, newStatus)

      persisted <- scheduleDayRepository.update(updated).mapDatabaseError
    } yield persisted

  def cancelScheduleDay(id: ScheduleDayId, companyId: CompanyId): IO[ScheduleError, ScheduleDay] =
    for {
      existing <- getScheduleDay(id)
      _        <- validateCompanyMatch(existing.companyId, companyId)
      _        <- validateStatusTransition(existing.status, ScheduleDayStatus.Cancelled)

      updated = existing.copy(
                  status = ScheduleDayStatus.Cancelled,
                  updatedAt = Instant.now()
                )

      persisted <- scheduleDayRepository.update(updated).mapDatabaseError
    } yield persisted

  private def validateTimeRange(start: java.time.LocalTime, end: java.time.LocalTime): IO[ScheduleError, Unit] =
    ZIO
      .when(!start.isBefore(end))(
        ZIO.fail(ScheduleError.ValidationError("Start time must be before end time"))
      )
      .unit

  private def validateDriverBelongsToCompany(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, Unit] =
    for {
      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(ScheduleError.DriverNotFound(driverId))
      _         <-
        ZIO
          .when(driver.role != PersonRole.Driver)(
            ZIO.fail(ScheduleError.ValidationError("Person is not a driver"))
          )
          .unit
      _         <-
        ZIO
          .when(!driver.companyId.contains(companyId))(
            ZIO.fail(ScheduleError.CompanyMismatch(companyId, driver.companyId.getOrElse(companyId)))
          )
          .unit
    } yield ()

  private def validateCompanyMatch(existing: CompanyId, requested: CompanyId): IO[ScheduleError, Unit] =
    ZIO
      .when(existing != requested)(
        ZIO.fail(ScheduleError.CompanyMismatch(requested, existing))
      )
      .unit

  private def validateStatusTransition(from: ScheduleDayStatus, to: ScheduleDayStatus): IO[ScheduleError, Unit] =
    if (from == to) ZIO.unit
    else
      val valid =
        (from, to) match
          case (ScheduleDayStatus.Scheduled, ScheduleDayStatus.Active)    => true
          case (ScheduleDayStatus.Active, ScheduleDayStatus.Completed)    => true
          case (ScheduleDayStatus.Scheduled, ScheduleDayStatus.Cancelled) => true
          case (ScheduleDayStatus.Active, ScheduleDayStatus.Cancelled)    => true
          case _                                                          => false

      ZIO
        .when(!valid)(
          ZIO.fail(ScheduleError.InvalidStatusTransition(from, to))
        )
        .unit

object ScheduleService:

  val layer: ZLayer[ScheduleDayRepository & PersonRepository, Nothing, ScheduleService] = ZLayer.fromFunction(
    ScheduleServiceImpl.apply
  )
