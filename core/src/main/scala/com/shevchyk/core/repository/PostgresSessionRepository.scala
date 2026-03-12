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

final class PostgresSessionRepository(xa: Transactor[Task]) extends SessionRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def create(session: Session): Task[Session] =
    sql"""
      INSERT INTO sessions (id, user_id, token, device_info, ip_address, created_at, last_active_at, is_active)
      VALUES (${session.id.value}, ${session.userId.value}, ${session.token},
              ${session.deviceInfo}, ${session.ipAddress},
              ${session.createdAt}, ${session.lastActiveAt}, ${session.isActive})
    """.update.run
      .transact(xa)
      .as(session)

  override def findByUserId(userId: PersonId): Task[List[Session]] =
    sql"""
      SELECT id, user_id, token, device_info, ip_address, created_at, last_active_at, is_active
      FROM sessions
      WHERE user_id = ${userId.value} AND is_active = true
      ORDER BY last_active_at DESC
    """
      .query[Session]
      .to[List]
      .transact(xa)

  override def findByToken(token: String): Task[Option[Session]] =
    sql"""
      SELECT id, user_id, token, device_info, ip_address, created_at, last_active_at, is_active
      FROM sessions
      WHERE token = $token AND is_active = true
    """
      .query[Session]
      .option
      .transact(xa)

  override def updateLastActive(sessionId: SessionId): Task[Unit] =
    sql"""
      UPDATE sessions SET last_active_at = NOW() WHERE id = ${sessionId.value}
    """.update.run
      .transact(xa)
      .unit

  override def deactivate(sessionId: SessionId): Task[Boolean] =
    sql"""
      UPDATE sessions SET is_active = false WHERE id = ${sessionId.value} AND is_active = true
    """.update.run
      .transact(xa)
      .map(_ > 0)

  override def deactivateAllForUser(userId: PersonId): Task[Int] =
    sql"""
      UPDATE sessions SET is_active = false WHERE user_id = ${userId.value} AND is_active = true
    """.update.run
      .transact(xa)

  override def deactivateAllExcept(userId: PersonId, currentSessionId: SessionId): Task[Int] =
    sql"""
      UPDATE sessions SET is_active = false
      WHERE user_id = ${userId.value} AND is_active = true AND id != ${currentSessionId.value}
    """.update.run
      .transact(xa)

  implicit val sessionRead: Read[Session] =
    Read[(UUID, UUID, String, Option[String], Option[String], Instant, Instant, Boolean)].map {
      case (id, userId, token, deviceInfo, ipAddress, createdAt, lastActiveAt, isActive) =>
        Session(
          id = SessionId(id),
          userId = PersonId(userId),
          token = token,
          deviceInfo = deviceInfo,
          ipAddress = ipAddress,
          createdAt = createdAt,
          lastActiveAt = lastActiveAt,
          isActive = isActive
        )
    }

object PostgresSessionRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, SessionRepository] = ZLayer.fromFunction(
    PostgresSessionRepository(_)
  )
