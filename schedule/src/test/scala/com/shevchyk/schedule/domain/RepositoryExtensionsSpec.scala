package com.shevchyk.schedule.domain

import com.shevchyk.schedule.domain.RepositoryExtensions.*
import zio.*
import zio.test.*

object RepositoryExtensionsSpec extends ZIOSpecDefault {

  def spec =
    suite("RepositoryExtensions")(
      test("mapDatabaseError maps Throwable to ScheduleError.DatabaseError on failure") {
        val boom: IO[Throwable, String] = ZIO.fail(new RuntimeException("db down"))
        boom.mapDatabaseError.flip.map { err =>
          assertTrue(err.isInstanceOf[ScheduleError.DatabaseError])
        }
      },
      test("mapDatabaseError preserves the original exception") {
        val ex                          = new RuntimeException("original cause")
        val boom: IO[Throwable, String] = ZIO.fail(ex)
        boom.mapDatabaseError.flip.map {
          case ScheduleError.DatabaseError(cause) => assertTrue(cause == ex)
          case _                                  => assertTrue(false)
        }
      },
      test("mapDatabaseError does not affect successful values") {
        val ok: IO[Throwable, String] = ZIO.succeed("schedule-ok")
        ok.mapDatabaseError.map(v => assertTrue(v == "schedule-ok"))
      }
    )
}
