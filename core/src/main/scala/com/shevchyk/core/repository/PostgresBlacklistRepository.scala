package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresBlacklistRepository(xa: Transactor[Task]) extends BlacklistRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def create(entry: BlacklistEntry): Task[BlacklistEntry] =
    sql"""
      INSERT INTO blacklist_entries (id, company_id, client_id, driver_id, reason, created_by, created_at, is_active)
      VALUES (${entry.id.value}, ${entry.companyId.value}, ${entry.clientId.value},
              ${entry.driverId.value}, ${entry.reason}, ${entry.createdBy.value},
              ${entry.createdAt}, ${entry.isActive})
      ON CONFLICT (client_id, driver_id) DO UPDATE SET
        reason = ${entry.reason}, is_active = true, created_by = ${entry.createdBy.value}, created_at = ${entry.createdAt}
    """.update.run
      .transact(xa)
      .as(entry)

  override def findByCompanyId(companyId: CompanyId): Task[List[BlacklistEntry]] =
    sql"""
      SELECT id, company_id, client_id, driver_id, reason, created_by, created_at, is_active
      FROM blacklist_entries WHERE company_id = ${companyId.value} AND is_active = true
    """
      .query[BlacklistEntry]
      .to[List]
      .transact(xa)

  override def findByClientId(clientId: PersonId): Task[List[BlacklistEntry]] =
    sql"""
      SELECT id, company_id, client_id, driver_id, reason, created_by, created_at, is_active
      FROM blacklist_entries WHERE client_id = ${clientId.value} AND is_active = true
    """
      .query[BlacklistEntry]
      .to[List]
      .transact(xa)

  override def findByDriverId(driverId: PersonId): Task[List[BlacklistEntry]] =
    sql"""
      SELECT id, company_id, client_id, driver_id, reason, created_by, created_at, is_active
      FROM blacklist_entries WHERE driver_id = ${driverId.value} AND is_active = true
    """
      .query[BlacklistEntry]
      .to[List]
      .transact(xa)

  override def isBlacklisted(clientId: PersonId, driverId: PersonId): Task[Boolean] =
    sql"""
      SELECT EXISTS(SELECT 1 FROM blacklist_entries WHERE client_id = ${clientId.value} AND driver_id = ${driverId.value} AND is_active = true)
    """
      .query[Boolean]
      .unique
      .transact(xa)

  override def deactivate(id: BlacklistEntryId): Task[Boolean] =
    sql"""UPDATE blacklist_entries SET is_active = false WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def delete(id: BlacklistEntryId): Task[Boolean] =
    sql"""DELETE FROM blacklist_entries WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  implicit val blacklistRead: Read[BlacklistEntry] =
    Read[(UUID, UUID, UUID, UUID, Option[String], UUID, Instant, Boolean)].map {
      case (id, companyId, clientId, driverId, reason, createdBy, createdAt, isActive) =>
        BlacklistEntry(
          id = BlacklistEntryId(id),
          companyId = CompanyId(companyId),
          clientId = PersonId(clientId),
          driverId = PersonId(driverId),
          reason = reason,
          createdBy = PersonId(createdBy),
          createdAt = createdAt,
          isActive = isActive
        )
    }

object PostgresBlacklistRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, BlacklistRepository] = ZLayer.fromFunction(
    PostgresBlacklistRepository(_)
  )
