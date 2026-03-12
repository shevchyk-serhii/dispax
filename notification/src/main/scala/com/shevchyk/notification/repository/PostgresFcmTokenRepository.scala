package com.shevchyk.notification.repository

import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.FcmToken
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresFcmTokenRepository(xa: Transactor[Task]) extends FcmTokenRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def save(token: FcmToken): Task[Unit] =
    sql"""
      INSERT INTO fcm_tokens (person_id, token, platform, created_at)
      VALUES (${token.personId.value}, ${token.token}, ${token.platform}, ${token.createdAt})
      ON CONFLICT (token) DO UPDATE SET person_id = ${token.personId.value}, platform = ${token.platform}
    """.update.run
      .transact(xa)
      .unit

  override def findByPersonId(personId: PersonId): Task[List[FcmToken]] =
    sql"""
      SELECT person_id, token, platform, created_at
      FROM fcm_tokens WHERE person_id = ${personId.value}
    """
      .query[FcmToken]
      .to[List]
      .transact(xa)

  override def deleteByToken(token: String): Task[Unit] =
    sql"""DELETE FROM fcm_tokens WHERE token = $token""".update.run
      .transact(xa)
      .unit

  override def deleteByPersonId(personId: PersonId): Task[Unit] =
    sql"""DELETE FROM fcm_tokens WHERE person_id = ${personId.value}""".update.run
      .transact(xa)
      .unit

  implicit val fcmTokenRead: Read[FcmToken] = Read[(UUID, String, String, Instant)].map {
    case (personId, token, platform, createdAt) =>
      FcmToken(
        personId = PersonId(personId),
        token = token,
        platform = platform,
        createdAt = createdAt
      )
  }

object PostgresFcmTokenRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, FcmTokenRepository] = ZLayer.fromFunction(
    PostgresFcmTokenRepository(_)
  )
