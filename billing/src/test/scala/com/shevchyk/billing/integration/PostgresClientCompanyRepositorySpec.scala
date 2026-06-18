package com.shevchyk.billing.integration

import com.shevchyk.billing.repository.PostgresClientCompanyRepository
import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

object PostgresClientCompanyRepositorySpec extends ZIOSpecDefault {

  val testCompanyId: CompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000c1"))

  private def seedCompany(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO companies (id, name, email)
          VALUES (${testCompanyId.value}, 'ClientRepo Test GmbH', 'clientrepo@test.com')
          ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def clean(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM client_companies WHERE taxi_company_id = ${testCompanyId.value}".update.run.transact(xa).unit

  private def makeReq(
      name: String,
      email: Option[String] = Some("test@example.com"),
      phone: Option[String] = Some("+49 89 0000"),
      address: Option[String] = Some("Teststraße 1, München")
  ): CreateClientCompanyRequest = CreateClientCompanyRequest(
    name = name,
    email = email,
    phone = phone,
    address = address
  )

  def spec =
    suite("PostgresClientCompanyRepository")(
      test("findById returns None for unknown id") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedCompany(xa)
          repo = PostgresClientCompanyRepository(xa)
          res <- repo.findById(ClientCompanyId(UUID.randomUUID()))
        } yield assertTrue(res.isEmpty)
      },
      test("create round-trip: findById returns the inserted row") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- clean(xa)
          repo     = PostgresClientCompanyRepository(xa)
          created <- repo.create(makeReq("Acme GmbH"), testCompanyId)
          fetched <- repo.findById(created.id)
        } yield assertTrue(
          fetched.isDefined,
          fetched.exists(_.name == "Acme GmbH"),
          fetched.exists(_.taxiCompanyId == testCompanyId),
          fetched.exists(_.email.contains("test@example.com")),
          fetched.exists(_.phone.contains("+49 89 0000")),
          fetched.exists(_.address.contains("Teststraße 1, München"))
        )
      },
      test("create with all optional fields None stores None values") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- clean(xa)
          repo     = PostgresClientCompanyRepository(xa)
          created <- repo.create(
                       CreateClientCompanyRequest(name = "Minimal GmbH", email = None, phone = None, address = None),
                       testCompanyId
                     )
          fetched <- repo.findById(created.id)
        } yield assertTrue(
          fetched.isDefined,
          fetched.exists(_.name == "Minimal GmbH"),
          fetched.exists(_.email.isEmpty),
          fetched.exists(_.phone.isEmpty),
          fetched.exists(_.address.isEmpty)
        )
      },
      test("findByTaxiCompany returns rows ordered by name") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompany(xa)
          _     <- clean(xa)
          repo   = PostgresClientCompanyRepository(xa)
          _     <- repo.create(makeReq("Zeta GmbH"), testCompanyId)
          _     <- repo.create(makeReq("Alpha GmbH"), testCompanyId)
          found <- repo.findByTaxiCompany(testCompanyId)
        } yield assertTrue(
          found.length == 2,
          found.head.name == "Alpha GmbH",
          found.last.name == "Zeta GmbH"
        )
      },
      test("findByTaxiCompany returns empty list for unknown company") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          repo = PostgresClientCompanyRepository(xa)
          res <- repo.findByTaxiCompany(CompanyId(UUID.randomUUID()))
        } yield assertTrue(res.isEmpty)
      },
      test("update happy path returns updated row") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- clean(xa)
          repo     = PostgresClientCompanyRepository(xa)
          created <- repo.create(makeReq("Original GmbH"), testCompanyId)
          updated <- repo.update(created.id, testCompanyId, makeReq("Updated GmbH", email = Some("new@example.com")))
        } yield assertTrue(
          updated.isDefined,
          updated.exists(_.name == "Updated GmbH"),
          updated.exists(_.email.contains("new@example.com"))
        )
      },
      test("update with foreign taxiCompanyId returns None and leaves row unchanged (tenant isolation)") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedCompany(xa)
          _        <- clean(xa)
          repo      = PostgresClientCompanyRepository(xa)
          created  <- repo.create(makeReq("Original GmbH"), testCompanyId)
          result   <- repo.update(created.id, CompanyId(UUID.randomUUID()), makeReq("Hijacked GmbH"))
          original <- repo.findById(created.id)
        } yield assertTrue(
          result.isEmpty,
          original.exists(_.name == "Original GmbH")
        )
      },
      test("delete happy path removes the row") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- clean(xa)
          repo     = PostgresClientCompanyRepository(xa)
          created <- repo.create(makeReq("ToDelete GmbH"), testCompanyId)
          deleted <- repo.delete(created.id, testCompanyId)
          fetched <- repo.findById(created.id)
        } yield assertTrue(
          deleted,
          fetched.isEmpty
        )
      },
      test("delete with foreign taxiCompanyId returns false and leaves row intact (tenant isolation)") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedCompany(xa)
          _       <- clean(xa)
          repo     = PostgresClientCompanyRepository(xa)
          created <- repo.create(makeReq("ShouldStay GmbH"), testCompanyId)
          result  <- repo.delete(created.id, CompanyId(UUID.randomUUID()))
          fetched <- repo.findById(created.id)
        } yield assertTrue(
          !result,
          fetched.isDefined
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
