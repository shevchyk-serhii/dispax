package com.shevchyk.core.repository

import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId}
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

class InMemoryClientCompanyRepository extends ClientCompanyRepository:
  private val store = new ConcurrentHashMap[ClientCompanyId, ClientCompany]()

  override def create(company: ClientCompany): Task[ClientCompany] = ZIO.succeed {
    store.put(company.id, company); company
  }

  override def findById(id: ClientCompanyId): Task[Option[ClientCompany]] = ZIO.succeed(Option(store.get(id)))

  override def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]] = ZIO.succeed(
    store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).toList.sortBy(_.name)
  )

  override def update(company: ClientCompany): Task[ClientCompany] = ZIO.succeed {
    store.put(company.id, company); company
  }

  override def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)) match
      case Some(c) if c.taxiCompanyId == taxiCompanyId => store.remove(id) != null
      case _                                           => false
  }

object InMemoryClientCompanyRepository:
  val layer: ULayer[ClientCompanyRepository] = ZLayer.succeed(new InMemoryClientCompanyRepository)
