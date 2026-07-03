package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.schedule.domain.{ScheduleDay, ScheduleDayStatus, ScheduleError}
import zio.*
import java.time.LocalDate

class InMemoryScheduleDayRepository extends ScheduleDayRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[ScheduleDayId, ScheduleDay])).getOrThrowFiberFailure()
  }

  // Mirrors the DB exclusion constraint excl_schedule_days_shift_overlap: only
  // time-overlapping non-cancelled shifts of the same driver conflict
  // (half-open intervals, so back-to-back shifts are allowed).
  private def conflicts(a: ScheduleDay, b: ScheduleDay): Boolean =
    a.status != ScheduleDayStatus.Cancelled && b.status != ScheduleDayStatus.Cancelled &&
      a.driverId == b.driverId && a.date == b.date &&
      a.startTime.isBefore(b.endTime) && b.startTime.isBefore(a.endTime)

  override def create(scheduleDay: ScheduleDay): Task[ScheduleDay] = store.get.flatMap { current =>
    val overlaps = current.values.exists(d => conflicts(scheduleDay, d))
    if (overlaps)
      ZIO.fail(ScheduleError.OverlapConflict(scheduleDay.driverId, scheduleDay.date))
    else
      store.update(_.updated(scheduleDay.id, scheduleDay)).as(scheduleDay)
  }

  // Mirrors the transactional Postgres createAll: any conflict (against existing rows OR
  // within the batch itself) fails the whole call and NOTHING is inserted.
  override def createAll(scheduleDays: List[ScheduleDay]): Task[List[ScheduleDay]] = store.modifyZIO { current =>
    val conflict = scheduleDays.zipWithIndex.collectFirst {
      case (day, idx)
          if current.values.exists(d => conflicts(day, d)) ||
            scheduleDays.take(idx).exists(other => conflicts(day, other)) =>
        day
    }
    conflict match
      case Some(day) => ZIO.fail(ScheduleError.OverlapConflict(day.driverId, day.date))
      case None      => ZIO.succeed((scheduleDays, current ++ scheduleDays.map(d => d.id -> d)))
  }

  override def findById(id: ScheduleDayId): Task[Option[ScheduleDay]] = store.get.map(_.get(id))

  override def findByDriverId(driverId: PersonId): Task[List[ScheduleDay]] = store.get.map(
    _.values.filter(_.driverId == driverId).toList.sortBy(_.date)
  )

  override def findByDriverAndDate(driverId: PersonId, date: LocalDate): Task[Option[ScheduleDay]] = store.get.map(
    _.values.find(d => d.driverId == driverId && d.date == date)
  )

  override def findShiftsForDriverOnDate(
      driverId: PersonId,
      companyId: CompanyId,
      date: LocalDate
  ): Task[List[ScheduleDay]] = store.get.map(
    _.values
      .filter(d => d.driverId == driverId && d.companyId == companyId && d.date == date)
      .toList
      .sortBy(_.startTime)
  )

  override def findByCompanyAndDate(companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]] = store.get.map(
    _.values.filter(d => d.companyId == companyId && d.date == date).toList.sortBy(_.startTime)
  )

  override def findByCompanyAndDateRange(
      companyId: CompanyId,
      from: LocalDate,
      to: LocalDate
  ): Task[List[ScheduleDay]] = store.get.map(
    _.values
      .filter(d => d.companyId == companyId && !d.date.isBefore(from) && !d.date.isAfter(to))
      .toList
      .sortBy(d => (d.date, d.startTime))
  )

  override def update(scheduleDay: ScheduleDay): Task[ScheduleDay] = store
    .update(_.updated(scheduleDay.id, scheduleDay))
    .as(scheduleDay)

  override def delete(id: ScheduleDayId, companyId: CompanyId): Task[Unit] =
    store
      .update(m =>
        m.get(id) match
          case Some(d) if d.companyId == companyId => m.removed(id)
          case _                                   => m
      )
      .unit

object InMemoryScheduleDayRepository:
  val layer: ZLayer[Any, Nothing, ScheduleDayRepository] = ZLayer.succeed(new InMemoryScheduleDayRepository)
