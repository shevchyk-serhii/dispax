package com.shevchyk.core.domain

import zio.test.*
import java.util.UUID

/**
 * Unit tests for the provisional ("from-chat / walk-in") client factory. The discriminating test is the unique-email
 * one: two provisional clients created in a row must NOT collide on email — otherwise the second INSERT would fail the
 * `persons.email UNIQUE` constraint. Mutate the synthetic email to a constant and this suite goes red.
 */
object ProvisionalClientSpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.randomUUID())

  def spec =
    suite("Person.provisionalClient")(
      test("is a provisional Client carrying the creator's companyId and a non-login placeholder password") {
        val p = Person.provisionalClient(name = None, phone = None, companyId = companyId)
        assertTrue(
          p.provisional,
          p.role == PersonRole.Client,
          p.companyId.contains(companyId),
          p.passwordHash == Person.ProvisionalPasswordPlaceholder,
          p.passwordHash.nonEmpty
        )
      },
      test("two provisional clients get distinct, unique synthetic emails (no UNIQUE collision)") {
        val a = Person.provisionalClient(name = None, phone = None, companyId = companyId)
        val b = Person.provisionalClient(name = None, phone = None, companyId = companyId)
        assertTrue(
          a.email != b.email,
          a.id != b.id,
          a.email.startsWith("provisional+"),
          a.email.endsWith("@chat.dispax.local")
        )
      },
      test("uses the supplied name and phone when present") {
        val p = Person.provisionalClient(name = Some("From Chat"), phone = Some("+49 170 1"), companyId = companyId)
        assertTrue(p.name == "From Chat", p.phone.contains("+49 170 1"))
      },
      test("falls back to the Walk-in placeholder name when name is blank") {
        val blank = Person.provisionalClient(name = Some("   "), phone = None, companyId = companyId)
        val empty = Person.provisionalClient(name = None, phone = None, companyId = companyId)
        assertTrue(
          blank.name == Person.ProvisionalDefaultName,
          empty.name == Person.ProvisionalDefaultName
        )
      }
    )
