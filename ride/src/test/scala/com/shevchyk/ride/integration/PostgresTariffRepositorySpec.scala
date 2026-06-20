package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.CompanyId
import com.shevchyk.ride.repository.PostgresTariffRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for PostgresTariffRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresTariffRepositorySpec extends ZIOSpecDefault {

  private val companyId = CompanyId(UUID.fromString("0000000C-0000-0000-0000-000000000001"))

  private def seedCompany(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO companies (id, name, email) VALUES (${companyId.value}, 'Tariff Co', 'tariff@test.com')
            ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def insertTariff(xa: Transactor[Task]): Task[Unit] =
    sql"""INSERT INTO tariffs (company_id, base_price_amount, price_per_km_amount,
                               airport_surcharge_amount, night_surcharge_amount)
            VALUES (${companyId.value}, 4.50, 2.20, 12.00, 6.00)
            ON CONFLICT (company_id) DO UPDATE SET base_price_amount = EXCLUDED.base_price_amount""".update.run
      .transact(xa)
      .unit

  def spec =
    suite("PostgresTariffRepository")(
      test("findByCompanyId returns the stored tariff") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedCompany(xa)
          _      <- insertTariff(xa)
          repo    = PostgresTariffRepository(xa)
          result <- repo.findByCompanyId(companyId)
        } yield assertTrue(
          result.isDefined,
          result.get.basePriceAmount == BigDecimal("4.50"),
          result.get.pricePerKmAmount == BigDecimal("2.20"),
          result.get.airportSurchargeAmount == BigDecimal("12.00"),
          result.get.nightSurchargeAmount == BigDecimal("6.00"),
          result.get.currency == "EUR"
        )
      },
      test("findByCompanyId returns None when no tariff row exists") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          repo    = PostgresTariffRepository(xa)
          result <- repo.findByCompanyId(CompanyId(UUID.randomUUID()))
        } yield assertTrue(result.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
