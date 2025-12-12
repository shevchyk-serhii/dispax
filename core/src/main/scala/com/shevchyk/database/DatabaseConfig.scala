package com.shevchyk.database

import zio.*
import doobie.*
import doobie.hikari.*
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

  // Hardcoded config for now - can be moved to external config later
  val defaultConfig = DatabaseConfig(
    driver = "org.postgresql.Driver",
    url = "jdbc:postgresql://localhost:5432/oktopus",
    user = "oktopus",
    password = "oktopus"
  )

  val layer: ZLayer[Any, Nothing, DatabaseConfig] = ZLayer.succeed(defaultConfig)

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

  val liveTransactor: ZLayer[Any, Throwable, Transactor[Task]] = layer >>> transactorLayer
}
