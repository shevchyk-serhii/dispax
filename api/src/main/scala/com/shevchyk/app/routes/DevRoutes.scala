package com.shevchyk.app.routes

import com.shevchyk.core.config.Environment
import doobie.*
import doobie.implicits.*
import zio.*
import zio.http.*
import zio.interop.catz.*

/**
 * Development-only test support endpoint.
 *
 * `POST /api/dev/reset` truncates the transactional tables so an E2E run can start from a clean state. Guarded by
 * [[Environment.isDevelopment]] — it returns 403 in any other environment, so it can never run in production.
 *
 * This is what lets the fast single-bundle E2E run (no test orchestrator) stay isolated: each suite calls it before
 * touching data.
 */
object DevRoutes {

  // Transactional tables wiped on reset. Reference data (persons, companies,
  // drivers, tariffs, client_addresses, schedule_days) is left intact.
  private val resetSql: ConnectionIO[Int] =
    sql"""
      TRUNCATE rides, ride_ratings, blacklist_entries, expenses, geofences,
               chat_messages, invoices, ride_pools, emergency_reassignments,
               sent_reminders
      RESTART IDENTITY CASCADE
    """.update.run

  val routes: Routes[Transactor[Task], Response] = Routes(
    Method.POST / "api" / "dev" / "reset" -> handler { (_: Request) =>
      if (!Environment.isDevelopment)
        ZIO.succeed(Response(Status.Forbidden, body = Body.fromString("""{"error":"dev only"}""")))
      else
        ZIO
          .serviceWithZIO[Transactor[Task]](xa => resetSql.transact(xa))
          .as(Response.json("""{"status":"ok"}"""))
          .catchAll(ex =>
            ZIO
              .logError(s"dev reset failed: ${ex.getMessage}")
              .as(Response(Status.InternalServerError, body = Body.fromString("""{"error":"reset failed"}""")))
          )
    }
  )
}
