package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.domain.RepositoryExtensions.*
import com.shevchyk.schedule.domain.{CreateDriverUnavailabilityRequest, DriverUnavailability}
import com.shevchyk.schedule.repository.{
  DriverScheduleVisibilityRepository,
  DriverUnavailabilityRepository,
  ScheduleDayRepository
}
import com.shevchyk.core.repository.PersonRepository
import zio.*
import java.time.{Instant, LocalDate}

trait ScheduleService:
  def createScheduleDay(req: CreateScheduleDayRequest): IO[ScheduleError, ScheduleDay]
  def createBatch(req: CreateScheduleBatchRequest): IO[ScheduleError, List[ScheduleDay]]
  def getScheduleDay(id: ScheduleDayId): IO[ScheduleError, ScheduleDay]
  def getDriverSchedule(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, List[ScheduleDay]]

  /**
   * Access-controlled variant: enforces per-driver visibility rules when the requester is a Driver.
   */
  def getDriverScheduleAs(
      requesterId: PersonId,
      requesterRole: String,
      targetDriverId: PersonId,
      companyId: CompanyId
  ): IO[ScheduleError, List[ScheduleDay]]

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

  // -- Visibility management (Dispatcher/Admin) --------------------------------

  def canDriverViewOthers(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, Boolean]
  def getCompanyVisibility(companyId: CompanyId): IO[ScheduleError, List[DriverScheduleVisibility]]

  /**
   * Returns the visibility record for the given driver in the given company, or a default with
   * canViewOtherSchedules=false if no record exists. Accessible to any authenticated user.
   */
  def getMyVisibility(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, DriverScheduleVisibility]

  def setDriverVisibility(
      driverId: PersonId,
      companyId: CompanyId,
      canView: Boolean
  ): IO[ScheduleError, DriverScheduleVisibility]

  // -- Driver unavailability management -----------------------------------

  /**
   * Creates a manual unavailability window. Driver-only-self: requesterId must equal driverId and requesterRole must be
   * DRIVER. Validates from < to and driver belongs to company.
   */
  def createUnavailability(
      req: CreateDriverUnavailabilityRequest,
      requesterId: PersonId,
      requesterRole: String
  ): IO[ScheduleError, DriverUnavailability]

  /**
   * Returns all unavailability windows for the given driver. Access-controlled: mirrors getDriverScheduleAs (self
   * always; dispatcher/admin/secretary always; other driver only if canViewOtherSchedules).
   */
  def getDriverUnavailability(
      driverId: PersonId,
      companyId: CompanyId,
      requesterId: PersonId,
      requesterRole: String
  ): IO[ScheduleError, List[DriverUnavailability]]

  /**
   * Company-wide unavailability in a time range. For the dispatcher day/range view.
   */
  def getCompanyUnavailability(
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): IO[ScheduleError, List[DriverUnavailability]]

  /**
   * Deletes an unavailability window. Owner-only: requesterId must match the record's driverId, or role must be
   * DISPATCHER/ADMIN.
   */
  def deleteUnavailability(
      id: DriverUnavailabilityId,
      requesterId: PersonId,
      requesterRole: String,
      companyId: CompanyId
  ): IO[ScheduleError, Unit]

class ScheduleServiceImpl(
    scheduleDayRepository: ScheduleDayRepository,
    visibilityRepository: DriverScheduleVisibilityRepository,
    personRepository: PersonRepository,
    unavailabilityRepository: DriverUnavailabilityRepository
) extends ScheduleService:

  def createScheduleDay(req: CreateScheduleDayRequest): IO[ScheduleError, ScheduleDay] =
    for {
      _ <- validateTimeRange(req.startTime, req.endTime)
      _ <- validateDriverBelongsToCompany(req.driverId, req.companyId)
      _ <- validateNoShiftOverlap(req)

      scheduleDay = ScheduleMapper.fromRequest(req)
      persisted  <- scheduleDayRepository.create(scheduleDay).mapError {
                      case e: ScheduleError => e
                      case ex               => ScheduleError.DatabaseError(ex)
                    }
    } yield persisted

  def createBatch(req: CreateScheduleBatchRequest): IO[ScheduleError, List[ScheduleDay]] =
    // Validate the WHOLE batch up front, then persist it in one atomic repository call:
    // a failure anywhere must leave nothing committed (a partial batch cannot be retried,
    // because the retry would conflict with the rows the first attempt already wrote).
    val requests = req.days.map { day =>
      CreateScheduleDayRequest(
        driverId = req.driverId,
        companyId = req.companyId,
        date = day.date,
        startTime = day.startTime,
        endTime = day.endTime,
        notes = day.notes
      )
    }
    for {
      _         <- validateDriverBelongsToCompany(req.driverId, req.companyId)
      _         <-
        ZIO.foreachDiscard(requests) { r =>
          validateTimeRange(r.startTime, r.endTime) *> validateNoShiftOverlap(r)
        }
      _         <- validateNoIntraBatchOverlap(requests)
      persisted <- scheduleDayRepository.createAll(requests.map(ScheduleMapper.fromRequest)).mapError {
                     case e: ScheduleError => e
                     case ex               => ScheduleError.DatabaseError(ex)
                   }
    } yield persisted

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

  // Roles allowed to read ANY driver's operational schedule in their company. An explicit
  // whitelist: the previous "anything that is not DRIVER → allowed" else-branch let CLIENT /
  // CLIENT_SECRETARY (legitimate authenticated roles) read any driver's schedule.
  private val staffScheduleRoles = Set("DISPATCHER", "ADMIN", "SECRETARY", "SUPER_ADMIN")

  def getDriverScheduleAs(
      requesterId: PersonId,
      requesterRole: String,
      targetDriverId: PersonId,
      companyId: CompanyId
  ): IO[ScheduleError, List[ScheduleDay]] =
    val roleUpper = requesterRole.toUpperCase
    if requesterId == targetDriverId then
      // Viewing own schedule — always allowed
      getDriverSchedule(targetDriverId, companyId)
    else if roleUpper == "DRIVER" then
      // Another driver's schedule — only if visibility is granted
      for {
        allowed <- canDriverViewOthers(requesterId, companyId)
        _       <-
          ZIO.unless(allowed)(
            ZIO.fail(ScheduleError.AccessDenied("You are not allowed to view other drivers' schedules"))
          )
        days    <- getDriverSchedule(targetDriverId, companyId)
      } yield days
    else if staffScheduleRoles.contains(roleUpper) then
      // Dispatcher / Admin / Secretary / SuperAdmin — always allowed
      getDriverSchedule(targetDriverId, companyId)
    else
      // CLIENT / CLIENT_SECRETARY / anything unknown: driver schedules are staff-only.
      ZIO.fail(ScheduleError.AccessDenied("Driver schedules are visible to staff roles only"))

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

      // Re-run the overlap invariant on edit: moving/stretching a shift must not make it
      // collide with another non-cancelled shift of the same driver on the same date.
      // The edited day itself is excluded from the comparison set. A day being cancelled
      // frees its slot, so no overlap check is needed for it.
      _ <-
        ZIO.unless(newStatus == ScheduleDayStatus.Cancelled)(
          validateNoShiftOverlap(
            existing.driverId,
            existing.companyId,
            existing.date,
            newStartTime,
            newEndTime,
            excludeId = Some(existing.id)
          )
        )

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

  // -- Visibility ----------------------------------------------------------

  def canDriverViewOthers(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, Boolean] = visibilityRepository
    .findByDriver(driverId)
    .mapDatabaseError
    .map {
      // Row absence = false; row with wrong company also treated as false (tenant safety)
      case Some(v) if v.companyId == companyId => v.canViewOtherSchedules
      case _                                   => false
    }

  def getCompanyVisibility(companyId: CompanyId): IO[ScheduleError, List[DriverScheduleVisibility]] =
    visibilityRepository
      .findByCompany(companyId)
      .mapDatabaseError

  def getMyVisibility(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, DriverScheduleVisibility] =
    visibilityRepository
      .findByDriver(driverId)
      .mapDatabaseError
      .map {
        case Some(v) if v.companyId == companyId => v
        // Row absent or belongs to a different company — return safe default
        case _                                   =>
          DriverScheduleVisibility(
            driverId = driverId,
            companyId = companyId,
            canViewOtherSchedules = false,
            updatedAt = java.time.Instant.EPOCH
          )
      }

  def setDriverVisibility(
      driverId: PersonId,
      companyId: CompanyId,
      canView: Boolean
  ): IO[ScheduleError, DriverScheduleVisibility] =
    for {
      _         <- validateDriverBelongsToCompany(driverId, companyId)
      visibility = DriverScheduleVisibility(
                     driverId = driverId,
                     companyId = companyId,
                     canViewOtherSchedules = canView,
                     updatedAt = Instant.now()
                   )
      persisted <- visibilityRepository.upsert(visibility).mapDatabaseError
    } yield persisted

  // -- Private helpers -----------------------------------------------------

  private def validateTimeRange(start: java.time.LocalTime, end: java.time.LocalTime): IO[ScheduleError, Unit] =
    ZIO
      .when(!start.isBefore(end))(
        ZIO.fail(ScheduleError.ValidationError("Start time must be before end time"))
      )
      .unit

  /**
   * Rejects a new shift that overlaps any existing (non-cancelled) shift for the same driver on the same date. Two
   * half-open intervals [start, end) overlap iff `newStart < existingEnd && existingStart < newEnd`, so back-to-back
   * shifts (e.g. 09:00–12:00 then 12:00–15:00) are allowed. Cancelled shifts free up their slot and never block a new
   * shift.
   */
  private def validateNoShiftOverlap(req: CreateScheduleDayRequest): IO[ScheduleError, Unit] = validateNoShiftOverlap(
    req.driverId,
    req.companyId,
    req.date,
    req.startTime,
    req.endTime,
    excludeId = None
  )

  /**
   * Shared overlap check for both create and update. `excludeId` removes the day being edited from the comparison set
   * so a shift never conflicts with itself.
   */
  private def validateNoShiftOverlap(
      driverId: PersonId,
      companyId: CompanyId,
      date: LocalDate,
      startTime: java.time.LocalTime,
      endTime: java.time.LocalTime,
      excludeId: Option[ScheduleDayId]
  ): IO[ScheduleError, Unit] = scheduleDayRepository
    .findShiftsForDriverOnDate(driverId, companyId, date)
    .mapDatabaseError
    .flatMap { existing =>
      val overlaps = existing.exists { d =>
        !excludeId.contains(d.id) &&
        d.status != ScheduleDayStatus.Cancelled &&
        startTime.isBefore(d.endTime) && d.startTime.isBefore(endTime)
      }
      ZIO
        .when(overlaps)(
          ZIO.fail(ScheduleError.OverlapConflict(driverId, date))
        )
        .unit
    }

  /**
   * Rejects a batch whose OWN days overlap each other (same date, intersecting half-open time ranges). Overlap against
   * already-persisted shifts is checked per day by [[validateNoShiftOverlap]].
   */
  private def validateNoIntraBatchOverlap(requests: List[CreateScheduleDayRequest]): IO[ScheduleError, Unit] =
    val conflict = requests.zipWithIndex.collectFirst {
      case (r, idx)
          if requests
            .take(idx)
            .exists(other =>
              other.date == r.date && r.startTime.isBefore(other.endTime) && other.startTime.isBefore(r.endTime)
            ) =>
        r
    }
    conflict match
      case Some(r) => ZIO.fail(ScheduleError.OverlapConflict(r.driverId, r.date))
      case None    => ZIO.unit

  private def validateDriverBelongsToCompany(driverId: PersonId, companyId: CompanyId): IO[ScheduleError, Unit] =
    for {
      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(ScheduleError.DriverNotFound(driverId))
      _         <-
        ZIO
          .when(!driver.canDrive)(
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

  // -- Driver unavailability -----------------------------------------------

  def createUnavailability(
      req: CreateDriverUnavailabilityRequest,
      requesterId: PersonId,
      requesterRole: String
  ): IO[ScheduleError, DriverUnavailability] =
    val roleUpper = requesterRole.toUpperCase
    for {
      _         <-
        ZIO
          .when(requesterId != req.driverId || roleUpper != "DRIVER")(
            ZIO.fail(ScheduleError.AccessDenied("Only the driver may mark their own unavailability"))
          )
          .unit
      _         <- validateInstantRange(req.fromTime, req.toTime)
      _         <- validateDriverBelongsToCompany(req.driverId, req.companyId)
      u          = DriverUnavailability(
                     id = DriverUnavailabilityId.generate(),
                     driverId = req.driverId,
                     companyId = req.companyId,
                     fromTime = req.fromTime,
                     toTime = req.toTime,
                     reason = req.reason,
                     note = req.note,
                     createdAt = Instant.now()
                   )
      persisted <- unavailabilityRepository.create(u).mapDatabaseError
    } yield persisted

  def getDriverUnavailability(
      driverId: PersonId,
      companyId: CompanyId,
      requesterId: PersonId,
      requesterRole: String
  ): IO[ScheduleError, List[DriverUnavailability]] =
    val roleUpper = requesterRole.toUpperCase
    if requesterId == driverId then unavailabilityRepository.findByDriver(driverId, companyId).mapDatabaseError
    else if roleUpper == "DRIVER" then
      for {
        allowed <- canDriverViewOthers(requesterId, companyId)
        _       <-
          ZIO.unless(allowed)(
            ZIO.fail(ScheduleError.AccessDenied("You are not allowed to view other drivers' unavailability"))
          )
        result  <- unavailabilityRepository.findByDriver(driverId, companyId).mapDatabaseError
      } yield result
    else if staffScheduleRoles.contains(roleUpper) then
      unavailabilityRepository.findByDriver(driverId, companyId).mapDatabaseError
    else
      // Same whitelist as getDriverScheduleAs: the old permissive else let CLIENT / CLIENT_SECRETARY read any
      // driver's unavailability windows (reason + free-text note) within the tenant. Staff roles only.
      ZIO.fail(ScheduleError.AccessDenied("Driver unavailability is visible to staff roles only"))

  def getCompanyUnavailability(
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): IO[ScheduleError, List[DriverUnavailability]] =
    unavailabilityRepository.findByCompanyAndRange(companyId, from, to).mapDatabaseError

  def deleteUnavailability(
      id: DriverUnavailabilityId,
      requesterId: PersonId,
      requesterRole: String,
      companyId: CompanyId
  ): IO[ScheduleError, Unit] =
    val roleUpper = requesterRole.toUpperCase
    for {
      existing <- unavailabilityRepository.findById(id).mapDatabaseError.flatMap {
                    case Some(u) => ZIO.succeed(u)
                    case None    => ZIO.fail(ScheduleError.UnavailabilityNotFound(id))
                  }
      _        <-
        ZIO
          .when(existing.companyId != companyId)(
            ZIO.fail(ScheduleError.AccessDenied("Unavailability belongs to a different company"))
          )
          .unit
      _        <-
        ZIO
          .when(existing.driverId != requesterId && roleUpper != "DISPATCHER" && roleUpper != "ADMIN")(
            ZIO.fail(
              ScheduleError.AccessDenied("Only the owning driver, dispatcher, or admin may delete this unavailability")
            )
          )
          .unit
      _        <- unavailabilityRepository.delete(id, existing.driverId, companyId).mapDatabaseError
    } yield ()

  private def validateInstantRange(from: Instant, to: Instant): IO[ScheduleError, Unit] =
    ZIO
      .when(!from.isBefore(to))(
        ZIO.fail(ScheduleError.ValidationError("from_time must be before to_time"))
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

  val layer
      : ZLayer[ScheduleDayRepository & DriverScheduleVisibilityRepository & PersonRepository & DriverUnavailabilityRepository, Nothing, ScheduleService] =
    ZLayer.fromFunction(ScheduleServiceImpl.apply)
