package com.shevchyk.database

import org.flywaydb.core.Flyway
import zio.*

trait FlywayService:
  def migrate(): ZIO[Any, Throwable, Int]

class FlywayServiceImpl(config: DatabaseConfig) extends FlywayService:

  override def migrate(): ZIO[Any, Throwable, Int] = ZIO.attempt {
    val flyway = Flyway
      .configure()
      .dataSource(config.url, config.user, config.password)
      .locations("classpath:db/migration")
      .baselineOnMigrate(true)
      .load()

    flyway.migrate().migrationsExecuted
  }

object FlywayService:
  val live: ZLayer[DatabaseConfig, Nothing, FlywayService] = ZLayer.fromFunction(FlywayServiceImpl.apply)
