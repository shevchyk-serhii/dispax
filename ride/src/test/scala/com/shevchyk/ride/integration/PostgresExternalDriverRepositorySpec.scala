package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.{ExternalDriver, PartnerCompany}
import com.shevchyk.ride.repository.{PostgresExternalDriverRepository, PostgresPartnerCompanyRepository}
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
 * Integration tests for PostgresExternalDriverRepository against a real PostgreSQL database via Testcontainers.
 *
 * Covers:
 *   - create + findById round-trip (same company → found)
 *   - findById from different company → None (tenant isolation)
 *   - findByCompany scoping and ordering
 *   - optional partnerCompanyId FK
 */
object PostgresExternalDriverRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000050-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000050-0000-0000-0000-000000000002"))

  private def seedCompanies(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'ExtDriverTest GmbH', 'extdrivertest@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${otherCompanyId.value}, 'OtherED GmbH', 'othered@example.com')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanExternalDrivers(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM external_drivers".update.run.transact(xa).unit

  private def cleanPartnerCompanies(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM partner_companies".update.run.transact(xa).unit

  private def makeExternalDriver(
      id: ExternalDriverId = ExternalDriverId.generate(),
      name: String = "Klaus Extern",
      taxiCompanyId: CompanyId = testCompanyId,
      phone: Option[String] = Some("+4989123456"),
      partnerCompanyId: Option[PartnerCompanyId] = None
  ): ExternalDriver = ExternalDriver(
    id = id,
    name = name,
    phone = phone,
    partnerCompanyId = partnerCompanyId,
    taxiCompanyId = taxiCompanyId,
    createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS),
    updatedAt = Instant.now().truncatedTo(ChronoUnit.MICROS)
  )

  private def seedPartnerCompany(xa: Transactor[Task], companyId: CompanyId): Task[PartnerCompanyId] = {
    val pcId = PartnerCompanyId.generate()
    val pc   = PartnerCompany(
      id = pcId,
      name = "Seed Partner GmbH",
      taxiCompanyId = companyId,
      createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS),
      updatedAt = Instant.now().truncatedTo(ChronoUnit.MICROS)
    )
    PostgresPartnerCompanyRepository(xa).create(pc).as(pcId)
  }

  def spec =
    suite("PostgresExternalDriverRepository")(
      test("create and findById round-trip — same company → found") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanExternalDrivers(xa)
          repo   = PostgresExternalDriverRepository(xa)
          ed     = makeExternalDriver()
          _     <- repo.create(ed)
          found <- repo.findById(ed.id, testCompanyId)
        } yield assertTrue(
          found.isDefined,
          found.get.id == ed.id,
          found.get.name == ed.name,
          found.get.phone == ed.phone,
          found.get.taxiCompanyId == testCompanyId,
          found.get.partnerCompanyId.isEmpty
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanExternalDrivers(xa)
          repo   = PostgresExternalDriverRepository(xa)
          found <- repo.findById(ExternalDriverId(UUID.randomUUID()), testCompanyId)
        } yield assertTrue(found.isEmpty)
      },
      test("findById — different company → None (tenant isolation) [CRITICAL]") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanExternalDrivers(xa)
          repo   = PostgresExternalDriverRepository(xa)
          ed     = makeExternalDriver(taxiCompanyId = testCompanyId)
          _     <- repo.create(ed)
          found <- repo.findById(ed.id, otherCompanyId) // ← wrong tenant
        } yield assertTrue(found.isEmpty)
      },
      test("create with partnerCompanyId FK stores and reads back the FK") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanExternalDrivers(xa)
          _     <- cleanPartnerCompanies(xa)
          pcId  <- seedPartnerCompany(xa, testCompanyId)
          repo   = PostgresExternalDriverRepository(xa)
          ed     = makeExternalDriver(partnerCompanyId = Some(pcId))
          _     <- repo.create(ed)
          found <- repo.findById(ed.id, testCompanyId)
        } yield assertTrue(
          found.isDefined,
          found.get.partnerCompanyId.contains(pcId)
        )
      },
      test("findByCompany returns only own-company rows, ordered by name") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedCompanies(xa)
          _    <- cleanExternalDrivers(xa)
          repo  = PostgresExternalDriverRepository(xa)
          ed1   = makeExternalDriver(name = "Zebra Driver")
          ed2   = makeExternalDriver(name = "Alpha Driver")
          ed3   = makeExternalDriver(name = "Other Driver", taxiCompanyId = otherCompanyId)
          _    <- repo.create(ed1)
          _    <- repo.create(ed2)
          _    <- repo.create(ed3)
          list <- repo.findByCompany(testCompanyId)
        } yield assertTrue(
          list.length == 2,
          list.map(_.name) == List("Alpha Driver", "Zebra Driver"),
          list.forall(_.taxiCompanyId == testCompanyId)
        )
      },
      test("findByCompany returns empty list for unknown company") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedCompanies(xa)
          _    <- cleanExternalDrivers(xa)
          repo  = PostgresExternalDriverRepository(xa)
          list <- repo.findByCompany(CompanyId(UUID.randomUUID()))
        } yield assertTrue(list.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
