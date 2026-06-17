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

  // Arbitrary fixed key identifying the global integration-test DB lock.
  private val AdvisoryLockKey: Long = 0x2451d57aL

  /**
   * Runs Flyway `migrate()` against the shared container exactly once per JVM.
   *
   * `make test` forks a JVM per module, so this `lazy val` fires on the first
   * spec of each module: it brings the reused container's schema up to date
   * (essential — a container left over from an older schema version would
   * otherwise be stale), and every subsequent spec in the same JVM skips the
   * Flyway connect + migrate entirely. The migration runs while the caller holds
   * the advisory lock (see [[layer]]), so two module JVMs never migrate the
   * shared container concurrently.
   */
  private lazy val migratedOnce: Unit = {
    val c = sharedContainer
    val dbConfig = DatabaseConfig(
      driver = "org.postgresql.Driver",
      url = c.jdbcUrl,
      user = c.username,
      password = c.password,
      maxPoolSize = 1,
      minIdle = 0
    )
    Unsafe.unsafe { implicit u =>
      zio.Runtime.default.unsafe
        .run(FlywayServiceImpl(dbConfig, "production").migrate())
        .getOrThrowFiberFailure()
    }
  }

  /**
   * Serialises spec access to the shared database with a session-level Postgres
   * advisory lock, held for a spec's whole lifetime (acquire→release of the
   * Transactor scope) on a dedicated connection.
   *
   * Why a DB lock and not an in-JVM Semaphore: zio-test runs a module's spec
   * classes concurrently, AND `make test` runs each module's tests in its own
   * forked JVM. All of them attach to the one reusable container, so an in-memory
   * permit only serialises specs within a single JVM — specs in different module
   * JVMs still raced on the shared `public` schema, where one spec's startup
   * [[resetDatabase]] TRUNCATE wiped a neighbour's just-inserted fixtures
   * (random FK violations / "database gone"). A `pg_advisory_lock` lives in the
   * database, so it serialises every spec process-wide.
   */
  private def advisoryLock(jdbcUrl: String, user: String, password: String): ZIO[Scope, Throwable, Unit] =
    ZIO.acquireRelease(
      ZIO.attempt {
        // Ensure the JDBC driver is registered: in a freshly-forked module JVM it
        // may not be loaded yet when we open this raw connection.
        Class.forName("org.postgresql.Driver")
        val conn = java.sql.DriverManager.getConnection(jdbcUrl, user, password)
        conn.createStatement().execute(s"SELECT pg_advisory_lock($AdvisoryLockKey)")
        conn
      }
    )(conn =>
      ZIO
        .attempt {
          try conn.createStatement().execute(s"SELECT pg_advisory_unlock($AdvisoryLockKey)")
          finally conn.close()
        }
        .ignore
    ).unit

  /**
   * Provides a Transactor backed by the shared container, running Flyway migrations (production schema only) to ensure
   * the schema is present. The Hikari pool is closed when the layer is released so per-spec pools don't pile up against
   * the shared container.
   */
  val layer: ZLayer[Any, Throwable, Transactor[Task]] = ZLayer.scoped {
    for {
      container <- ZIO.attempt(sharedContainer)
      // Hold exclusive DB access for this spec's whole lifetime (released with the
      // scope) via a process-wide Postgres advisory lock, so concurrently-scheduled
      // specs — even in other module JVMs — can't race on the shared schema.
      _         <- advisoryLock(container.jdbcUrl, container.username, container.password)

      dbConfig = DatabaseConfig(
                   driver = "org.postgresql.Driver",
                   url = container.jdbcUrl,
                   user = container.username,
                   password = container.password,
                   maxPoolSize = 5,
                   minIdle = 1
                 )

      // Migrate the shared container once per JVM (memoised). Forced here, under
      // the advisory lock, so two module JVMs never migrate concurrently and
      // every spec after the first skips the Flyway connect + migrate.
      _  <- ZIO.attempt(migratedOnce)

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
