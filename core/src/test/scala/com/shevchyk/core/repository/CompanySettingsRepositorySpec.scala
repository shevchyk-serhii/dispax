package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.Instant

object CompanySettingsRepositorySpec extends ZIOSpecDefault {

  val companyId1 = CompanyId.generate()
  val companyId2 = CompanyId.generate()

  def makeSettings(
      companyId: CompanyId = companyId1,
      commissionRate: BigDecimal = BigDecimal(15.00),
      currency: String = "EUR"
  ): CompanySettings = CompanySettings(
    companyId = companyId,
    commissionRate = commissionRate,
    defaultCurrency = currency,
    updatedAt = Instant.now()
  )

  val layers = CompanySettingsRepository.inMemory

  def spec =
    suite("CompanySettingsRepository")(
      test("upsert creates new settings") {
        val settings = makeSettings()
        for {
          repo    <- ZIO.service[CompanySettingsRepository]
          created <- repo.upsert(settings)
          found   <- repo.findByCompanyId(companyId1)
        } yield assertTrue(
          created.companyId == companyId1 &&
            found.isDefined &&
            found.get.companyId == companyId1 &&
            found.get.commissionRate == BigDecimal(15.00)
        )
      }.provide(layers),
      test("upsert updates existing settings") {
        val original = makeSettings(commissionRate = BigDecimal(10.00))
        val updated  = original.copy(commissionRate = BigDecimal(20.00))
        for {
          repo  <- ZIO.service[CompanySettingsRepository]
          _     <- repo.upsert(original)
          _     <- repo.upsert(updated)
          found <- repo.findByCompanyId(companyId1)
        } yield assertTrue(
          found.isDefined &&
            found.get.commissionRate == BigDecimal(20.00)
        )
      }.provide(layers),
      test("findByCompanyId returns None for unknown company") {
        for {
          repo  <- ZIO.service[CompanySettingsRepository]
          found <- repo.findByCompanyId(companyId2)
        } yield assertTrue(found.isEmpty)
      }.provide(layers)
    )
}
