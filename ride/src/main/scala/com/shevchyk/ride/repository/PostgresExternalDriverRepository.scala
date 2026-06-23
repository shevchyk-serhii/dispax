package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{CompanyId, ExternalDriverId, PartnerCompanyId}
import com.shevchyk.ride.domain.{ExternalDriver, RideError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresExternalDriverRepository(xa: Transactor[Task]) extends ExternalDriverRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  private val selectColumns = fr"id, name, phone, partner_company_id, taxi_company_id, created_at, updated_at"

  implicit val externalDriverRead: Read[ExternalDriver] =
    Read[
      (UUID, String, Option[String], Option[UUID], UUID, Instant, Instant)
    ].map { case (id, name, phone, partnerCompanyId, taxiCompanyId, createdAt, updatedAt) =>
      ExternalDriver(
        id = ExternalDriverId(id),
        name = name,
        phone = phone,
        partnerCompanyId = partnerCompanyId.map(PartnerCompanyId.apply),
        taxiCompanyId = CompanyId(taxiCompanyId),
        createdAt = createdAt,
        updatedAt = updatedAt
      )
    }

  override def create(ed: ExternalDriver): Task[ExternalDriver] =
    sql"""
      INSERT INTO external_drivers (id, name, phone, partner_company_id, taxi_company_id)
      VALUES (${ed.id.value}, ${ed.name}, ${ed.phone}, ${ed.partnerCompanyId.map(_.value)}, ${ed.taxiCompanyId.value})
    """.update.run
      .transact(xa)
      .as(ed)
      .mapError(ex => RideError.DatabaseError(ex))

  override def findById(id: ExternalDriverId, companyId: CompanyId): Task[Option[ExternalDriver]] =
    (fr"SELECT" ++ selectColumns ++
      fr"FROM external_drivers WHERE id = ${id.value} AND taxi_company_id = ${companyId.value}")
      .query[ExternalDriver]
      .option
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))

  override def findByCompany(companyId: CompanyId): Task[List[ExternalDriver]] =
    (fr"SELECT" ++ selectColumns ++
      fr"FROM external_drivers WHERE taxi_company_id = ${companyId.value} ORDER BY name")
      .query[ExternalDriver]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))

object PostgresExternalDriverRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ExternalDriverRepository] = ZLayer.fromFunction((xa: Transactor[Task]) =>
    PostgresExternalDriverRepository(xa)
  )
