package com.shevchyk.core.database

import com.shevchyk.core.config.Environment
import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*
import doobie.util.transactor.Transactor
import com.zaxxer.hikari.{HikariConfig, HikariDataSource}
import zio.interop.catz.*

case class DatabaseConfig(
    driver: String,
    url: String,
    user: String,
    password: String,
    maxPoolSize: Int = 10,
    minIdle: Int = 2,
    // Hikari timeouts (milliseconds). Defaults mirror Hikari's own defaults but are made explicit
    // and env-overridable so production can tune them: connectionTimeout caps how long a request
    // waits for a free connection before failing fast; maxLifetime/idleTimeout recycle connections.
    connectionTimeoutMs: Long = 30000,
    idleTimeoutMs: Long = 600000,
    maxLifetimeMs: Long = 1800000
)

object DatabaseConfig {

  private val configDescriptor: Config[DatabaseConfig] = deriveConfig[DatabaseConfig].nested("database")

  /**
   * Builds a fully-configured Hikari pool from a DatabaseConfig. Single source of truth so the pool settings (and
   * timeouts) cannot drift between the migrating and non-migrating transactors.
   */
  private def buildHikari(dbConfig: DatabaseConfig): HikariConfig =
    val hc = new HikariConfig()
    hc.setDriverClassName(dbConfig.driver)
    hc.setJdbcUrl(dbConfig.url)
    hc.setUsername(dbConfig.user)
    hc.setPassword(dbConfig.password)
    hc.setMaximumPoolSize(dbConfig.maxPoolSize)
    hc.setMinimumIdle(dbConfig.minIdle)
    hc.setConnectionTimeout(dbConfig.connectionTimeoutMs)
    hc.setIdleTimeout(dbConfig.idleTimeoutMs)
    hc.setMaxLifetime(dbConfig.maxLifetimeMs)
    hc

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
      dbConfig   <- ZIO.service[DatabaseConfig]
      dataSource <- ZIO.fromAutoCloseable(ZIO.attempt(new HikariDataSource(buildHikari(dbConfig))))
      ec         <- ZIO.descriptor.map(_.executor.asExecutionContext)
      transactor  = Transactor.fromDataSource[Task](dataSource, ec)
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
      dataSource    <- ZIO.fromAutoCloseable(ZIO.attempt(new HikariDataSource(buildHikari(dbConfig))))
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
