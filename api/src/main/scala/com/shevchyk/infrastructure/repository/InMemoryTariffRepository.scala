package com.shevchyk.infrastructure.repository

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{TariffRepository, RepositoryError}
import zio.*

case class InMemoryTariffRepository(storage: Ref[Map[CompanyId, Tariff]]) extends TariffRepository:

  override def findByCompanyId(companyId: CompanyId): IO[RepositoryError, Option[Tariff]] = storage.get.map(
    _.get(companyId)
  )

  override def save(tariff: Tariff, companyId: CompanyId): IO[RepositoryError, Unit] = storage.update(
    _ + (companyId -> tariff)
  )

object InMemoryTariffRepository:

  val layer: ZLayer[Any, Nothing, TariffRepository] = ZLayer.fromZIO(
    Ref.make(mockTariffs).map(InMemoryTariffRepository(_))
  )

  private val mockTariffs: Map[CompanyId, Tariff] = Map(
    CompanyId(1) -> Tariff(
      basePrice = Price(5.00, "EUR"),
      pricePerKm = Price(1.20, "EUR"),
      airportSurcharge = Price(10.00, "EUR"),
      nightSurcharge = Price(3.00, "EUR")
    )
  )
