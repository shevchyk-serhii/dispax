package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{PostgresClientCompanyRepository, PostgresCompanySettingsRepository}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for the new airport pickup timing columns:
 *   - company_settings.airport_buffer_minutes / airport_checkin_close_minutes
 *   - client_companies.airport_buffer_minutes / airport_checkin_close_minutes
 *
 * Rules verified here:
 *   1. Write + read airport_buffer_minutes and airport_checkin_close_minutes in company_settings. 2. Write + read those
 *      columns in client_companies. 3. Upsert on company_settings overwrites the timing columns. 4. [CRITICAL] Tenant
 *      isolation: settings for company A are NOT returned when querying with company B's id.
 */
object PostgresPickupTimingSettingsSpec extends ZIOSpecDefault {

  val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  val companyBId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))

  private def seedCompanies(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${companyAId.value}, 'Pickup Company A', 'a@pickup.test')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${companyBId.value}, 'Pickup Company B', 'b@pickup.test')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanSettings(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM client_companies".update.run
      _ <- sql"DELETE FROM company_settings".update.run
    } yield ()).transact(xa)

  private def makeSettings(compId: CompanyId, buffer: Option[Int], checkIn: Option[Int]): CompanySettings =
    CompanySettings(
      companyId = compId,
      airportBufferMinutes = buffer,
      airportCheckInCloseMinutes = checkIn
    )

  private def makeClientCompany(
      ccId: ClientCompanyId,
      taxiId: CompanyId,
      buffer: Option[Int],
      checkIn: Option[Int]
  ): ClientCompany = ClientCompany(
    id = ccId,
    name = "Test Corp",
    taxiCompanyId = taxiId,
    email = Some("cc@test.com"),
    airportBufferMinutes = buffer,
    airportCheckInCloseMinutes = checkIn
  )

  def spec =
    suite("PostgresPickupTimingSettings — integration")(
      // ─────────────────────────────────────────────────────────────────────
      // company_settings
      // ─────────────────────────────────────────────────────────────────────

      test("company_settings: upsert writes airport timing columns; findByCompanyId reads them back") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          s      = makeSettings(companyAId, buffer = Some(20), checkIn = Some(40))
          _     <- repo.upsert(s)
          found <- repo.findByCompanyId(companyAId)
        } yield assertTrue(
          found.isDefined,
          found.get.airportBufferMinutes.contains(20),
          found.get.airportCheckInCloseMinutes.contains(40)
        )
      },
      test("company_settings: NULL timing columns map to None") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresCompanySettingsRepository(xa)
          s      = makeSettings(companyAId, buffer = None, checkIn = None)
          _     <- repo.upsert(s)
          found <- repo.findByCompanyId(companyAId)
        } yield assertTrue(
          found.isDefined,
          found.get.airportBufferMinutes.isEmpty,
          found.get.airportCheckInCloseMinutes.isEmpty
        )
      },
      test("company_settings: upsert with new values overwrites previous airport timing columns") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompanies(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresCompanySettingsRepository(xa)
          initial = makeSettings(companyAId, buffer = Some(10), checkIn = Some(30))
          _      <- repo.upsert(initial)
          updated = makeSettings(companyAId, buffer = Some(25), checkIn = Some(55))
          _      <- repo.upsert(updated)
          found  <- repo.findByCompanyId(companyAId)
          rows   <- sql"SELECT COUNT(*)::int FROM company_settings WHERE company_id = ${companyAId.value}"
                      .query[Int]
                      .unique
                      .transact(xa)
        } yield assertTrue(
          rows == 1, // no duplicate row
          found.isDefined,
          found.get.airportBufferMinutes.contains(25),
          found.get.airportCheckInCloseMinutes.contains(55)
        )
      },

      // ─────────────────────────────────────────────────────────────────────
      // client_companies
      // ─────────────────────────────────────────────────────────────────────

      test("client_companies: create writes airport timing columns; findById reads them back") {
        val ccId = ClientCompanyId(UUID.randomUUID())
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresClientCompanyRepository(xa)
          cc     = makeClientCompany(ccId, companyAId, buffer = Some(10), checkIn = Some(35))
          _     <- repo.create(cc)
          found <- repo.findById(ccId)
        } yield assertTrue(
          found.isDefined,
          found.get.airportBufferMinutes.contains(10),
          found.get.airportCheckInCloseMinutes.contains(35)
        )
      },
      test("client_companies: update overwrites airport timing columns") {
        val ccId = ClientCompanyId(UUID.randomUUID())
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompanies(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresClientCompanyRepository(xa)
          initial = makeClientCompany(ccId, companyAId, buffer = Some(10), checkIn = Some(35))
          _      <- repo.create(initial)
          updated = initial.copy(airportBufferMinutes = Some(20), airportCheckInCloseMinutes = Some(50))
          _      <- repo.update(updated)
          found  <- repo.findById(ccId)
        } yield assertTrue(
          found.isDefined,
          found.get.airportBufferMinutes.contains(20),
          found.get.airportCheckInCloseMinutes.contains(50)
        )
      },
      test("client_companies: NULL timing columns map to None") {
        val ccId = ClientCompanyId(UUID.randomUUID())
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedCompanies(xa)
          _     <- cleanSettings(xa)
          repo   = PostgresClientCompanyRepository(xa)
          cc     = makeClientCompany(ccId, companyAId, buffer = None, checkIn = None)
          _     <- repo.create(cc)
          found <- repo.findById(ccId)
        } yield assertTrue(
          found.isDefined,
          found.get.airportBufferMinutes.isEmpty,
          found.get.airportCheckInCloseMinutes.isEmpty
        )
      },

      // ─────────────────────────────────────────────────────────────────────
      // [CRITICAL] Tenant isolation
      // ─────────────────────────────────────────────────────────────────────

      test("[CRITICAL] company_settings tenant isolation: company A settings NOT returned for company B") {
        // Mutation-verified: kills "return any company's settings regardless of companyId" mutation
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompanies(xa)
          _      <- cleanSettings(xa)
          repo    = PostgresCompanySettingsRepository(xa)
          sA      = makeSettings(companyAId, buffer = Some(20), checkIn = Some(40))
          _      <- repo.upsert(sA)
          foundA <- repo.findByCompanyId(companyAId) // own company: must be Some
          foundB <- repo.findByCompanyId(companyBId) // other company: must be None (no settings set)
        } yield assertTrue(
          foundA.isDefined,
          foundA.get.airportBufferMinutes.contains(20),
          foundB.isEmpty // company B has no settings — company A's row must not bleed across
        )
      },
      test("[CRITICAL] client_companies tenant isolation: findByTaxiCompany returns only matching company") {
        // Mutation-verified: kills "return all client companies regardless of taxiCompanyId" mutation
        val ccAId = ClientCompanyId(UUID.randomUUID())
        val ccBId = ClientCompanyId(UUID.randomUUID())
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedCompanies(xa)
          _    <- cleanSettings(xa)
          repo  = PostgresClientCompanyRepository(xa)
          ccA   = makeClientCompany(ccAId, companyAId, buffer = Some(10), checkIn = Some(30))
          ccB   = makeClientCompany(ccBId, companyBId, buffer = Some(99), checkIn = Some(99))
          _    <- repo.create(ccA)
          _    <- repo.create(ccB)
          forA <- repo.findByTaxiCompany(companyAId)
          forB <- repo.findByTaxiCompany(companyBId)
        } yield assertTrue(
          forA.length == 1,
          forA.head.id == ccAId,
          forA.head.taxiCompanyId == companyAId,
          forB.length == 1,
          forB.head.id == ccBId,
          forB.head.taxiCompanyId == companyBId,
          !forA.exists(_.id == ccBId), // company A must not see company B's record
          !forB.exists(_.id == ccAId)  // company B must not see company A's record
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
