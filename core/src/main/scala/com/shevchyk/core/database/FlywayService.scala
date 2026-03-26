package com.shevchyk.core.database

import org.flywaydb.core.Flyway
import zio.*

trait FlywayService:
  def migrate(): ZIO[Any, Throwable, Int]

class FlywayServiceImpl(config: DatabaseConfig, environment: String = "development") extends FlywayService:

  override def migrate(): ZIO[Any, Throwable, Int] =
    for {
      _        <- ZIO.logInfo(s"🛠️ Running migrations for environment: $environment")
      locations = {
        val baseLocations = Array("classpath:db/migration")
        environment.toLowerCase match {
          case "production" => baseLocations
          case _            => baseLocations ++ Array("classpath:db/migration-dev")
        }
      }
      _        <- ZIO.logInfo(s"📁 Migration locations: ${locations.mkString(", ")}")
      result   <- ZIO.attempt {
                    val flyway = Flyway
                      .configure()
                      .dataSource(config.url, config.user, config.password)
                      .locations(locations: _*)
                      .baselineOnMigrate(true)
                      .outOfOrder(true)
                      .load()

                    flyway.migrate().migrationsExecuted
                  }
    } yield result

object FlywayService:

  val live: ZLayer[DatabaseConfig, Nothing, FlywayService] = ZLayer.fromFunction((config: DatabaseConfig) =>
    FlywayServiceImpl(config)
  )

  def withEnvironment(env: String): ZLayer[DatabaseConfig, Nothing, FlywayService] = ZLayer.fromFunction(
    (config: DatabaseConfig) => FlywayServiceImpl(config, env)
  )

  val production: ZLayer[DatabaseConfig, Nothing, FlywayService]  = withEnvironment("production")
  val development: ZLayer[DatabaseConfig, Nothing, FlywayService] = withEnvironment("development")
