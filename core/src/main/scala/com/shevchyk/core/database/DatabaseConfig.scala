package com.shevchyk.core.database

import com.shevchyk.core.config.Environment
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

  private val configDescriptor: Config[DatabaseConfig] = deriveConfig[DatabaseConfig].nested("database")

  val layer: ZLayer[Any, Throwable, DatabaseConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  val defaultLayer: ZLayer[Any, Nothing, DatabaseConfig] = ZLayer.succeed(
    DatabaseConfig(
      driver = "org.postgresql.Driver",
      url = sys.env.getOrElse("DB_URL", "jdbc:postgresql://localhost:5432/dispax"),
      user = sys.env.getOrElse("DB_USER", "dispax"),
      password = sys.env.getOrElse("DB_PASSWORD", "dispax")
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

  val productionTransactorWithMigrations: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer
    .makeSome[Any, Transactor[Task]](
      layer.catchAll(_ => defaultLayer),
      FlywayService.production,
      transactorWithMigrations
    )

  private val developmentTransactorWithMigrations: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer
    .makeSome[Any, Transactor[Task]](
      layer.catchAll(_ => defaultLayer),
      FlywayService.development,
      transactorWithMigrations
    )

  // Switches between production (schema only) and development (with seed data) based on the single
  // environment selector (APP_ENV via Environment.current).
  val liveTransactorWithMigrations: ZLayer[Any, Throwable, Transactor[Task]] =
    if Environment.isProduction then productionTransactorWithMigrations
    else developmentTransactorWithMigrations
}
