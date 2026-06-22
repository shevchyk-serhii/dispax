package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, DriverUnavailabilityId, PersonId}
import com.shevchyk.schedule.domain.DriverUnavailability
import zio.*
import java.time.Instant

class InMemoryDriverUnavailabilityRepository extends DriverUnavailabilityRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[DriverUnavailabilityId, DriverUnavailability]))
      .getOrThrowFiberFailure()
  }

  override def create(u: DriverUnavailability): Task[DriverUnavailability] = store.update(_.updated(u.id, u)).as(u)

  override def findById(id: DriverUnavailabilityId): Task[Option[DriverUnavailability]] = store.get.map(_.get(id))

  override def findByDriver(driverId: PersonId, companyId: CompanyId): Task[List[DriverUnavailability]] = store.get.map(
    _.values.filter(u => u.driverId == driverId && u.companyId == companyId).toList.sortBy(_.fromTime)
  )

  override def findByCompanyAndRange(
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[DriverUnavailability]] = store.get.map(
    _.values
      .filter(u => u.companyId == companyId && u.fromTime.isBefore(to) && from.isBefore(u.toTime))
      .toList
      .sortBy(_.fromTime)
  )

  override def findOverlapping(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[DriverUnavailability]] = store.get.map(
    _.values
      .filter(u =>
        u.driverId == driverId &&
          u.companyId == companyId &&
          u.fromTime.isBefore(to) &&
          from.isBefore(u.toTime)
      )
      .toList
      .sortBy(_.fromTime)
  )

  override def delete(id: DriverUnavailabilityId, driverId: PersonId, companyId: CompanyId): Task[Unit] =
    store
      .update(m =>
        m.get(id) match
          case Some(u) if u.driverId == driverId && u.companyId == companyId => m.removed(id)
          case _                                                             => m
      )
      .unit

object InMemoryDriverUnavailabilityRepository:

  val layer: ZLayer[Any, Nothing, DriverUnavailabilityRepository] = ZLayer.succeed(
    new InMemoryDriverUnavailabilityRepository
  )
