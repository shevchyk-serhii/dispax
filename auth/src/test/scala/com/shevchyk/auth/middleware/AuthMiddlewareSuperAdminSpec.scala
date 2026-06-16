package com.shevchyk.auth.middleware

import zio.*
import zio.test.*
import java.util.UUID

/**
 * Unit tests for AuthMiddleware.isSuperAdmin.
 *
 * isSuperAdmin must return true only for the SUPER_ADMIN role (case-insensitive) and
 * false for every other role, including Admin — the closest non-SuperAdmin role.
 */
object AuthMiddlewareSuperAdminSpec extends ZIOSpecDefault:

  private val userId    = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val companyId = UUID.fromString("00000000-0000-0000-0000-000000000010")

  private def user(role: String, cid: Option[UUID] = Some(companyId)): AuthenticatedUser =
    AuthenticatedUser(userId, "test@example.com", role, cid, None)

  def spec =
    suite("AuthMiddleware.isSuperAdmin")(
      suite("returns true only for SuperAdmin role")(
        test("returns true for 'SUPER_ADMIN' (uppercase canonical form)") {
          assertTrue(AuthMiddleware.isSuperAdmin(user("SUPER_ADMIN")))
        },
        test("returns true for 'super_admin' (lowercase DB form)") {
          assertTrue(AuthMiddleware.isSuperAdmin(user("super_admin")))
        },
        test("returns true for 'Super_Admin' (mixed case)") {
          assertTrue(AuthMiddleware.isSuperAdmin(user("Super_Admin")))
        },
        test("returns true for 'SuperAdmin' (PascalCase from JWT encoder)") {
          // The JWT role is stored as the .toString of the PersonRole enum case
          // which produces "SuperAdmin" before the JSON encoder normalises it.
          // isSuperAdmin must handle this transitional form.
          assertTrue(AuthMiddleware.isSuperAdmin(user("SuperAdmin")))
        }
      ),
      suite("returns false for every other role")(
        test("returns false for Admin") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("ADMIN")))
        },
        test("returns false for Admin (mixed case)") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("Admin")))
        },
        test("returns false for Dispatcher") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("DISPATCHER")))
        },
        test("returns false for Driver") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("DRIVER")))
        },
        test("returns false for Client") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("CLIENT")))
        },
        test("returns false for Secretary") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("SECRETARY")))
        },
        test("returns false for ClientSecretary") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("CLIENT_SECRETARY")))
        },
        test("returns false for empty string") {
          assertTrue(!AuthMiddleware.isSuperAdmin(user("")))
        },
        test("returns false for SuperAdmin with companyId=None does not auto-grant") {
          // Having companyId=None alone must NOT make a user a SuperAdmin.
          // The role check is primary; companyId is irrelevant.
          assertTrue(!AuthMiddleware.isSuperAdmin(user("ADMIN", cid = None)))
        }
      )
    )
