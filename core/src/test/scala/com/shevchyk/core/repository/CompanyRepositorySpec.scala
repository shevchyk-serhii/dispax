package com.shevchyk.core.repository

import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus, SubscriptionPlan}
import zio.*
import zio.test.*

import java.util.UUID

/**
 * Unit tests for CompanyRepository using the in-memory double. These tests do NOT touch PostgreSQL — for Postgres
 * integration see PostgresCompanyRepositorySpec.
 */
object CompanyRepositorySpec extends ZIOSpecDefault:

  private def makeCompany(
      name: String,
      email: String = "info@test.de",
      status: CompanyStatus = CompanyStatus.Active,
      plan: SubscriptionPlan = SubscriptionPlan.Free
  ): Company = Company(
    id = CompanyId(UUID.randomUUID()),
    name = name,
    email = email,
    phone = "+491234567890",
    address = "Leopoldstraße 1, München",
    status = status,
    subscriptionPlan = plan
  )

  def spec =
    suite("InMemoryCompanyRepository")(
      test("findAll returns all inserted companies") {
        for {
          repo <- ZIO.service[CompanyRepository]
          c1    = makeCompany(name = "Alpha GmbH")
          c2    = makeCompany(name = "Beta GmbH")
          _    <- repo.create(c1)
          _    <- repo.create(c2)
          all  <- repo.findAll()
        } yield assertTrue(
          all.length == 2,
          all.exists(_.id == c1.id),
          all.exists(_.id == c2.id)
        )
      },
      test("findById returns the company when it exists") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          company = makeCompany(name = "Delta GmbH")
          _      <- repo.create(company)
          found  <- repo.findById(company.id)
        } yield assertTrue(
          found.isDefined,
          found.get.name == "Delta GmbH"
        )
      },
      test("findById returns None for unknown id") {
        for {
          repo  <- ZIO.service[CompanyRepository]
          found <- repo.findById(CompanyId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("update persists new status and plan") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          company = makeCompany(name = "Gamma GmbH", status = CompanyStatus.Active)
          _      <- repo.create(company)
          updated = company.copy(status = CompanyStatus.Suspended, subscriptionPlan = SubscriptionPlan.Professional)
          _      <- repo.update(updated)
          found  <- repo.findById(company.id)
        } yield assertTrue(
          found.isDefined,
          found.get.status == CompanyStatus.Suspended,
          found.get.subscriptionPlan == SubscriptionPlan.Professional
        )
      },
      test("countByStatus returns correct counts per status") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          active1 = makeCompany(name = "A1", status = CompanyStatus.Active)
          active2 = makeCompany(name = "A2", status = CompanyStatus.Active)
          susp    = makeCompany(name = "S1", status = CompanyStatus.Suspended)
          trial   = makeCompany(name = "T1", status = CompanyStatus.Trial)
          _      <- repo.create(active1)
          _      <- repo.create(active2)
          _      <- repo.create(susp)
          _      <- repo.create(trial)
          counts <- repo.countByStatus()
        } yield assertTrue(
          counts.getOrElse(CompanyStatus.Active, 0) >= 2,
          counts.getOrElse(CompanyStatus.Suspended, 0) >= 1,
          counts.getOrElse(CompanyStatus.Trial, 0) >= 1
        )
      },
      test("countByStatus returns empty map when no companies") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          counts <- repo.countByStatus()
        } yield assertTrue(counts.isEmpty)
      },
      test("softDelete marks an existing company Inactive and returns Some(company)") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          company = makeCompany(name = "Soft GmbH", status = CompanyStatus.Active)
          _      <- repo.create(company)
          result <- repo.softDelete(company.id)
          found  <- repo.findById(company.id)
        } yield assertTrue(
          result.isDefined,
          result.get.id == company.id,
          result.get.status == CompanyStatus.Inactive,
          // The in-memory store must reflect the change
          found.isDefined,
          found.get.status == CompanyStatus.Inactive
        )
      },
      test("softDelete of a non-existent company returns None") {
        for {
          repo   <- ZIO.service[CompanyRepository]
          result <- repo.softDelete(CompanyId(UUID.randomUUID()))
        } yield assertTrue(result.isEmpty)
      }
    ).provide(InMemoryCompanyRepository.layer) @@ TestAspect.sequential
