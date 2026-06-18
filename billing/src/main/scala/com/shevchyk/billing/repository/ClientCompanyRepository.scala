package com.shevchyk.billing.repository

import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId, CreateClientCompanyRequest}
import com.shevchyk.core.database.DatabaseConfig
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.util.UUID

trait ClientCompanyRepository:
  def findById(id: ClientCompanyId): Task[Option[ClientCompany]]
  def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]
  def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany]

  // Tenant-scoped: only affect the client company owned by `taxiCompanyId`.
  def update(
      id: ClientCompanyId,
      taxiCompanyId: CompanyId,
      req: CreateClientCompanyRequest
  ): Task[Option[ClientCompany]]
  def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean]

object ClientCompanyRepository:

  val layer: ZLayer[Any, Throwable, ClientCompanyRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresClientCompanyRepository.layer

final class PostgresClientCompanyRepository(xa: Transactor[Task]) extends ClientCompanyRepository:

  private def row2cc(
      id: UUID,
      name: String,
      taxiId: UUID,
      email: Option[String],
      phone: Option[String],
      address: Option[String],
      preferredLanguage: Option[String]
  ): ClientCompany = ClientCompany(
    ClientCompanyId(id),
    name,
    CompanyId(taxiId),
    email,
    phone,
    address,
    preferredLanguage
  )

  override def findById(id: ClientCompanyId): Task[Option[ClientCompany]] =
    sql"""SELECT id, name, taxi_company_id, email, phone, address, preferred_language
          FROM client_companies WHERE id = ${id.value}"""
      .query[(UUID, String, UUID, Option[String], Option[String], Option[String], Option[String])]
      .option
      .transact(xa)
      .map(_.map(row2cc.tupled))

  override def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]] =
    sql"""SELECT id, name, taxi_company_id, email, phone, address, preferred_language
          FROM client_companies WHERE taxi_company_id = ${taxiCompanyId.value}
          ORDER BY name"""
      .query[(UUID, String, UUID, Option[String], Option[String], Option[String], Option[String])]
      .to[List]
      .transact(xa)
      .map(_.map(row2cc.tupled))

  override def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany] =
    val id = ClientCompanyId.generate()
    sql"""INSERT INTO client_companies (id, name, taxi_company_id, email, phone, address, preferred_language)
          VALUES (${id.value}, ${req.name}, ${taxiCompanyId.value}, ${req.email}, ${req.phone}, ${req.address}, ${req.preferredLanguage})""".update.run
      .transact(xa)
      .as(ClientCompany(id, req.name, taxiCompanyId, req.email, req.phone, req.address, req.preferredLanguage))

  override def update(
      id: ClientCompanyId,
      taxiCompanyId: CompanyId,
      req: CreateClientCompanyRequest
  ): Task[Option[ClientCompany]] =
    sql"""UPDATE client_companies
          SET name = ${req.name}, email = ${req.email}, phone = ${req.phone}, address = ${req.address},
              preferred_language = ${req.preferredLanguage}, updated_at = NOW()
          WHERE id = ${id.value} AND taxi_company_id = ${taxiCompanyId.value}""".update.run
      .transact(xa)
      .flatMap {
        case 0 => ZIO.none
        case _ => findById(id)
      }

  override def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean] =
    sql"""DELETE FROM client_companies
          WHERE id = ${id.value} AND taxi_company_id = ${taxiCompanyId.value}""".update.run
      .transact(xa)
      .map(_ > 0)

object PostgresClientCompanyRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ClientCompanyRepository] = ZLayer.fromFunction(
    PostgresClientCompanyRepository(_)
  )
