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
 * Integration tests for the three DATEV fields added by migration V6 in PostgresCompanySettingsRepository.
 *
 *   - datev_beraternummer (VARCHAR 7)
 *   - datev_mandantennummer (VARCHAR 5)
 *   - datev_sachkontenlaenge (SMALLINT)
 *
 * All tests use the real Postgres schema via Testcontainers. DB is not mocked per project invariants.
 */
object PostgresCompanySettingsDatevSpec extends ZIOSpecDefault {

  val companyId: CompanyId      = CompanyId(UUID.fromString("0000000E-0000-0000-0000-000000000001"))
  val otherCompanyId: CompanyId = CompanyId(UUID.fromString("0000000E-0000-0000-0000-000000000002"))

  private def seedCompanies(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
              VALUES (${companyId.value}, 'DATEV GmbH A', 'datev-a@example.com')
              ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email)
              VALUES (${otherCompanyId.value}, 'DATEV GmbH B', 'datev-b@example.com')
              ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanSettings(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM company_settings".update.run.transact(xa).unit

  private def baseSettings(cid: CompanyId = companyId): CompanySettings = CompanySettings(
    companyId = cid,
    commissionRate = BigDecimal("10.00"),
    datevBeraternummer = None,
    datevMandantennummer = None,
    datevSachkontenlaenge = None
  )

  def spec =
    suite("PostgresCompanySettingsRepository — DATEV V6 fields")(
      test("upsert with all DATEV fields → read back with correct values") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          s      = baseSettings().copy(
                     datevBeraternummer = Some("123456"),
                     datevMandantennummer = Some("99999"),
                     datevSachkontenlaenge = Some(4)
                   )
          _     <- repo.upsert(s)
          found <- repo.findByCompanyId(companyId)
        } yield assertTrue(
          found.isDefined,
          found.get.datevBeraternummer.contains("123456"),
          found.get.datevMandantennummer.contains("99999"),
          found.get.datevSachkontenlaenge.contains(4)
        )
      },
      test("upsert with None DATEV fields → read back as None") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          _     <- repo.upsert(baseSettings())
          found <- repo.findByCompanyId(companyId)
        } yield assertTrue(
          found.isDefined,
          found.get.datevBeraternummer.isEmpty,
          found.get.datevMandantennummer.isEmpty,
          found.get.datevSachkontenlaenge.isEmpty
        )
      },
      test("upsert overwrites DATEV fields on conflict (update path)") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedCompanies(xa)
          _        <- cleanSettings(xa)
          repo      = PostgresCompanySettingsRepository(xa)
          // First insert with values
          initial   = baseSettings().copy(
                        datevBeraternummer = Some("000001"),
                        datevMandantennummer = Some("00001"),
                        datevSachkontenlaenge = Some(4)
                      )
          _        <- repo.upsert(initial)
          // Update with different values
          updated   = initial.copy(
                        datevBeraternummer = Some("654321"),
                        datevMandantennummer = Some("11111"),
                        datevSachkontenlaenge = Some(6)
                      )
          _        <- repo.upsert(updated)
          found    <- repo.findByCompanyId(companyId)
          // Confirm no duplicate row was inserted
          rowCount <- sql"SELECT COUNT(*)::int FROM company_settings WHERE company_id = ${companyId.value}"
                        .query[Int]
                        .unique
                        .transact(xa)
        } yield assertTrue(
          rowCount == 1,
          found.isDefined,
          found.get.datevBeraternummer.contains("654321"),
          found.get.datevMandantennummer.contains("11111"),
          found.get.datevSachkontenlaenge.contains(6)
        )
      },
      test("upsert clears DATEV fields from Some to None on update") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          // Insert with DATEV values
          _     <- repo.upsert(
                     baseSettings().copy(
                       datevBeraternummer = Some("123456"),
                       datevMandantennummer = Some("99999"),
                       datevSachkontenlaenge = Some(4)
                     )
                   )
          // Update clearing the DATEV fields
          _     <- repo.upsert(baseSettings())
          found <- repo.findByCompanyId(companyId)
        } yield assertTrue(
          found.isDefined,
          found.get.datevBeraternummer.isEmpty,
          found.get.datevMandantennummer.isEmpty,
          found.get.datevSachkontenlaenge.isEmpty
        )
      },
      test("findByCompanyId isolates DATEV settings between companies") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompanies(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresCompanySettingsRepository(xa)
          _      <- repo.upsert(
                      baseSettings(companyId).copy(
                        datevBeraternummer = Some("AAAA"),
                        datevSachkontenlaenge = Some(4)
                      )
                    )
          _      <- repo.upsert(
                      baseSettings(otherCompanyId).copy(
                        datevBeraternummer = Some("BBBB"),
                        datevSachkontenlaenge = Some(6)
                      )
                    )
          mine   <- repo.findByCompanyId(companyId)
          theirs <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.isDefined,
          mine.get.datevBeraternummer.contains("AAAA"),
          mine.get.datevSachkontenlaenge.contains(4),
          theirs.isDefined,
          theirs.get.datevBeraternummer.contains("BBBB"),
          theirs.get.datevSachkontenlaenge.contains(6)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
