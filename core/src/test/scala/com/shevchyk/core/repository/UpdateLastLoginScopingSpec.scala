package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*

import java.util.UUID

/**
 * Unit tests (in-memory double) for the tenant scoping of `PersonRepository.updateLastLogin` — the same
 * defense-in-depth "AND company_id" guard the setAvatar/deleteAvatar neighbours already carry: a scoped write for a
 * person of another company must be a no-op, while the person's own company (or None for company-less SuperAdmins)
 * records the login.
 */
object UpdateLastLoginScopingSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000a1"))
  private val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000b1"))

  private def person(companyId: Option[CompanyId]): Person = Person(
    id = PersonId(UUID.randomUUID()),
    name = "Login Person",
    email = s"login-${UUID.randomUUID()}@test.com",
    role = PersonRole.Client,
    companyId = companyId
  )

  def spec =
    suite("PersonRepository.updateLastLogin tenant scoping (in-memory)")(
      test("scoped to the person's own company: lastLoginAt is set") {
        val repo = new InMemoryPersonRepository
        val p    = person(Some(companyA))
        for {
          _     <- repo.create(p)
          _     <- repo.updateLastLogin(p.id, Some(companyA))
          found <- repo.findById(p.id)
        } yield assertTrue(found.exists(_.lastLoginAt.isDefined))
      },
      test("scoped to a FOREIGN company: no-op, lastLoginAt stays empty") {
        val repo = new InMemoryPersonRepository
        val p    = person(Some(companyA))
        for {
          _     <- repo.create(p)
          _     <- repo.updateLastLogin(p.id, Some(companyB))
          found <- repo.findById(p.id)
        } yield assertTrue(found.exists(_.lastLoginAt.isEmpty))
      },
      test("unscoped (None): a company-less person (SuperAdmin) still records the login") {
        val repo = new InMemoryPersonRepository
        val p    = person(None)
        for {
          _     <- repo.create(p)
          _     <- repo.updateLastLogin(p.id, None)
          found <- repo.findById(p.id)
        } yield assertTrue(found.exists(_.lastLoginAt.isDefined))
      }
    )
