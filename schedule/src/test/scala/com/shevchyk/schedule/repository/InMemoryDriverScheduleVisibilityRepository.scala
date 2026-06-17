package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.schedule.domain.DriverScheduleVisibility
import zio.*

class InMemoryDriverScheduleVisibilityRepository extends DriverScheduleVisibilityRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[PersonId, DriverScheduleVisibility]))
      .getOrThrowFiberFailure()
  }

  override def findByDriver(driverId: PersonId): Task[Option[DriverScheduleVisibility]] =
    store.get.map(_.get(driverId))

  override def upsert(visibility: DriverScheduleVisibility): Task[DriverScheduleVisibility] =
    store.update(_.updated(visibility.driverId, visibility)).as(visibility)

  override def findByCompany(companyId: CompanyId): Task[List[DriverScheduleVisibility]] =
    store.get.map(_.values.filter(_.companyId == companyId).toList)

object InMemoryDriverScheduleVisibilityRepository:
  val layer: ZLayer[Any, Nothing, DriverScheduleVisibilityRepository] =
    ZLayer.succeed(new InMemoryDriverScheduleVisibilityRepository)
