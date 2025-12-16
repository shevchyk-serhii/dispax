package com.shevchyk.auth.repository

import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*
import java.util.UUID

trait TokenRepository:
  def create(token: String, userId: UUID): Task[Unit]
  def findUserIdByToken(token: String): Task[Option[UUID]]
  def deleteByToken(token: String): Task[Unit]
  def deleteByUserId(userId: UUID): Task[Unit]

object TokenRepository:

  def create(token: String, userId: UUID): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.create(token, userId)
  )

  def findUserIdByToken(token: String): ZIO[TokenRepository, Throwable, Option[UUID]] = ZIO
    .serviceWithZIO[TokenRepository](_.findUserIdByToken(token))

  def deleteByToken(token: String): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.deleteByToken(token)
  )

  def deleteByUserId(userId: UUID): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.deleteByUserId(userId)
  )

  private val postgresLayer: ZLayer[Transactor[Task], Nothing, TokenRepository] = ZLayer.fromFunction(
    PostgresTokenRepository.apply
  )

  val layer: ZLayer[Any, Throwable, TokenRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
