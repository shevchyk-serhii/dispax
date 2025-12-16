package com.shevchyk.database

import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*
import doobie.*
import doobie.hikari.{Config => DoobieConfig, *}
import doobie.util.transactor.Transactor
import com.zaxxer.hikari.{HikariConfig, HikariDataSource}
import cats.effect.IO
import zio.interop.catz.*
import scala.concurrent.ExecutionContext

case class DatabaseConfig(
    driver: String,
    url: String,
    user: String,
    password: String,
    maxPoolSize: Int = 10,
    minIdle: Int = 2
)

object DatabaseConfig {

  // Configuration descriptor for ZIO Config
  private val configDescriptor: Config[DatabaseConfig] = deriveConfig[DatabaseConfig].nested("database")

  // Layer that loads configuration from application.conf
  val layer: ZLayer[Any, Throwable, DatabaseConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  // Fallback layer with default configuration for development/testing
  val defaultLayer: ZLayer[Any, Nothing, DatabaseConfig] = ZLayer.succeed(
    DatabaseConfig(
      driver = "org.postgresql.Driver",
      url = "jdbc:postgresql://localhost:5432/oktopus",
      user = "oktopus",
      password = "oktopus"
    )
  )

  val transactorLayer: ZLayer[DatabaseConfig, Throwable, Transactor[Task]] = ZLayer.scoped {
    for {
      dbConfig    <- ZIO.service[DatabaseConfig]
      hikariConfig = new HikariConfig()
      _            = hikariConfig.setDriverClassName(dbConfig.driver)
      _            = hikariConfig.setJdbcUrl(dbConfig.url)
      _            = hikariConfig.setUsername(dbConfig.user)
      _            = hikariConfig.setPassword(dbConfig.password)
      _            = hikariConfig.setMaximumPoolSize(dbConfig.maxPoolSize)
      _            = hikariConfig.setMinimumIdle(dbConfig.minIdle)
      dataSource  <- ZIO.fromAutoCloseable(ZIO.attempt(new HikariDataSource(hikariConfig)))
      ec          <- ZIO.descriptor.map(_.executor.asExecutionContext)
      transactor   = Transactor.fromDataSource[Task](dataSource, ec)
    } yield transactor
  }

  val transactorWithMigrations: ZLayer[DatabaseConfig & FlywayService, Throwable, Transactor[Task]] = ZLayer.scoped {
    for {
      flywayService <- ZIO.service[FlywayService]
      _             <- flywayService
                         .migrate()
                         .tapBoth(
                           err => ZIO.logError(s"Migration failed: ${err.getMessage}"),
                           count => ZIO.logInfo(s"Applied $count migrations successfully")
                         )
      dbConfig      <- ZIO.service[DatabaseConfig]
      hikariConfig   = new HikariConfig()
      _              = hikariConfig.setDriverClassName(dbConfig.driver)
      _              = hikariConfig.setJdbcUrl(dbConfig.url)
      _              = hikariConfig.setUsername(dbConfig.user)
      _              = hikariConfig.setPassword(dbConfig.password)
      _              = hikariConfig.setMaximumPoolSize(dbConfig.maxPoolSize)
      _              = hikariConfig.setMinimumIdle(dbConfig.minIdle)
      dataSource    <- ZIO.fromAutoCloseable(ZIO.attempt(new HikariDataSource(hikariConfig)))
      ec            <- ZIO.descriptor.map(_.executor.asExecutionContext)
      transactor     = Transactor.fromDataSource[Task](dataSource, ec)
    } yield transactor
  }

  val liveTransactor: ZLayer[Any, Throwable, Transactor[Task]] = layer.catchAll(_ => defaultLayer) >>> transactorLayer

  val liveTransactorWithMigrations: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer.makeSome[Any, Transactor[Task]](
    layer.catchAll(_ => defaultLayer),
    FlywayService.live,
    transactorWithMigrations
  )
}
