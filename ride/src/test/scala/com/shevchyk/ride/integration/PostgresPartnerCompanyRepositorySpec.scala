package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.PartnerCompany
import com.shevchyk.ride.repository.PostgresPartnerCompanyRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Integration tests for PostgresPartnerCompanyRepository against a real PostgreSQL database via Testcontainers.
 *
 * Covers:
 *   - create + findById round-trip (same company → found)
 *   - findById from different company → None (tenant isolation)
 *   - findByCompany scoping
 *   - ordering by name
 */
object PostgresPartnerCompanyRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000040-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000040-0000-0000-0000-000000000002"))

  private def seedCompanies(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'PartnerTest GmbH', 'partnertest@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${otherCompanyId.value}, 'Other GmbH', 'other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanPartnerCompanies(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM partner_companies".update.run.transact(xa).unit

  private def makePartnerCompany(
      id: PartnerCompanyId = PartnerCompanyId.generate(),
      name: String = "Test Partner GmbH",
      taxiCompanyId: CompanyId = testCompanyId,
      email: Option[String] = Some("partner@example.com"),
      phone: Option[String] = Some("+49123456789"),
      address: Option[String] = Some("Hauptstraße 1, Munich")
  ): PartnerCompany = PartnerCompany(
    id = id,
    name = name,
    email = email,
    phone = phone,
    address = address,
    taxiCompanyId = taxiCompanyId,
    createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS),
    updatedAt = Instant.now().truncatedTo(ChronoUnit.MICROS)
  )

  def spec =
    suite("PostgresPartnerCompanyRepository")(
      test("create and findById round-trip — same company → found") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanPartnerCompanies(xa)
          repo   = PostgresPartnerCompanyRepository(xa)
          pc     = makePartnerCompany()
          _     <- repo.create(pc)
          found <- repo.findById(pc.id, testCompanyId)
        } yield assertTrue(
          found.isDefined,
          found.get.id == pc.id,
          found.get.name == pc.name,
          found.get.email == pc.email,
          found.get.phone == pc.phone,
          found.get.address == pc.address,
          found.get.taxiCompanyId == testCompanyId
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanPartnerCompanies(xa)
          repo   = PostgresPartnerCompanyRepository(xa)
          found <- repo.findById(PartnerCompanyId(UUID.randomUUID()), testCompanyId)
        } yield assertTrue(found.isEmpty)
      },
      test("findById — different company → None (tenant isolation) [CRITICAL]") {
        // Creates a partner company for testCompanyId; a lookup by otherCompanyId must return None.
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanPartnerCompanies(xa)
          repo   = PostgresPartnerCompanyRepository(xa)
          pc     = makePartnerCompany(taxiCompanyId = testCompanyId)
          _     <- repo.create(pc)
          found <- repo.findById(pc.id, otherCompanyId) // ← wrong tenant
        } yield assertTrue(found.isEmpty)
      },
      test("create with all optional fields None stores None values") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanPartnerCompanies(xa)
          repo   = PostgresPartnerCompanyRepository(xa)
          pc     = makePartnerCompany(email = None, phone = None, address = None)
          _     <- repo.create(pc)
          found <- repo.findById(pc.id, testCompanyId)
        } yield assertTrue(
          found.isDefined,
          found.get.email.isEmpty,
          found.get.phone.isEmpty,
          found.get.address.isEmpty
        )
      },
      test("findByCompany returns only own-company rows, ordered by name") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedCompanies(xa)
          _    <- cleanPartnerCompanies(xa)
          repo  = PostgresPartnerCompanyRepository(xa)
          pc1   = makePartnerCompany(name = "Zeta Partner")
          pc2   = makePartnerCompany(name = "Alpha Partner")
          pc3   = makePartnerCompany(name = "Other Partner", taxiCompanyId = otherCompanyId)
          _    <- repo.create(pc1)
          _    <- repo.create(pc2)
          _    <- repo.create(pc3)
          list <- repo.findByCompany(testCompanyId)
        } yield assertTrue(
          list.length == 2,
          list.map(_.name) == List("Alpha Partner", "Zeta Partner"),
          list.forall(_.taxiCompanyId == testCompanyId)
        )
      },
      test("findByCompany returns empty list for unknown company") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedCompanies(xa)
          _    <- cleanPartnerCompanies(xa)
          repo  = PostgresPartnerCompanyRepository(xa)
          list <- repo.findByCompany(CompanyId(UUID.randomUUID()))
        } yield assertTrue(list.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
