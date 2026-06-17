package com.shevchyk.core.database

import com.dimafeng.testcontainers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import doobie.*
import doobie.implicits.*
import zio.*
import zio.interop.catz.*

object PostgresTestContainer {

  /**
   * Wipes every application table in one TRUNCATE so a spec starts from a clean database, regardless of rows other
   * specs left behind in the shared (reused) container.
   *
   * Specs share one long-lived Postgres (see [[layer]]). With a fresh container per spec (the old behaviour) each spec
   * implicitly started from an empty DB; a neighbour's rows in other tables (e.g. emergency_reassignments referencing
   * rides) would otherwise violate FK constraints on a `DELETE FROM rides`, and findAll-style queries would observe
   * foreign fixture rows. [[layer]] calls this once when the spec acquires its Transactor, restoring that clean-start
   * guarantee; each spec's own per-test seed/cleanup then works exactly as before.
   *
   * The table list is read from pg_tables (excluding Flyway's history), so new migrations are covered automatically.
   * TRUNCATE ... CASCADE clears FK-dependent rows together; RESTART IDENTITY resets sequences. Specs run sequentially
   * (Test / parallelExecution := false), so a full wipe is safe.
   */
  def resetDatabase(xa: Transactor[Task]): Task[Unit] =
    for {
      tables <-
        sql"""SELECT tablename FROM pg_tables
              WHERE schemaname = 'public' AND tablename <> 'flyway_schema_history'"""
          .query[String]
          .to[List]
          .transact(xa)
      _      <-
        ZIO.when(tables.nonEmpty) {
          val list = tables.map(t => s""""$t"""").mkString(", ")
          Fragment.const(s"TRUNCATE TABLE $list RESTART IDENTITY CASCADE").update.run.transact(xa)
        }
    } yield ()

  /**
   * A single PostgreSQL container shared across every integration spec.
   *
   * Testcontainers `withReuse(true)` keeps the container alive between specs (and even between `sbt test` runs), so the
   * ~30 Postgres specs no longer pay a container start + Flyway migration each. Reuse is keyed by the container's
   * configuration plus the explicit label: the first spec starts it, the rest attach to the running one. We therefore
   * must NOT stop it in a release action — stopping would defeat reuse. Stale containers are cleaned by Docker / the
   * user.
   *
   * Reuse must be enabled on the host once via `~/.testcontainers.properties` → `testcontainers.reuse.enable=true` (the
   * Makefile's test targets ensure this). Without it Testcontainers logs a warning and falls back to a fresh container
   * per spec — correct, just slower.
   *
   * Specs isolate themselves by TRUNCATE-ing their tables up front, so sharing one long-lived database across specs is
   * safe. Flyway `migrate()` on an already-migrated schema is a no-op, so re-running it per spec is cheap.
   */
  private lazy val sharedContainer: PostgreSQLContainer = {
    val c = PostgreSQLContainer(dockerImageNameOverride = DockerImageName.parse("postgres:16-alpine"))
    c.container.withReuse(true)
    c.container.withLabel("com.shevchyk.dispax", "it-postgres")
    c.start()
    c
  }

  /**
   * Provides a Transactor backed by the shared container, running Flyway migrations (production schema only) to ensure
   * the schema is present. The Hikari pool is closed when the layer is released so per-spec pools don't pile up against
   * the shared container.
   */
  val layer: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer.scoped {
    for {
      container <- ZIO.attempt(sharedContainer)

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
      ds <-
        ZIO.acquireRelease(ZIO.attempt {
          val hc = new com.zaxxer.hikari.HikariConfig()
          hc.setDriverClassName(dbConfig.driver)
          hc.setJdbcUrl(dbConfig.url)
          hc.setUsername(dbConfig.user)
          hc.setPassword(dbConfig.password)
          hc.setMaximumPoolSize(dbConfig.maxPoolSize)
          hc.setMinimumIdle(dbConfig.minIdle)
          new com.zaxxer.hikari.HikariDataSource(hc)
        })(ds => ZIO.succeed(ds.close()))
      xa  = Transactor.fromDataSource[Task](ds, ec)
      // Start every spec from a clean DB — the shared container may hold rows
      // from previously-run specs. Specs run sequentially, so this is safe.
      _  <- resetDatabase(xa)
    } yield xa
  }
}
