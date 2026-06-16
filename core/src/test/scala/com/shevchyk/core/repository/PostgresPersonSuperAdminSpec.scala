package com.shevchyk.core.repository

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration test: insert a Person with role super_admin and company_id = NULL, read back, assert role ==
 * PersonRole.SuperAdmin and companyId == None.
 *
 * This validates that:
 *   1. The Doobie pgEnumString mapping handles "super_admin" ↔ PersonRole.SuperAdmin. 2. The PostgreSQL column allows
 *      NULL for company_id (SuperAdmin sits outside tenants).
 */
object PostgresPersonSuperAdminSpec extends ZIOSpecDefault:

  private val superAdminId = PersonId(UUID.fromString("a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0ff"))

  private def cleanSuperAdminPerson(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM persons WHERE id = ${superAdminId.value}".update.run.transact(xa).unit

  def spec =
    suite("PostgresPersonRepository — SuperAdmin special cases")(
      test("insert super_admin with NULL company_id and read back correctly") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- cleanSuperAdminPerson(xa)
          repo   = PostgresPersonRepository(xa)
          // Create a SuperAdmin person with companyId = None (platform-level user)
          person = Person(
                     id = superAdminId,
                     name = "Platform SuperAdmin",
                     email = "superadmin-test@dispax-integration.de",
                     role = PersonRole.SuperAdmin,
                     companyId = None, // ← this is the critical assertion target
                     passwordHash = "bcrypt-placeholder"
                   )
          _     <- repo.create(person)
          found <- repo.findById(superAdminId)
        } yield assertTrue(
          found.isDefined,
          found.get.role == PersonRole.SuperAdmin,
          found.get.companyId.isEmpty,
          found.get.name == "Platform SuperAdmin"
        )
      },
      test("findByRole returns SuperAdmin persons") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- cleanSuperAdminPerson(xa)
          repo    = PostgresPersonRepository(xa)
          person  = Person(
                      id = superAdminId,
                      name = "Platform SuperAdmin",
                      email = "superadmin-test2@dispax-integration.de",
                      role = PersonRole.SuperAdmin,
                      companyId = None,
                      passwordHash = "bcrypt-placeholder"
                    )
          _      <- repo.create(person)
          supers <- repo.findByRole(PersonRole.SuperAdmin)
        } yield assertTrue(
          supers.exists(_.id == superAdminId),
          supers.forall(_.role == PersonRole.SuperAdmin)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
