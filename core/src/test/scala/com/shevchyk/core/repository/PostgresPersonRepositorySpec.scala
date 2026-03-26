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

/** Integration tests for PostgresPersonRepository against a real PostgreSQL database via Testcontainers. */
object PostgresPersonRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))

  private def seedCompany(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'test@example.com')
          ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def cleanPersons(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM persons".update.run.transact(xa).unit

  private def makePerson(
      role: PersonRole = PersonRole.Client,
      name: String = "Test Person",
      email: String = s"test-${UUID.randomUUID()}@example.com",
      isVip: Boolean = false
  ): Person = Person(
    id = PersonId(UUID.randomUUID()),
    name = name,
    email = email,
    role = role,
    companyId = Some(testCompanyId),
    isVip = isVip
  )

  def spec = suite("PostgresPersonRepository")(
    test("create and findById round-trip") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        _      <- seedCompany(xa)
        _      <- cleanPersons(xa)
        repo    = PostgresPersonRepository(xa)
        person  = makePerson(name = "Alice", email = "alice@test.com")
        _      <- repo.create(person)
        found  <- repo.findById(person.id)
      } yield assertTrue(
        found.isDefined,
        found.get.name == "Alice",
        found.get.email == "alice@test.com",
        found.get.role == PersonRole.Client,
        found.get.companyId.contains(testCompanyId)
      )
    },

    test("findByEmail") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
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
        xa   <- ZIO.service[Transactor[Task]]
        _    <- cleanPersons(xa)
        repo  = PostgresPersonRepository(xa)
        _    <- repo.create(makePerson(role = PersonRole.Driver, email = "d1@test.com"))
        _    <- repo.create(makePerson(role = PersonRole.Driver, email = "d2@test.com"))
        _    <- repo.create(makePerson(role = PersonRole.Client, email = "c1@test.com"))
        drivers <- repo.findByRole(PersonRole.Driver)
        clients <- repo.findByRole(PersonRole.Client)
      } yield assertTrue(
        drivers.length == 2,
        clients.length == 1
      )
    },

    test("findByRoleAndCompany isolates by company") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- cleanPersons(xa)
        repo  = PostgresPersonRepository(xa)
        _    <- repo.create(makePerson(role = PersonRole.Driver, email = "d@test.com"))
        other = CompanyId(UUID.randomUUID())
        drivers     <- repo.findByRoleAndCompany(PersonRole.Driver, testCompanyId)
        otherResult <- repo.findByRoleAndCompany(PersonRole.Driver, other)
      } yield assertTrue(
        drivers.length == 1,
        otherResult.isEmpty
      )
    },

    test("update modifies fields") {
      for {
        xa      <- ZIO.service[Transactor[Task]]
        _       <- cleanPersons(xa)
        repo     = PostgresPersonRepository(xa)
        person   = makePerson(name = "Before", email = "update@test.com")
        _       <- repo.create(person)
        updated  = person.copy(name = "After", isVip = true)
        _       <- repo.update(updated)
        found   <- repo.findById(person.id)
      } yield assertTrue(
        found.get.name == "After",
        found.get.isVip
      )
    },

    test("delete removes person") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        _      <- cleanPersons(xa)
        repo    = PostgresPersonRepository(xa)
        person  = makePerson(email = "delete@test.com")
        _      <- repo.create(person)
        _      <- repo.delete(person.id)
        found  <- repo.findById(person.id)
      } yield assertTrue(found.isEmpty)
    },

    test("VIP with preferred driver round-trip") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        _      <- cleanPersons(xa)
        repo    = PostgresPersonRepository(xa)
        driver  = makePerson(role = PersonRole.Driver, email = "pdriver@test.com")
        _      <- repo.create(driver)
        vip     = makePerson(
                    name = "VIP Client",
                    email = "vip@test.com",
                    isVip = true
                  ).copy(preferredDriverId = Some(driver.id))
        _      <- repo.create(vip)
        found  <- repo.findById(vip.id)
      } yield assertTrue(
        found.get.isVip,
        found.get.preferredDriverId.contains(driver.id)
      )
    }

  ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
