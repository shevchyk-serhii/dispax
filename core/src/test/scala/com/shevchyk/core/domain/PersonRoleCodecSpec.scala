package com.shevchyk.core.domain

import zio.json.*
import zio.test.*

/**
 * Unit tests for PersonRole JSON codec covering the new SuperAdmin variant.
 */
object PersonRoleCodecSpec extends ZIOSpecDefault:

  def spec =
    suite("PersonRole JSON codec")(
      suite("encode")(
        test("Driver encodes to 'DRIVER'") {
          assertTrue(PersonRole.Driver.toJson == "\"DRIVER\"")
        },
        test("Admin encodes to 'ADMIN'") {
          assertTrue(PersonRole.Admin.toJson == "\"ADMIN\"")
        },
        test("ClientSecretary encodes to 'CLIENT_SECRETARY' — not 'CLIENTSECRETARY' (mutation guard)") {
          val wire = PersonRole.toWire(PersonRole.ClientSecretary)
          assertTrue(wire == "CLIENT_SECRETARY" && wire != "CLIENTSECRETARY")
        },
        test("SuperAdmin encodes to 'SUPER_ADMIN' — not 'SUPERADMIN' (mutation guard)") {
          val wire = PersonRole.toWire(PersonRole.SuperAdmin)
          assertTrue(wire == "SUPER_ADMIN" && wire != "SUPERADMIN")
        },
        test("ClientSecretary JSON encode is exact 'CLIENT_SECRETARY'") {
          assertTrue(PersonRole.ClientSecretary.toJson == "\"CLIENT_SECRETARY\"")
        },
        test("SuperAdmin JSON encode is exact 'SUPER_ADMIN'") {
          assertTrue(PersonRole.SuperAdmin.toJson == "\"SUPER_ADMIN\"")
        }
      ),
      suite("decode")(
        test("'SUPER_ADMIN' decodes to SuperAdmin") {
          assertTrue("\"SUPER_ADMIN\"".fromJson[PersonRole] == Right(PersonRole.SuperAdmin))
        },
        test("'super_admin' (DB form) decodes to SuperAdmin") {
          assertTrue("\"super_admin\"".fromJson[PersonRole] == Right(PersonRole.SuperAdmin))
        },
        test("'ADMIN' decodes to Admin — not SuperAdmin (mutation guard)") {
          assertTrue("\"ADMIN\"".fromJson[PersonRole] == Right(PersonRole.Admin))
        },
        test("'CLIENT_SECRETARY' decodes to ClientSecretary — not Client (mutation guard)") {
          assertTrue("\"CLIENT_SECRETARY\"".fromJson[PersonRole] == Right(PersonRole.ClientSecretary))
        },
        test("'client_secretary' lowercase decodes to ClientSecretary — not Client (legacy DB form)") {
          assertTrue("\"client_secretary\"".fromJson[PersonRole] == Right(PersonRole.ClientSecretary))
        },
        test("'SUPER_ADMIN' decodes to SuperAdmin — not Admin (mutation guard)") {
          val result = "\"SUPER_ADMIN\"".fromJson[PersonRole]
          assertTrue(result == Right(PersonRole.SuperAdmin) && result != Right(PersonRole.Admin))
        },
        test("unknown string decodes to Left") {
          val result = "\"NOT_A_ROLE\"".fromJson[PersonRole]
          assertTrue(result.isLeft)
        },
        test("empty string decodes to Left") {
          val result = "\"\"".fromJson[PersonRole]
          assertTrue(result.isLeft)
        }
      ),
      suite("roundtrip")(
        test("SuperAdmin encodes then decodes back to SuperAdmin") {
          val encoded = PersonRole.SuperAdmin.toJson
          val decoded = encoded.fromJson[PersonRole]
          assertTrue(decoded == Right(PersonRole.SuperAdmin))
        },
        test("All roles roundtrip without loss") {
          val roles   = List(
            PersonRole.Driver,
            PersonRole.Client,
            PersonRole.Secretary,
            PersonRole.Dispatcher,
            PersonRole.Admin,
            PersonRole.ClientSecretary,
            PersonRole.SuperAdmin
          )
          val results = roles.map(r => r.toJson.fromJson[PersonRole] == Right(r))
          assertTrue(results.forall(identity))
        }
      )
    )
