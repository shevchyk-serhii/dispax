package com.shevchyk.app.routes

import doobie.*
import doobie.implicits.*
import zio.*
import zio.http.*
import zio.interop.catz.*

/**
 * Health endpoints, split into liveness and readiness so an orchestrator (Cloud Run, a load balancer, an uptime check)
 * can tell "the process is up" apart from "the process can actually serve traffic".
 *
 *   - `GET /health` — liveness. Cheap, dependency-free, always 200 while the JVM is running. Use for restart decisions.
 *   - `GET /health/ready` — readiness. Runs `SELECT 1` against PostgreSQL and returns 503 if the DB is unreachable.
 *     Point uptime checks and pre-traffic gating here, so a healthy process with a dead DB is reported as down rather
 *     than silently serving 500s.
 */
object HealthRoutes {

  // Minimal round-trip that forces a real connection from the pool and back.
  private val pingDb: ConnectionIO[Int] = sql"SELECT 1".query[Int].unique

  val routes: Routes[Transactor[Task], Response] = Routes(
    Method.GET / "health"           -> handler { (_: Request) =>
      ZIO.succeed(Response.text("Dispax Modular API - OK"))
    },
    Method.GET / "health" / "ready" -> handler { (_: Request) =>
      ZIO
        .serviceWithZIO[Transactor[Task]](xa => pingDb.transact(xa))
        .as(Response.json("""{"status":"ready"}"""))
        .catchAll { ex =>
          ZIO
            .logError(s"Readiness check failed: ${ex.getMessage}")
            .as(
              Response(
                Status.ServiceUnavailable,
                body = Body.fromString("""{"status":"not_ready","reason":"database_unavailable"}""")
              )
            )
        }
    }
  )
}
