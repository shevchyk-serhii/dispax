package com.shevchyk.schedule.openapi

import com.shevchyk.auth.middleware.AuthenticatedUser
import sttp.model.StatusCode
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the ScheduleApi role checks. Regression coverage for the multi-role bug: the schedule secure layer
 * only looked at the primary `user.role`. A dispatcher who can also drive was wrongly treated as non-driver, locking
 * them out of driver-self schedule actions (e.g. marking their own unavailability).
 */
object ScheduleApiRoleSpec extends ZIOSpecDefault:

  private val userId = UUID.fromString("00000002-0000-0000-0000-000000000002")

  def spec =
    suite("ScheduleApi role checks")(
      suite("requireDispatcherOrAdmin multi-role")(
        test("dispatcher-driver passes requireDispatcherOrAdmin") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          ScheduleApi.requireDispatcherOrAdmin(user).map(_ => assertCompletes)
        },
        test("admin (legacy empty roles) passes requireDispatcherOrAdmin") {
          val user = AuthenticatedUser(userId, "e@e.com", "ADMIN", roles = Set.empty)
          ScheduleApi.requireDispatcherOrAdmin(user).map(_ => assertCompletes)
        },
        test("pure driver fails requireDispatcherOrAdmin with 403") {
          val user = AuthenticatedUser(userId, "e@e.com", "DRIVER", roles = Set("DRIVER"))
          ScheduleApi.requireDispatcherOrAdmin(user).flip.map { case (status, _) =>
            assertTrue(status == StatusCode.Forbidden)
          }
        }
      ),
      suite("driverSelfRole (multi-role) — drives the driver-only-self service check")(
        test("dispatcher-driver resolves to DRIVER so they can mark their own unavailability (regression)") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          assertTrue(ScheduleApi.driverSelfRole(user) == "DRIVER")
        },
        test("a pure driver resolves to DRIVER") {
          val user = AuthenticatedUser(userId, "e@e.com", "DRIVER", roles = Set("DRIVER"))
          assertTrue(ScheduleApi.driverSelfRole(user) == "DRIVER")
        },
        test("a non-driver keeps the primary role") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER"))
          assertTrue(ScheduleApi.driverSelfRole(user) == "DISPATCHER")
        }
      )
    )
