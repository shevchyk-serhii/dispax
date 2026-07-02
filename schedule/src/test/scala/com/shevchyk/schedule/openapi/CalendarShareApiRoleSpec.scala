package com.shevchyk.schedule.openapi

import com.shevchyk.auth.middleware.AuthenticatedUser
import sttp.model.StatusCode
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the CalendarShareApi role gate: calendar sharing is a staff feature (Driver/Dispatcher/Admin); clients
 * and secretaries must get a 403 before any share logic runs.
 */
object CalendarShareApiRoleSpec extends ZIOSpecDefault:

  private val userId = UUID.fromString("00000002-0000-0000-0000-000000000042")

  def spec =
    suite("CalendarShareApi role checks")(
      test("driver passes requireStaffRole") {
        val user = AuthenticatedUser(userId, "e@e.com", "DRIVER", roles = Set("DRIVER"))
        CalendarShareApi.requireStaffRole(user).map(_ => assertCompletes)
      },
      test("dispatcher passes requireStaffRole") {
        val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER"))
        CalendarShareApi.requireStaffRole(user).map(_ => assertCompletes)
      },
      test("admin (legacy empty roles) passes requireStaffRole") {
        val user = AuthenticatedUser(userId, "e@e.com", "ADMIN", roles = Set.empty)
        CalendarShareApi.requireStaffRole(user).map(_ => assertCompletes)
      },
      test("client fails requireStaffRole with 403") {
        val user = AuthenticatedUser(userId, "e@e.com", "CLIENT", roles = Set("CLIENT"))
        CalendarShareApi.requireStaffRole(user).flip.map { case (status, _) =>
          assertTrue(status == StatusCode.Forbidden)
        }
      },
      test("secretary fails requireStaffRole with 403") {
        val user = AuthenticatedUser(userId, "e@e.com", "SECRETARY", roles = Set("SECRETARY"))
        CalendarShareApi.requireStaffRole(user).flip.map { case (status, _) =>
          assertTrue(status == StatusCode.Forbidden)
        }
      },
      test("secretary-driver multi-role passes (Driver among effective roles)") {
        val user = AuthenticatedUser(userId, "e@e.com", "SECRETARY", roles = Set("SECRETARY", "DRIVER"))
        CalendarShareApi.requireStaffRole(user).map(_ => assertCompletes)
      }
    )
