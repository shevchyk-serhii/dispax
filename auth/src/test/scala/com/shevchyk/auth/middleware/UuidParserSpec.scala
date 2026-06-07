package com.shevchyk.auth.middleware

import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*
import java.util.UUID

object UuidParserSpec extends ZIOSpecDefault {

  private val validUuid = "550e8400-e29b-41d4-a716-446655440000"

  def spec =
    suite("UuidParser")(
      suite("parse")(
        test("parses valid UUID string") {
          UuidParser.parse(validUuid).map(u => assertTrue(u == UUID.fromString(validUuid)))
        },
        test("fails with 400 for invalid UUID") {
          UuidParser.parse("not-a-uuid").flip.map(r => assertTrue(r.status == Status.BadRequest))
        },
        test("fails with 400 for empty string") {
          UuidParser.parse("").flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("parsePersonId")(
        test("wraps UUID in PersonId") {
          UuidParser.parsePersonId(validUuid).map(id => assertTrue(id == PersonId(UUID.fromString(validUuid))))
        },
        test("fails for invalid input") {
          UuidParser.parsePersonId("bad").flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("parseRideId")(
        test("wraps UUID in RideId") {
          UuidParser.parseRideId(validUuid).map(id => assertTrue(id == RideId(UUID.fromString(validUuid))))
        },
        test("fails for invalid input") {
          UuidParser.parseRideId("bad").flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("parseCompanyId")(
        test("wraps UUID in CompanyId") {
          UuidParser.parseCompanyId(validUuid).map(id => assertTrue(id == CompanyId(UUID.fromString(validUuid))))
        },
        test("fails for invalid input") {
          UuidParser.parseCompanyId("bad").flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("parseClientCompanyId")(
        test("wraps UUID in ClientCompanyId") {
          UuidParser
            .parseClientCompanyId(validUuid)
            .map(id => assertTrue(id == ClientCompanyId(UUID.fromString(validUuid))))
        },
        test("fails for invalid input") {
          UuidParser.parseClientCompanyId("bad").flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("requireCompanyId")(
        test("returns CompanyId when present") {
          val uuid = UUID.randomUUID()
          UuidParser.requireCompanyId(Some(uuid)).map(id => assertTrue(id == CompanyId(uuid)))
        },
        test("fails with 400 when None") {
          UuidParser.requireCompanyId(None).flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      ),
      suite("requireClientCompanyId")(
        test("returns ClientCompanyId when present") {
          val uuid = UUID.randomUUID()
          UuidParser.requireClientCompanyId(Some(uuid)).map(id => assertTrue(id == ClientCompanyId(uuid)))
        },
        test("fails with 400 when None") {
          UuidParser.requireClientCompanyId(None).flip.map(r => assertTrue(r.status == Status.BadRequest))
        }
      )
    )
}
