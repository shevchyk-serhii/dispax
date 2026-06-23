package com.shevchyk.ride.repository.helpers

import com.shevchyk.core.domain.{CompanyId, ExternalDriverId}
import com.shevchyk.ride.domain.ExternalDriver
import com.shevchyk.ride.repository.ExternalDriverRepository
import zio.*

class InMemoryExternalDriverRepository extends ExternalDriverRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[ExternalDriverId, ExternalDriver]))
      .getOrThrowFiberFailure()
  }

  override def create(ed: ExternalDriver): Task[ExternalDriver] = store.update(_.updated(ed.id, ed)).as(ed)

  override def findById(id: ExternalDriverId, companyId: CompanyId): Task[Option[ExternalDriver]] = store.get.map(
    _.get(id).filter(_.taxiCompanyId == companyId)
  )

  override def findByCompany(companyId: CompanyId): Task[List[ExternalDriver]] = store.get.map(
    _.values.filter(_.taxiCompanyId == companyId).toList.sortBy(_.name)
  )

object InMemoryExternalDriverRepository:
  val layer: ZLayer[Any, Nothing, ExternalDriverRepository] = ZLayer.succeed(new InMemoryExternalDriverRepository)
