package com.shevchyk.auth.repository

import zio.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import cats.effect.IO
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresTokenRepository(xa: Transactor[Task]) extends TokenRepository:

  override def create(token: String, userId: UUID): Task[Unit] =
    sql"""
      INSERT INTO tokens (token, user_id, created_at) 
      VALUES ($token, $userId, ${Instant.now()})
      ON CONFLICT (token) DO UPDATE SET user_id = $userId, created_at = ${Instant.now()}
    """.update.run
      .transact(xa)
      .map(_ => ())

  override def findUserIdByToken(token: String): Task[Option[UUID]] =
    sql"""
      SELECT user_id
      FROM tokens 
      WHERE token = $token
    """
      .query[UUID]
      .option
      .transact(xa)

  override def deleteByToken(token: String): Task[Unit] =
    sql"""
      DELETE FROM tokens WHERE token = $token
    """.update.run
      .transact(xa)
      .map(_ => ())

  override def deleteByUserId(userId: UUID): Task[Unit] =
    sql"""
      DELETE FROM tokens WHERE user_id = $userId
    """.update.run
      .transact(xa)
      .map(_ => ())
