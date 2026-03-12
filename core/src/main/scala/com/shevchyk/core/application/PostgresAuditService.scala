package com.shevchyk.core.application

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresAuditService(xa: Transactor[Task]) extends AuditService:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val auditActionMeta: Meta[AuditAction] = Meta[String].imap(s => AuditAction.valueOf(s))(_.toString)

  override def log(entry: AuditLogEntry): Task[Unit] =
    sql"""
      INSERT INTO audit_log (id, company_id, actor_id, action, entity_type, entity_id, old_value, new_value, metadata, created_at)
      VALUES (${entry.id.value}, ${entry.companyId.value}, ${entry.actorId.value},
              ${entry.action.toString}, ${entry.entityType}, ${entry.entityId},
              ${entry.oldValue}, ${entry.newValue}, ${entry.metadata}::jsonb, ${entry.createdAt})
    """.update.run
      .transact(xa)
      .unit

  override def findByEntity(entityType: String, entityId: UUID): Task[List[AuditLogEntry]] =
    sql"""
      SELECT id, company_id, actor_id, action, entity_type, entity_id, old_value, new_value, metadata::text, created_at
      FROM audit_log
      WHERE entity_type = $entityType AND entity_id = $entityId
      ORDER BY created_at DESC
    """
      .query[AuditLogEntry]
      .to[List]
      .transact(xa)

  override def findByCompany(companyId: CompanyId, limit: Int, offset: Int): Task[List[AuditLogEntry]] =
    sql"""
      SELECT id, company_id, actor_id, action, entity_type, entity_id, old_value, new_value, metadata::text, created_at
      FROM audit_log
      WHERE company_id = ${companyId.value}
      ORDER BY created_at DESC
      LIMIT $limit OFFSET $offset
    """
      .query[AuditLogEntry]
      .to[List]
      .transact(xa)

  implicit val auditLogRead: Read[AuditLogEntry] =
    Read[(UUID, UUID, UUID, String, String, UUID, Option[String], Option[String], Option[String], Instant)].map {
      case (id, companyId, actorId, action, entityType, entityId, oldValue, newValue, metadata, createdAt) =>
        AuditLogEntry(
          id = AuditLogId(id),
          companyId = CompanyId(companyId),
          actorId = PersonId(actorId),
          action = AuditAction.valueOf(action),
          entityType = entityType,
          entityId = entityId,
          oldValue = oldValue,
          newValue = newValue,
          metadata = metadata,
          createdAt = createdAt
        )
    }

object PostgresAuditService:
  val postgresLayer: ZLayer[Transactor[Task], Nothing, AuditService] = ZLayer.fromFunction(PostgresAuditService(_))
