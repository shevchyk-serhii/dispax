package com.shevchyk.core.repository

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus, SubscriptionPlan}
import doobie.*
import doobie.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for [[PostgresCompanyRepository]] against a real PostgreSQL database via Testcontainers. DB is
 * never mocked — see dev-flow.md invariant #4.
 */
object PostgresCompanyRepositorySpec extends ZIOSpecDefault:

  private def clean(xa: Transactor[Task]): Task[Unit] =
    // TRUNCATE CASCADE avoids FK issues with persons that reference companies.
    // We only delete companies we created in tests to keep other fixture data intact.
    sql"DELETE FROM companies WHERE email LIKE '%@superadmin-test.de'".update.run.transact(xa).unit

  private def makeCompany(
      name: String = "Test Firma GmbH",
      email: String = s"test-${UUID.randomUUID()}@superadmin-test.de",
      status: CompanyStatus = CompanyStatus.Active,
      plan: SubscriptionPlan = SubscriptionPlan.Free
  ): Company = Company(
    id = CompanyId(UUID.randomUUID()),
    name = name,
    email = email,
    phone = "+491234567890",
    address = "Leopoldstraße 1, 80802 München",
    status = status,
    subscriptionPlan = plan
  )

  def spec =
    suite("PostgresCompanyRepository (integration)")(
      test("create and findById round-trip") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- clean(xa)
          repo     = PostgresCompanyRepository(xa)
          company  = makeCompany(name = "Roundtrip GmbH", email = "roundtrip@superadmin-test.de")
          created <- repo.create(company)
          found   <- repo.findById(created.id)
        } yield assertTrue(
          found.isDefined,
          found.get.name == "Roundtrip GmbH",
          found.get.status == CompanyStatus.Active,
          found.get.subscriptionPlan == SubscriptionPlan.Free,
          // create() must return real DB-generated timestamps, not Instant.EPOCH
          created.createdAt != Instant.EPOCH,
          created.updatedAt != Instant.EPOCH
        )
      },
      test("findAll returns all created companies (cross-tenant)") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- clean(xa)
          repo  = PostgresCompanyRepository(xa)
          c1    = makeCompany(name = "Alpha Taxi", email = "alpha@superadmin-test.de")
          c2    = makeCompany(name = "Beta Taxi", email = "beta@superadmin-test.de")
          _    <- repo.create(c1)
          _    <- repo.create(c2)
          all  <- repo.findAll()
          names = all.map(_.name)
        } yield assertTrue(
          names.contains("Alpha Taxi"),
          names.contains("Beta Taxi")
        )
      },
      test("update changes status and subscription plan") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- clean(xa)
          repo     = PostgresCompanyRepository(xa)
          company  = makeCompany(
                       name = "Update GmbH",
                       email = "update@superadmin-test.de",
                       status = CompanyStatus.Active,
                       plan = SubscriptionPlan.Free
                     )
          created <- repo.create(company)
          updated  = created.copy(status = CompanyStatus.Suspended, subscriptionPlan = SubscriptionPlan.Professional)
          _       <- repo.update(updated)
          found   <- repo.findById(created.id)
        } yield assertTrue(
          found.isDefined,
          found.get.status == CompanyStatus.Suspended,
          found.get.subscriptionPlan == SubscriptionPlan.Professional
        )
      },
      test("countByStatus returns correct counts per status") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- clean(xa)
          repo    = PostgresCompanyRepository(xa)
          _      <- repo.create(makeCompany(email = "cnt-a1@superadmin-test.de", status = CompanyStatus.Active))
          _      <- repo.create(makeCompany(email = "cnt-a2@superadmin-test.de", status = CompanyStatus.Active))
          _      <- repo.create(makeCompany(email = "cnt-s1@superadmin-test.de", status = CompanyStatus.Suspended))
          counts <- repo.countByStatus()
        } yield assertTrue(
          counts.getOrElse(CompanyStatus.Active, 0) >= 2,
          counts.getOrElse(CompanyStatus.Suspended, 0) >= 1
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          repo   = PostgresCompanyRepository(xa)
          found <- repo.findById(CompanyId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
