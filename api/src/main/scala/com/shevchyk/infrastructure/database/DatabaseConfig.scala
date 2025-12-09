package com.shevchyk.infrastructure.database

import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*

case class DatabaseConfig(
    driver: String,
    url: String,
    user: String,
    password: String,
    hikari: HikariConfig
)

case class HikariConfig(
    maximumPoolSize: Int,
    minimumIdle: Int,
    connectionTimeout: Long,
    idleTimeout: Long,
    maxLifetime: Long
)

case class FlywayConfig(
    locations: List[String],
    baselineOnMigrate: Boolean
)

case class ServerConfig(
    port: Int
)

case class AppConfig(
    database: DatabaseConfig,
    flyway: FlywayConfig,
    server: ServerConfig
)

object DatabaseConfig:

  val layer: ZLayer[Any, Config.Error, DatabaseConfig] = ZLayer.fromZIO(
    read(deriveConfig[AppConfig].from(TypesafeConfigProvider.fromResourcePath()))
      .map(_.database)
  )
