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
 * Integration tests for PostgresCompanySettingsRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresCompanySettingsRepositorySpec extends ZIOSpecDefault {

  val companyId      = CompanyId(UUID.fromString("0000000D-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("0000000D-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyId.value}, 'Settings One GmbH', 'set1@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Settings Two GmbH', 'set2@example.com')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanSettings(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM company_settings".update.run.transact(xa).unit

  private def makeSettings(company: CompanyId = companyId): CompanySettings =
    CompanySettings(
      companyId = company,
      commissionRate = BigDecimal("12.50"),
      workingHoursStart = "07:00",
      workingHoursEnd = "21:00",
      defaultCurrency = "EUR",
      cancellationFeeDefault = BigDecimal("5.00"),
      noShowFee = BigDecimal("10.00"),
      autoAssignEnabled = true
    )

  def spec =
    suite("PostgresCompanySettingsRepository")(
      test("upsert inserts then findByCompanyId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          s      = makeSettings()
          _     <- repo.upsert(s)
          found <- repo.findByCompanyId(companyId)
        } yield assertTrue(
          found.isDefined,
          found.get.companyId == companyId,
          found.get.commissionRate == BigDecimal("12.50"),
          found.get.workingHoursStart == "07:00:00",
          found.get.workingHoursEnd == "21:00:00",
          found.get.defaultCurrency == "EUR",
          found.get.cancellationFeeDefault == BigDecimal("5.00"),
          found.get.noShowFee == BigDecimal("10.00"),
          found.get.autoAssignEnabled
        )
      },
      test("findByCompanyId returns None when absent") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          found <- repo.findByCompanyId(companyId)
        } yield assertTrue(found.isEmpty)
      },
      test("upsert twice updates existing row by company_id (no duplicate)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresCompanySettingsRepository(xa)
          _      <- repo.upsert(makeSettings())
          updated = makeSettings().copy(commissionRate = BigDecimal("20.00"), autoAssignEnabled = false, defaultCurrency = "USD")
          _      <- repo.upsert(updated)
          found  <- repo.findByCompanyId(companyId)
          rows   <- sql"SELECT COUNT(*)::int FROM company_settings WHERE company_id = ${companyId.value}"
                      .query[Int].unique.transact(xa)
        } yield assertTrue(
          rows == 1,
          found.isDefined,
          found.get.commissionRate == BigDecimal("20.00"),
          !found.get.autoAssignEnabled,
          found.get.defaultCurrency == "USD"
        )
      },
      test("findByCompanyId isolates by company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresCompanySettingsRepository(xa)
          _      <- repo.upsert(makeSettings(company = companyId))
          _      <- repo.upsert(makeSettings(company = otherCompanyId).copy(commissionRate = BigDecimal("99.00")))
          mine   <- repo.findByCompanyId(companyId)
          theirs <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.isDefined,
          mine.get.commissionRate == BigDecimal("12.50"),
          theirs.isDefined,
          theirs.get.commissionRate == BigDecimal("99.00")
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
