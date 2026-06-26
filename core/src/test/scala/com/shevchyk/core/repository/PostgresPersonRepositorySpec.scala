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
 * Integration tests for PostgresPersonRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresPersonRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))

  private def seedCompany(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'test@example.com')
          ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  // TRUNCATE ... CASCADE clears persons together with rows that FK-reference it
  // (drivers, rides, etc.); a bare DELETE FROM persons fails on drivers_id_fkey.
  private def cleanPersons(xa: Transactor[Task]): Task[Unit] =
    sql"TRUNCATE persons RESTART IDENTITY CASCADE".update.run.transact(xa).unit

  private def makePerson(
      role: PersonRole = PersonRole.Client,
      name: String = "Test Person",
      email: String,
      isVip: Boolean = false
  ): Person = Person(
    id = PersonId(UUID.randomUUID()),
    name = name,
    email = email,
    role = role,
    companyId = Some(testCompanyId),
    isVip = isVip
  )

  def spec =
    suite("PostgresPersonRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(name = "Alice", email = "alice@test.com")
          _     <- repo.create(person)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.name == "Alice",
          found.get.email == "alice@test.com",
          found.get.role == PersonRole.Client,
          found.get.companyId.contains(testCompanyId)
        )
      },
      test("must_change_password round-trips and defaults to false") {
        for {
          xa           <- ZIO.service[Transactor[Task]]
          _            <- seedCompany(xa)
          _            <- cleanPersons(xa)
          repo          = PostgresPersonRepository(xa)
          // default false on a plainly-created person
          plain         = makePerson(email = "plain@test.com")
          _            <- repo.create(plain)
          plainFound   <- repo.findById(plain.id)
          // explicitly flagged person persists the flag, and clearing it via update persists too
          flagged       = makePerson(email = "flagged@test.com").copy(mustChangePassword = true)
          _            <- repo.create(flagged)
          flaggedFound <- repo.findById(flagged.id)
          _            <- repo.update(flagged.copy(mustChangePassword = false))
          clearedFound <- repo.findById(flagged.id)
        } yield assertTrue(
          plainFound.exists(!_.mustChangePassword),
          flaggedFound.exists(_.mustChangePassword),
          clearedFound.exists(!_.mustChangePassword)
        )
      },
      test("findByEmail") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(email = "unique@test.com")
          _      <- repo.create(person)
          found  <- repo.findByEmail("unique@test.com")
          absent <- repo.findByEmail("missing@test.com")
        } yield assertTrue(
          found.isDefined,
          found.get.id == person.id,
          absent.isEmpty
        )
      },
      test("findByRole filters correctly") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- cleanPersons(xa)
          repo     = PostgresPersonRepository(xa)
          _       <- repo.create(makePerson(role = PersonRole.Driver, email = "d1@test.com"))
          _       <- repo.create(makePerson(role = PersonRole.Driver, email = "d2@test.com"))
          _       <- repo.create(makePerson(role = PersonRole.Client, email = "c1@test.com"))
          drivers <- repo.findByRole(PersonRole.Driver)
          clients <- repo.findByRole(PersonRole.Client)
        } yield assertTrue(
          drivers.length == 2,
          clients.length == 1
        )
      },
      test("findByRoleAndCompany isolates by company") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedCompany(xa)
          _           <- cleanPersons(xa)
          repo         = PostgresPersonRepository(xa)
          _           <- repo.create(makePerson(role = PersonRole.Driver, email = "d@test.com"))
          other        = CompanyId(UUID.randomUUID())
          drivers     <- repo.findByRoleAndCompany(PersonRole.Driver, testCompanyId)
          otherResult <- repo.findByRoleAndCompany(PersonRole.Driver, other)
        } yield assertTrue(
          drivers.length == 1,
          otherResult.isEmpty
        )
      },
      test("update modifies fields") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(name = "Before", email = "update@test.com")
          _      <- repo.create(person)
          updated = person.copy(name = "After", isVip = true)
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.get.name == "After",
          found.get.isVip
        )
      },
      test("update modifies a person with a null company_id (SuperAdmin)") {
        // SuperAdmin is cross-tenant: company_id IS NULL. The WHERE clause must use
        // `IS NOT DISTINCT FROM` so that NULL matches NULL — `company_id = NULL` would
        // never match and the update would silently no-op.
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(role = PersonRole.SuperAdmin, name = "Before", email = "superadmin@test.com")
                      .copy(companyId = None)
          _      <- repo.create(person)
          updated = person.copy(name = "After", isVip = true)
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.companyId.isEmpty,
          found.get.name == "After",
          found.get.isVip
        )
      },
      test("delete removes person") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "delete@test.com")
          _     <- repo.create(person)
          _     <- repo.delete(person.id)
          found <- repo.findById(person.id)
        } yield assertTrue(found.isEmpty)
      },
      test("VIP with preferred driver round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          driver = makePerson(role = PersonRole.Driver, email = "pdriver@test.com")
          _     <- repo.create(driver)
          vip    = makePerson(
                     name = "VIP Client",
                     email = "vip@test.com",
                     isVip = true
                   ).copy(preferredDriverId = Some(driver.id))
          _     <- repo.create(vip)
          found <- repo.findById(vip.id)
        } yield assertTrue(
          found.get.isVip,
          found.get.preferredDriverId.contains(driver.id)
        )
      },
      // ── multi-role (dispatcher-can-drive) ──────────────────────────────
      test("create and findById round-trip preserves multi-role set") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          // Dispatcher who also drives: primary role = Dispatcher, roles = {Dispatcher, Driver}
          person = makePerson(role = PersonRole.Dispatcher, email = "dispdrv@test.com")
                     .copy(roles = Set(PersonRole.Dispatcher, PersonRole.Driver))
          _     <- repo.create(person)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.role == PersonRole.Dispatcher,
          found.get.effectiveRoles.contains(PersonRole.Dispatcher),
          found.get.effectiveRoles.contains(PersonRole.Driver),
          found.get.canDrive
        )
      },
      test("findByRoleAndCompany(Driver) returns dispatcher-driver") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedCompany(xa)
          _         <- cleanPersons(xa)
          repo       = PostgresPersonRepository(xa)
          dispDriver = makePerson(role = PersonRole.Dispatcher, email = "dd@test.com")
                         .copy(roles = Set(PersonRole.Dispatcher, PersonRole.Driver))
          pureDriver = makePerson(role = PersonRole.Driver, email = "pure@test.com")
          _         <- repo.create(dispDriver)
          _         <- repo.create(pureDriver)
          // searching for Driver role must return BOTH the pure driver and the dispatcher-driver
          drivers   <- repo.findByRoleAndCompany(PersonRole.Driver, testCompanyId)
        } yield assertTrue(
          drivers.length == 2,
          drivers.exists(_.id == dispDriver.id),
          drivers.exists(_.id == pureDriver.id)
        )
      },
      test("findByRoleAndCompany(Dispatcher) returns dispatcher-driver") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedCompany(xa)
          _           <- cleanPersons(xa)
          repo         = PostgresPersonRepository(xa)
          dispDriver   = makePerson(role = PersonRole.Dispatcher, email = "dd2@test.com")
                           .copy(roles = Set(PersonRole.Dispatcher, PersonRole.Driver))
          pureDisp     = makePerson(role = PersonRole.Dispatcher, email = "disp@test.com")
          _           <- repo.create(dispDriver)
          _           <- repo.create(pureDisp)
          dispatchers <- repo.findByRoleAndCompany(PersonRole.Dispatcher, testCompanyId)
        } yield assertTrue(
          dispatchers.length == 2,
          dispatchers.exists(_.id == dispDriver.id),
          dispatchers.exists(_.id == pureDisp.id)
        )
      },
      test("update preserves multi-role set") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(role = PersonRole.Dispatcher, email = "upddd@test.com")
                      .copy(roles = Set(PersonRole.Dispatcher, PersonRole.Driver))
          _      <- repo.create(person)
          updated = person.copy(name = "Updated")
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.get.name == "Updated",
          found.get.effectiveRoles == Set(PersonRole.Dispatcher, PersonRole.Driver)
        )
      },
      test("upsertDriverRow is idempotent") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          driver = makePerson(role = PersonRole.Driver, email = "upsert@test.com")
          _     <- repo.create(driver)
          // call twice — ON CONFLICT DO NOTHING must not throw
          _     <- repo.upsertDriverRow(driver.id)
          _     <- repo.upsertDriverRow(driver.id)
        } yield assertCompletes
      },
      // ── avatar (BYTEA) round-trip ──────────────────────────────────────────
      test("setAvatar + getAvatar round-trip — BYTEA survives write/read unchanged") {
        val bytes       = Array.tabulate(1024)(i => (i % 256).toByte)
        val contentType = "image/jpeg"
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "avatar-roundtrip@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, testCompanyId, bytes, contentType)
          found <- repo.getAvatar(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get._1.length == bytes.length,
          found.get._1.toSeq == bytes.toSeq,
          found.get._2 == contentType
        )
      },
      // ── avatar tenant isolation (defense-in-depth: AND company_id) ─────────
      test("setAvatar with a foreign company id is a no-op — avatar is not written") {
        val bytes        = Array.fill(256)(0x55.toByte)
        val otherCompany = CompanyId(UUID.fromString("00000099-0000-0000-0000-000000000099"))
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "avatar-foreign-set@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, otherCompany, bytes, "image/png")
          found <- repo.getAvatar(person.id)
        } yield assertTrue(found.isEmpty)
      },
      test("deleteAvatar with a foreign company id is a no-op — existing avatar survives") {
        val bytes        = Array.fill(256)(0x66.toByte)
        val otherCompany = CompanyId(UUID.fromString("00000099-0000-0000-0000-000000000099"))
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "avatar-foreign-del@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, testCompanyId, bytes, "image/png")
          _     <- repo.deleteAvatar(person.id, otherCompany)
          found <- repo.getAvatar(person.id)
        } yield assertTrue(found.isDefined)
      },
      test("getAvatar on person without avatar returns None") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "no-avatar@test.com")
          _     <- repo.create(person)
          found <- repo.getAvatar(person.id)
        } yield assertTrue(found.isEmpty)
      },
      test("deleteAvatar — subsequent getAvatar returns None") {
        val bytes = Array.fill(512)(0x7f.toByte)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "delete-avatar@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, testCompanyId, bytes, "image/png")
          _     <- repo.deleteAvatar(person.id, testCompanyId)
          found <- repo.getAvatar(person.id)
        } yield assertTrue(found.isEmpty)
      },
      test("deleteAvatar is idempotent — safe to call when no avatar exists") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "idempotent-delete@test.com")
          _     <- repo.create(person)
          // delete on a person with no avatar must not fail
          _     <- repo.deleteAvatar(person.id, testCompanyId)
          _     <- repo.deleteAvatar(person.id, testCompanyId)
        } yield assertCompletes
      },
      test("findById after setAvatar — avatarPresent == true") {
        // Verifies that the (avatar IS NOT NULL) AS has_avatar computed column is read correctly.
        val bytes = Array.fill(256)(0x01.toByte)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "has-avatar@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, testCompanyId, bytes, "image/webp")
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.avatarPresent
        )
      },
      test("findById before setAvatar — avatarPresent == false") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "no-avatar-flag@test.com")
          _     <- repo.create(person)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          !found.get.avatarPresent
        )
      },
      test("findById after deleteAvatar — avatarPresent reverts to false") {
        val bytes = Array.fill(128)(0x02.toByte)
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "avatar-flag-revert@test.com")
          _     <- repo.create(person)
          _     <- repo.setAvatar(person.id, testCompanyId, bytes, "image/jpeg")
          _     <- repo.deleteAvatar(person.id, testCompanyId)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          !found.get.avatarPresent
        )
      },
      // ── preferredLanguage round-trips (user-language-selection feature) ──
      test("create with preferredLanguage=Some(\"de\") — findById returns it") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "lang-de@test.com").copy(preferredLanguage = Some("de"))
          _     <- repo.create(person)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.preferredLanguage == Some("de")
        )
      },
      test("create with preferredLanguage=None — findById returns None") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- cleanPersons(xa)
          repo   = PostgresPersonRepository(xa)
          person = makePerson(email = "lang-none@test.com").copy(preferredLanguage = None)
          _     <- repo.create(person)
          found <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.preferredLanguage.isEmpty
        )
      },
      test("update changes preferredLanguage from None to Some(\"uk\") — findById sees new value") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(email = "lang-update@test.com").copy(preferredLanguage = None)
          _      <- repo.create(person)
          updated = person.copy(preferredLanguage = Some("uk"))
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.preferredLanguage == Some("uk")
        )
      },
      test("update changes preferredLanguage from Some(\"en\") to Some(\"de\")") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(email = "lang-change@test.com").copy(preferredLanguage = Some("en"))
          _      <- repo.create(person)
          updated = person.copy(preferredLanguage = Some("de"))
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.preferredLanguage == Some("de")
        )
      },
      test("update can clear preferredLanguage back to None") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(email = "lang-clear@test.com").copy(preferredLanguage = Some("en"))
          _      <- repo.create(person)
          updated = person.copy(preferredLanguage = None)
          _      <- repo.update(updated)
          found  <- repo.findById(person.id)
        } yield assertTrue(
          found.isDefined,
          found.get.preferredLanguage.isEmpty
        )
      },
      // Tenant-isolation integration guard: update is company-scoped (IS NOT DISTINCT FROM).
      // A person in another company must not have their language changed even when the ID is guessed.
      test("update is company-scoped — preferredLanguage update does not touch different-company row") {
        val companyB = CompanyId(UUID.randomUUID())
        for {
          xa      <- ZIO.service[Transactor[Task]]
          // Seed companyA via the shared seedCompany (testCompanyId), then seed companyB manually.
          _       <- seedCompany(xa)
          _       <-
            sql"""INSERT INTO companies (id, name, email)
                           VALUES (${companyB.value}, 'Company B', 'b@example.com')
                           ON CONFLICT DO NOTHING""".update.run.transact(xa)
          _       <- cleanPersons(xa)
          repo     = PostgresPersonRepository(xa)
          // Person belongs to companyA.
          personA  = makePerson(email = "isolated-lang@test.com")
                       .copy(companyId = Some(testCompanyId), preferredLanguage = Some("en"))
          _       <- repo.create(personA)
          // Attacker tries to update via a Person object referencing companyB.
          attacker = personA.copy(companyId = Some(companyB), preferredLanguage = Some("de"))
          _       <- repo.update(attacker)
          found   <- repo.findById(personA.id)
        } yield assertTrue(
          // Row must still have company A's language (SQL WHERE company_id IS NOT DISTINCT FROM
          // blocked the update because companyB != companyA).
          found.isDefined,
          found.get.preferredLanguage == Some("en")
        )
      },
      test("setAvatar stores different MIME types correctly (PNG, WebP)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- cleanPersons(xa)
          repo    = PostgresPersonRepository(xa)
          person  = makePerson(email = "mime-types@test.com")
          _      <- repo.create(person)
          _      <- repo.setAvatar(person.id, testCompanyId, Array(0x01.toByte), "image/png")
          found1 <- repo.getAvatar(person.id)
          _      <- repo.setAvatar(person.id, testCompanyId, Array(0x02.toByte), "image/webp")
          found2 <- repo.getAvatar(person.id)
        } yield assertTrue(
          found1.get._2 == "image/png",
          found2.get._2 == "image/webp"
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
