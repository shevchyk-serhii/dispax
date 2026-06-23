package com.shevchyk.ride.repository.helpers

import com.shevchyk.core.domain.{CompanyId, PartnerCompanyId}
import com.shevchyk.ride.domain.PartnerCompany
import com.shevchyk.ride.repository.PartnerCompanyRepository
import zio.*

class InMemoryPartnerCompanyRepository extends PartnerCompanyRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[PartnerCompanyId, PartnerCompany]))
      .getOrThrowFiberFailure()
  }

  override def create(pc: PartnerCompany): Task[PartnerCompany] = store.update(_.updated(pc.id, pc)).as(pc)

  override def findById(id: PartnerCompanyId, companyId: CompanyId): Task[Option[PartnerCompany]] = store.get.map(
    _.get(id).filter(_.taxiCompanyId == companyId)
  )

  override def findByCompany(companyId: CompanyId): Task[List[PartnerCompany]] = store.get.map(
    _.values.filter(_.taxiCompanyId == companyId).toList.sortBy(_.name)
  )

object InMemoryPartnerCompanyRepository:
  val layer: ZLayer[Any, Nothing, PartnerCompanyRepository] = ZLayer.succeed(new InMemoryPartnerCompanyRepository)
