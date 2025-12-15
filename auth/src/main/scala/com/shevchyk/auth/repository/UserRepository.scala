package com.shevchyk.auth.repository

import com.shevchyk.auth.domain.*
import com.shevchyk.database.DatabaseConfig
import doobie.Transactor
import zio.*

trait UserRepository:
  def create(user: User): Task[User]
  def findById(id: Long): Task[Option[User]]
  def findByEmail(email: String): Task[Option[User]]
  def findAll(): Task[List[User]]
  def findByRole(role: UserRole): Task[List[User]]
  def findByStatus(status: UserStatus): Task[List[User]]
  def update(user: User): Task[User]
  def delete(id: Long): Task[Unit]
  def searchByQuery(query: String): Task[List[User]]

object UserRepository:
  def create(user: User): ZIO[UserRepository, Throwable, User] = ZIO.serviceWithZIO[UserRepository](_.create(user))

  def findById(id: Long): ZIO[UserRepository, Throwable, Option[User]] = ZIO.serviceWithZIO[UserRepository](
    _.findById(id)
  )

  def findByEmail(email: String): ZIO[UserRepository, Throwable, Option[User]] = ZIO.serviceWithZIO[UserRepository](
    _.findByEmail(email)
  )

  def findAll(): ZIO[UserRepository, Throwable, List[User]] = ZIO.serviceWithZIO[UserRepository](_.findAll())

  def findByRole(role: UserRole): ZIO[UserRepository, Throwable, List[User]] = ZIO.serviceWithZIO[UserRepository](
    _.findByRole(role)
  )

  def findByStatus(status: UserStatus): ZIO[UserRepository, Throwable, List[User]] = ZIO.serviceWithZIO[UserRepository](
    _.findByStatus(status)
  )

  def update(user: User): ZIO[UserRepository, Throwable, User] = ZIO.serviceWithZIO[UserRepository](_.update(user))

  def delete(id: Long): ZIO[UserRepository, Throwable, Unit] = ZIO.serviceWithZIO[UserRepository](_.delete(id))

  def searchByQuery(query: String): ZIO[UserRepository, Throwable, List[User]] = ZIO.serviceWithZIO[UserRepository](
    _.searchByQuery(query)
  )

  val postgresLayer: ZLayer[Transactor[Task], Nothing, UserRepository] = ZLayer.fromFunction(
    PostgresUserRepository.apply
  )

  val layer: ZLayer[Any, Throwable, UserRepository] = DatabaseConfig.liveTransactor >>> postgresLayer
