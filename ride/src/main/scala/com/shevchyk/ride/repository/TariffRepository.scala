package com.shevchyk.ride.repository

import com.shevchyk.core.domain.CompanyId
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.ride.domain.CompanyTariff
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.util.UUID

trait TariffRepository:
  /**
   * Load the tariff for a company. Returns `None` when no tariff row exists yet for the company. Callers should fall
   * back to [[CompanyTariff.default]] in that case.
   */
  def findByCompanyId(companyId: CompanyId): Task[Option[CompanyTariff]]

// ---------------------------------------------------------------------------
// In-memory double (used in unit tests — no DB required)
// ---------------------------------------------------------------------------

class InMemoryTariffRepository(rows: Map[CompanyId, CompanyTariff] = Map.empty) extends TariffRepository:

  def findByCompanyId(companyId: CompanyId): Task[Option[CompanyTariff]] = ZIO.succeed(rows.get(companyId))

object InMemoryTariffRepository:

  def withDefaults(companyIds: CompanyId*): InMemoryTariffRepository =
    new InMemoryTariffRepository(companyIds.map(id => id -> CompanyTariff.default(id)).toMap)

// ---------------------------------------------------------------------------
// PostgreSQL implementation
// ---------------------------------------------------------------------------

final class PostgresTariffRepository(xa: Transactor[Task]) extends TariffRepository:

  implicit val tariffRead: Read[CompanyTariff] = Read[(UUID, BigDecimal, BigDecimal, BigDecimal, BigDecimal, String)]
    .map { case (companyId, base, perKm, airport, night, currency) =>
      CompanyTariff(
        companyId = CompanyId(companyId),
        basePriceAmount = base,
        pricePerKmAmount = perKm,
        airportSurchargeAmount = airport,
        nightSurchargeAmount = night,
        currency = currency
      )
    }

  override def findByCompanyId(companyId: CompanyId): Task[Option[CompanyTariff]] =
    sql"""
      SELECT company_id, base_price_amount, price_per_km_amount,
             airport_surcharge_amount, night_surcharge_amount, base_price_currency
      FROM tariffs
      WHERE company_id = ${companyId.value}
    """
      .query[CompanyTariff]
      .option
      .transact(xa)

object PostgresTariffRepository:

  val layer: ZLayer[Transactor[Task], Nothing, TariffRepository] = ZLayer.fromFunction(PostgresTariffRepository.apply)

object TariffRepository:

  val liveLayer: ZLayer[Any, Throwable, TariffRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresTariffRepository.layer
