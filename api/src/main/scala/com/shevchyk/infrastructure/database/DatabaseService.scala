package com.shevchyk.infrastructure.database

import doobie.*
import doobie.hikari.HikariTransactor
import doobie.implicits.*
import org.flywaydb.core.Flyway
import zio.*
import zio.interop.catz.*
import com.zaxxer.hikari.HikariConfig
import java.util.concurrent.Executors

case class DatabaseService(transactor: Transactor[Task]):
  def xa: Transactor[Task] = transactor

object DatabaseService:

  def live: ZLayer[DatabaseConfig, Throwable, DatabaseService] = ZLayer.scoped {
    for
      config     <- ZIO.service[DatabaseConfig]
      transactor <- createTransactor(config)
      _          <- runMigrations(config)
    yield DatabaseService(transactor)
  }

  private def createTransactor(config: DatabaseConfig): ZIO[Scope, Throwable, Transactor[Task]] = ZIO.succeed(
    Transactor.fromDriverManager[Task](
      driver = config.driver,
      url = config.url,
      user = config.user,
      password = config.password,
      logHandler = None
    )
  )

  private def runMigrations(config: DatabaseConfig): ZIO[Any, Throwable, Unit] =
    ZIO.attemptBlocking {
      val flyway = Flyway
        .configure()
        .dataSource(config.url, config.user, config.password)
        .locations("classpath:db/migration")
        .baselineOnMigrate(true)
        .load()

      flyway.migrate()
    }.unit

  def test: ZLayer[Any, Nothing, DatabaseService] = ZLayer.succeed {
    val transactor = Transactor.fromDriverManager[Task](
      driver = "org.h2.Driver",
      url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1",
      user = "sa",
      password = "",
      logHandler = None
    )
    DatabaseService(transactor)
  }
