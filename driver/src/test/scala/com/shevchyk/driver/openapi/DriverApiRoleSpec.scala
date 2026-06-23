package com.shevchyk.driver.openapi

import com.shevchyk.auth.middleware.AuthenticatedUser
import sttp.model.StatusCode
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the DriverApi role checks. Regression coverage for the multi-role bug: the driver secure layer only
 * looked at the primary `user.role` and ignored the full `roles` set, so a dispatcher who can also drive was wrongly
 * rejected (403) on driver endpoints.
 */
object DriverApiRoleSpec extends ZIOSpecDefault:

  private val userId  = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val otherId = UUID.fromString("00000003-0000-0000-0000-000000000003")

  def spec =
    suite("DriverApi role checks")(
      suite("checkRole multi-role")(
        test("dispatcher-driver passes checkRole for DRIVER (regression)") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          DriverApi.checkRole(user, "DRIVER").map(_ => assertCompletes)
        },
        test("dispatcher-driver passes checkRole for DISPATCHER") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          DriverApi.checkRole(user, "DISPATCHER").map(_ => assertCompletes)
        },
        test("pure client fails checkRole for DISPATCHER with 403") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT", roles = Set("CLIENT"))
          DriverApi.checkRole(user, "DISPATCHER").flip.map { case (status, _) =>
            assertTrue(status == StatusCode.Forbidden)
          }
        }
      ),
      suite("checkRoleOrOwner multi-role")(
        test("dispatcher-driver passes via the DRIVER role even when not the owner") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          DriverApi.checkRoleOrOwner(user, otherId, "DRIVER").map(_ => assertCompletes)
        },
        test("wrong role and not owner fails with 403") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT", roles = Set("CLIENT"))
          DriverApi.checkRoleOrOwner(user, otherId, "DISPATCHER").flip.map { case (status, _) =>
            assertTrue(status == StatusCode.Forbidden)
          }
        }
      )
    )
