package com.shevchyk.ride.openapi

import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.core.domain.PersonRole
import sttp.model.StatusCode
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the RideSecure role checks. Regression coverage for the multi-role bug where the ride secure layer
 * only looked at the primary `user.role` and ignored the full `roles` set — a dispatcher who can also drive was wrongly
 * rejected (403) on driver ride endpoints. Also covers `toPersonRole` so the two multi-word wire roles
 * (CLIENT_SECRETARY, SUPER_ADMIN) no longer collapse into Client.
 */
object RideSecureSpec extends ZIOSpecDefault:

  private val userId  = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val otherId = UUID.fromString("00000003-0000-0000-0000-000000000003")

  def spec =
    suite("RideSecure")(
      suite("checkRole multi-role")(
        test("dispatcher-driver passes checkRole for DRIVER (regression for the multi-role bug)") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          RideSecure.checkRole(user, "DRIVER").map(_ => assertCompletes)
        },
        test("dispatcher-driver still passes checkRole for DISPATCHER") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          RideSecure.checkRole(user, "DISPATCHER").map(_ => assertCompletes)
        },
        test("pure dispatcher fails checkRole for DRIVER with 403") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER"))
          RideSecure.checkRole(user, "DRIVER").flip.map { case (status, _) =>
            assertTrue(status == StatusCode.Forbidden)
          }
        },
        test("legacy token (empty roles) falls back to the primary role") {
          val user = AuthenticatedUser(userId, "e@e.com", "DRIVER", roles = Set.empty)
          RideSecure.checkRole(user, "DRIVER").map(_ => assertCompletes)
        }
      ),
      suite("checkRoleOrOwner multi-role")(
        test("dispatcher-driver passes via the DRIVER role even when not the owner") {
          val user = AuthenticatedUser(userId, "e@e.com", "DISPATCHER", roles = Set("DISPATCHER", "DRIVER"))
          RideSecure.checkRoleOrOwner(user, otherId, "DRIVER").map(_ => assertCompletes)
        },
        test("non-matching role still passes when the user is the owner") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT", roles = Set("CLIENT"))
          RideSecure.checkRoleOrOwner(user, userId, "DRIVER").map(_ => assertCompletes)
        },
        test("wrong role and not owner fails with 403") {
          val user = AuthenticatedUser(userId, "e@e.com", "CLIENT", roles = Set("CLIENT"))
          RideSecure.checkRoleOrOwner(user, otherId, "DRIVER").flip.map { case (status, _) =>
            assertTrue(status == StatusCode.Forbidden)
          }
        }
      ),
      suite("toPersonRole wire-format")(
        test("CLIENT_SECRETARY maps to ClientSecretary (not Client)") {
          assertTrue(RideSecure.toPersonRole("CLIENT_SECRETARY") == PersonRole.ClientSecretary)
        },
        test("SUPER_ADMIN maps to SuperAdmin (not Client)") {
          assertTrue(RideSecure.toPersonRole("SUPER_ADMIN") == PersonRole.SuperAdmin)
        },
        test("DRIVER maps to Driver") {
          assertTrue(RideSecure.toPersonRole("DRIVER") == PersonRole.Driver)
        },
        test("unknown role falls back to the least-privileged Client") {
          assertTrue(RideSecure.toPersonRole("NOT_A_ROLE") == PersonRole.Client)
        }
      )
    )
