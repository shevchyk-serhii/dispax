package com.shevchyk.core.repository

import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.util.UUID

final class PostgresClientCompanyRepository(xa: Transactor[Task]) extends ClientCompanyRepository:

  private val selectColumns =
    fr"id, name, taxi_company_id, email, phone, address, preferred_language, vat_id, airport_buffer_minutes, airport_checkin_close_minutes"

  implicit val clientCompanyRead: Read[ClientCompany] =
    Read[
      (
          UUID,
          String,
          UUID,
          Option[String],
          Option[String],
          Option[String],
          Option[String],
          Option[String],
          Option[Int],
          Option[Int]
      )
    ].map {
      case (
            id,
            name,
            taxiCompanyId,
            email,
            phone,
            address,
            preferredLanguage,
            vatId,
            airportBufferMinutes,
            airportCheckInCloseMinutes
          ) =>
        ClientCompany(
          id = ClientCompanyId(id),
          name = name,
          taxiCompanyId = CompanyId(taxiCompanyId),
          email = email,
          phone = phone,
          address = address,
          preferredLanguage = preferredLanguage,
          vatId = vatId,
          airportBufferMinutes = airportBufferMinutes,
          airportCheckInCloseMinutes = airportCheckInCloseMinutes
        )
    }

  override def create(company: ClientCompany): Task[ClientCompany] =
    sql"""
      INSERT INTO client_companies (id, name, taxi_company_id, email, phone, address, preferred_language,
                                    vat_id, airport_buffer_minutes, airport_checkin_close_minutes)
      VALUES (${company.id.value}, ${company.name}, ${company.taxiCompanyId.value},
              ${company.email}, ${company.phone}, ${company.address}, ${company.preferredLanguage},
              ${company.vatId}, ${company.airportBufferMinutes}, ${company.airportCheckInCloseMinutes})
    """.update.run
      .transact(xa)
      .as(company)

  override def findById(id: ClientCompanyId): Task[Option[ClientCompany]] =
    (fr"SELECT" ++ selectColumns ++ fr"FROM client_companies WHERE id = ${id.value}")
      .query[ClientCompany]
      .option
      .transact(xa)

  override def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]] =
    (fr"SELECT" ++ selectColumns ++ fr"FROM client_companies WHERE taxi_company_id = ${taxiCompanyId.value} ORDER BY name")
      .query[ClientCompany]
      .to[List]
      .transact(xa)

  override def update(company: ClientCompany): Task[ClientCompany] =
    sql"""
      UPDATE client_companies
      SET name = ${company.name},
          email = ${company.email},
          phone = ${company.phone},
          address = ${company.address},
          preferred_language = ${company.preferredLanguage},
          vat_id = ${company.vatId},
          airport_buffer_minutes = ${company.airportBufferMinutes},
          airport_checkin_close_minutes = ${company.airportCheckInCloseMinutes},
          updated_at = NOW()
      WHERE id = ${company.id.value} AND taxi_company_id = ${company.taxiCompanyId.value}
    """.update.run
      .transact(xa)
      .as(company)

  override def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean] =
    sql"""DELETE FROM client_companies
          WHERE id = ${id.value} AND taxi_company_id = ${taxiCompanyId.value}""".update.run
      .transact(xa)
      .map(_ > 0)

object PostgresClientCompanyRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ClientCompanyRepository] = ZLayer.fromFunction(
    PostgresClientCompanyRepository(_)
  )
