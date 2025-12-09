package com.shevchyk.infrastructure.repository.postgres

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

case class DoobieTariffRepository(xa: Transactor[Task]) extends TariffRepository:

  implicit val companyIdMeta: Meta[CompanyId] = Meta[Int].timap(CompanyId.apply)(_.value)

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, Option[Tariff]] =
    val selectSql =
      sql"""
      SELECT base_price_amount, base_price_currency, price_per_km_amount, price_per_km_currency,
             airport_surcharge_amount, airport_surcharge_currency, night_surcharge_amount, night_surcharge_currency
      FROM tariffs 
      WHERE company_id = $companyId
    """

    selectSql
      .query[TariffRow]
      .option
      .transact(xa)
      .map(_.map(toTariff))
      .mapError(RepositoryError.DatabaseError.apply)

  def save(tariff: Tariff, companyId: CompanyId): IO[RepositoryError, Unit] =
    val upsertSql =
      sql"""
      INSERT INTO tariffs (
        company_id, base_price_amount, base_price_currency, 
        price_per_km_amount, price_per_km_currency,
        airport_surcharge_amount, airport_surcharge_currency,
        night_surcharge_amount, night_surcharge_currency, updated_at
      ) VALUES (
        $companyId, ${tariff.basePrice.amount}, ${tariff.basePrice.currency},
        ${tariff.pricePerKm.amount}, ${tariff.pricePerKm.currency},
        ${tariff.airportSurcharge.amount}, ${tariff.airportSurcharge.currency},
        ${tariff.nightSurcharge.amount}, ${tariff.nightSurcharge.currency}, NOW()
      )
      ON CONFLICT (company_id) DO UPDATE SET
        base_price_amount = EXCLUDED.base_price_amount,
        base_price_currency = EXCLUDED.base_price_currency,
        price_per_km_amount = EXCLUDED.price_per_km_amount,
        price_per_km_currency = EXCLUDED.price_per_km_currency,
        airport_surcharge_amount = EXCLUDED.airport_surcharge_amount,
        airport_surcharge_currency = EXCLUDED.airport_surcharge_currency,
        night_surcharge_amount = EXCLUDED.night_surcharge_amount,
        night_surcharge_currency = EXCLUDED.night_surcharge_currency,
        updated_at = EXCLUDED.updated_at
    """

    upsertSql.update.run
      .transact(xa)
      .map(_ => ())
      .mapError(RepositoryError.DatabaseError.apply)

  private case class TariffRow(
      basePriceAmount: Double,
      basePriceCurrency: String,
      pricePerKmAmount: Double,
      pricePerKmCurrency: String,
      airportSurchargeAmount: Double,
      airportSurchargeCurrency: String,
      nightSurchargeAmount: Double,
      nightSurchargeCurrency: String
  )

  private def toTariff(row: TariffRow): Tariff = Tariff(
    basePrice = Price(row.basePriceAmount, row.basePriceCurrency),
    pricePerKm = Price(row.pricePerKmAmount, row.pricePerKmCurrency),
    airportSurcharge = Price(row.airportSurchargeAmount, row.airportSurchargeCurrency),
    nightSurcharge = Price(row.nightSurchargeAmount, row.nightSurchargeCurrency)
  )
