package com.shevchyk.core.repository

import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus}
import zio.*

/**
 * Ref-backed in-memory implementation of [[CompanyRepository]] for use in unit tests. Never used in integration tests —
 * those use a real PostgreSQL via Testcontainers.
 */
class InMemoryCompanyRepository extends CompanyRepository:

  private val store = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[CompanyId, Company])).getOrThrowFiberFailure()
  }

  override def findAll(): Task[List[Company]] = store.get.map(_.values.toList.sortBy(_.name))

  override def findById(id: CompanyId): Task[Option[Company]] = store.get.map(_.get(id))

  override def create(company: Company): Task[Company] = store.update(_.updated(company.id, company)).as(company)

  override def update(company: Company): Task[Company] = store.update(_.updated(company.id, company)).as(company)

  override def countByStatus(): Task[Map[CompanyStatus, Int]] = store.get.map(
    _.values
      .groupBy(_.status)
      .map((k, v) => k -> v.size)
  )

  override def softDelete(id: CompanyId): Task[Option[Company]] = store.modifyZIO { m =>
    m.get(id) match
      case None          => ZIO.succeed((None, m))
      case Some(company) =>
        val updated = company.copy(status = CompanyStatus.Inactive)
        ZIO.succeed((Some(updated), m.updated(id, updated)))
  }

object InMemoryCompanyRepository:
  val layer: ZLayer[Any, Nothing, CompanyRepository] = ZLayer.succeed(new InMemoryCompanyRepository)
