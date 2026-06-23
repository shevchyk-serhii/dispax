package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{CompanyId, PartnerCompanyId}
import com.shevchyk.ride.domain.{PartnerCompany, RideError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresPartnerCompanyRepository(xa: Transactor[Task]) extends PartnerCompanyRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  private val selectColumns = fr"id, name, email, phone, address, taxi_company_id, created_at, updated_at"

  implicit val partnerCompanyRead: Read[PartnerCompany] =
    Read[
      (UUID, String, Option[String], Option[String], Option[String], UUID, Instant, Instant)
    ].map { case (id, name, email, phone, address, taxiCompanyId, createdAt, updatedAt) =>
      PartnerCompany(
        id = PartnerCompanyId(id),
        name = name,
        email = email,
        phone = phone,
        address = address,
        taxiCompanyId = CompanyId(taxiCompanyId),
        createdAt = createdAt,
        updatedAt = updatedAt
      )
    }

  override def create(pc: PartnerCompany): Task[PartnerCompany] =
    sql"""
      INSERT INTO partner_companies (id, name, email, phone, address, taxi_company_id)
      VALUES (${pc.id.value}, ${pc.name}, ${pc.email}, ${pc.phone}, ${pc.address}, ${pc.taxiCompanyId.value})
    """.update.run
      .transact(xa)
      .as(pc)
      .mapError(ex => RideError.DatabaseError(ex))

  override def findById(id: PartnerCompanyId, companyId: CompanyId): Task[Option[PartnerCompany]] =
    (fr"SELECT" ++ selectColumns ++
      fr"FROM partner_companies WHERE id = ${id.value} AND taxi_company_id = ${companyId.value}")
      .query[PartnerCompany]
      .option
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))

  override def findByCompany(companyId: CompanyId): Task[List[PartnerCompany]] =
    (fr"SELECT" ++ selectColumns ++
      fr"FROM partner_companies WHERE taxi_company_id = ${companyId.value} ORDER BY name")
      .query[PartnerCompany]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))

object PostgresPartnerCompanyRepository:

  val layer: ZLayer[Transactor[Task], Nothing, PartnerCompanyRepository] = ZLayer.fromFunction((xa: Transactor[Task]) =>
    PostgresPartnerCompanyRepository(xa)
  )
