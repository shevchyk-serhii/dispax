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
 * Integration tests for PostgresClientCompanyRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresClientCompanyRepositorySpec extends ZIOSpecDefault {

  val taxiCompanyId = CompanyId(UUID.fromString("0000000C-0000-0000-0000-000000000001"))
  val otherTaxiId   = CompanyId(UUID.fromString("0000000C-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${taxiCompanyId.value}, 'Taxi One GmbH', 'taxi1@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherTaxiId.value}, 'Taxi Two GmbH', 'taxi2@example.com')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanClientCompanies(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM client_companies".update.run.transact(xa).unit

  private def makeClientCompany(
      taxi: CompanyId = taxiCompanyId,
      name: String = "Acme Corp"
  ): ClientCompany = ClientCompany(
    id = ClientCompanyId(UUID.randomUUID()),
    name = name,
    taxiCompanyId = taxi,
    email = Some("acme@example.com"),
    phone = Some("+49 89 12345"),
    address = Some("Marienplatz 1, Munich")
  )

  def spec =
    suite("PostgresClientCompanyRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanClientCompanies(xa)
          repo   = PostgresClientCompanyRepository(xa)
          cc     = makeClientCompany()
          _     <- repo.create(cc)
          found <- repo.findById(cc.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == cc.id,
          found.get.name == "Acme Corp",
          found.get.taxiCompanyId == taxiCompanyId,
          found.get.email.contains("acme@example.com"),
          found.get.phone.contains("+49 89 12345"),
          found.get.address.contains("Marienplatz 1, Munich")
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanClientCompanies(xa)
          repo   = PostgresClientCompanyRepository(xa)
          found <- repo.findById(ClientCompanyId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("findByTaxiCompany returns only matching taxi company, ordered by name") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanClientCompanies(xa)
          repo   = PostgresClientCompanyRepository(xa)
          c1     = makeClientCompany(taxi = taxiCompanyId, name = "Zeta")
          c2     = makeClientCompany(taxi = taxiCompanyId, name = "Alpha")
          cOther = makeClientCompany(taxi = otherTaxiId, name = "Beta")
          _     <- repo.create(c1)
          _     <- repo.create(c2)
          _     <- repo.create(cOther)
          mine  <- repo.findByTaxiCompany(taxiCompanyId)
          empty <- repo.findByTaxiCompany(CompanyId(UUID.randomUUID()))
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.taxiCompanyId == taxiCompanyId),
          mine.map(_.name) == List("Alpha", "Zeta"),
          empty.isEmpty
        )
      },
      test("update changes mutable fields") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanClientCompanies(xa)
          repo    = PostgresClientCompanyRepository(xa)
          cc      = makeClientCompany()
          _      <- repo.create(cc)
          updated = cc.copy(
                      name = "Acme Renamed",
                      email = Some("new@example.com"),
                      phone = None,
                      address = Some("New Addr")
                    )
          _      <- repo.update(updated)
          found  <- repo.findById(cc.id)
        } yield assertTrue(
          found.isDefined,
          found.get.name == "Acme Renamed",
          found.get.email.contains("new@example.com"),
          found.get.phone.isEmpty,
          found.get.address.contains("New Addr")
        )
      },
      test("delete removes row and returns true once") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanClientCompanies(xa)
          repo    = PostgresClientCompanyRepository(xa)
          cc      = makeClientCompany()
          _      <- repo.create(cc)
          first  <- repo.delete(cc.id)
          second <- repo.delete(cc.id)
          found  <- repo.findById(cc.id)
        } yield assertTrue(
          first,
          !second,
          found.isEmpty
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
