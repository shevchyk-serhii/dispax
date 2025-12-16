package com.shevchyk.auth.repository

import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait TokenRepository:
  def create(token: String, userId: Long): Task[Unit]
  def findUserIdByToken(token: String): Task[Option[Long]]
  def deleteByToken(token: String): Task[Unit]
  def deleteByUserId(userId: Long): Task[Unit]

object TokenRepository:

  def create(token: String, userId: Long): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.create(token, userId)
  )

  def findUserIdByToken(token: String): ZIO[TokenRepository, Throwable, Option[Long]] = ZIO
    .serviceWithZIO[TokenRepository](_.findUserIdByToken(token))

  def deleteByToken(token: String): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.deleteByToken(token)
  )

  def deleteByUserId(userId: Long): ZIO[TokenRepository, Throwable, Unit] = ZIO.serviceWithZIO[TokenRepository](
    _.deleteByUserId(userId)
  )

  private val postgresLayer: ZLayer[Transactor[Task], Nothing, TokenRepository] = ZLayer.fromFunction(
    PostgresTokenRepository.apply
  )

  val layer: ZLayer[Any, Throwable, TokenRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
