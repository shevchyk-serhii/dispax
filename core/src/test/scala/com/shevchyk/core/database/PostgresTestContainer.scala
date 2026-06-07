package com.shevchyk.core.database

import com.dimafeng.testcontainers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import doobie.Transactor
import zio.*
import zio.interop.catz.*

object PostgresTestContainer {

  /**
   * Starts a PostgreSQL container, runs Flyway migrations (production schema only), and provides a Transactor.
   */
  val layer: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer.scoped {
    for {
      container <-
        ZIO.acquireRelease(ZIO.attempt {
          val c = PostgreSQLContainer(dockerImageNameOverride = DockerImageName.parse("postgres:16-alpine"))
          c.start()
          c
        })(c => ZIO.succeed(c.stop()))

      dbConfig = DatabaseConfig(
                   driver = "org.postgresql.Driver",
                   url = container.jdbcUrl,
                   user = container.username,
                   password = container.password,
                   maxPoolSize = 5,
                   minIdle = 1
                 )

      flyway = FlywayServiceImpl(dbConfig, "production")
      _     <- flyway.migrate()

      ec <- ZIO.descriptor.map(_.executor.asExecutionContext)
      ds <- ZIO.attempt {
              val hc = new com.zaxxer.hikari.HikariConfig()
              hc.setDriverClassName(dbConfig.driver)
              hc.setJdbcUrl(dbConfig.url)
              hc.setUsername(dbConfig.user)
              hc.setPassword(dbConfig.password)
              hc.setMaximumPoolSize(dbConfig.maxPoolSize)
              hc.setMinimumIdle(dbConfig.minIdle)
              new com.zaxxer.hikari.HikariDataSource(hc)
            }
      xa  = Transactor.fromDataSource[Task](ds, ec)
    } yield xa
  }
}
