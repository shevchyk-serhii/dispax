package com.shevchyk.billing.integration

import com.shevchyk.billing.domain.UpdateCompanyBillingProfileRequest
import com.shevchyk.billing.repository.PostgresCompanyBillingProfileRepository
import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

object PostgresCompanyBillingProfileRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000b1"))

  private def seed(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO companies (id, name, email)
          VALUES (${testCompanyId.value}, 'Profile Test GmbH', 'profile@test.com')
          ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def clean(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM company_billing_profile WHERE company_id = ${testCompanyId.value}".update.run.transact(xa).unit

  private def fullRequest = UpdateCompanyBillingProfileRequest(
    businessType = Some("Mietwagenunternehmen"),
    legalName = Some("Dispax München"),
    addressLine1 = Some("Leopoldstraße 1"),
    addressLine2 = Some("80802 München"),
    phone = Some("+49 89 12345678"),
    email = Some("info@dispax.de"),
    taxNumber = Some("146/116/61550"),
    vatId = Some("DE123456789"),
    bankName = Some("Deutsche Bank"),
    bankAccountNo = Some("3939543"),
    bankCode = Some("70070024"),
    iban = Some("DE24 7007 0024 0393 9543 00"),
    bic = Some("DEUTDEDBMUC"),
    paymentTermsDays = Some(14),
    invoiceIntro = Some("Ich gestatte mir, ...")
  )

  def spec =
    suite("PostgresCompanyBillingProfileRepository")(
      test("findByCompany returns None when no profile exists") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seed(xa)
          _   <- clean(xa)
          repo = PostgresCompanyBillingProfileRepository(xa)
          res <- repo.findByCompany(testCompanyId)
        } yield assertTrue(res.isEmpty)
      },
      test("upsert inserts a new profile and findByCompany returns it") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresCompanyBillingProfileRepository(xa)
          saved   <- repo.upsert(testCompanyId, fullRequest)
          fetched <- repo.findByCompany(testCompanyId)
        } yield assertTrue(
          saved.companyId == testCompanyId,
          saved.legalName.contains("Dispax München"),
          saved.vatId.contains("DE123456789"),
          saved.iban.contains("DE24 7007 0024 0393 9543 00"),
          saved.paymentTermsDays == 14,
          fetched.exists(_.legalName.contains("Dispax München")),
          fetched.exists(_.paymentTermsDays == 14)
        )
      },
      test("upsert updates an existing profile (idempotent on company_id)") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresCompanyBillingProfileRepository(xa)
          _       <- repo.upsert(testCompanyId, fullRequest)
          updated <- repo.upsert(
                       testCompanyId,
                       fullRequest.copy(legalName = Some("Dispax München GmbH"), paymentTermsDays = Some(30))
                     )
          all     <- ZIO.service[Transactor[Task]].flatMap { x =>
                       sql"SELECT count(*) FROM company_billing_profile WHERE company_id = ${testCompanyId.value}"
                         .query[Int]
                         .unique
                         .transact(x)
                     }
        } yield assertTrue(
          updated.legalName.contains("Dispax München GmbH"),
          updated.paymentTermsDays == 30,
          // Upsert must not create a second row.
          all == 1
        )
      },
      test("upsert defaults paymentTermsDays to 7 when not provided") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresCompanyBillingProfileRepository(xa)
          saved <- repo.upsert(testCompanyId, UpdateCompanyBillingProfileRequest(legalName = Some("Minimal")))
        } yield assertTrue(saved.paymentTermsDays == 7)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")
}
