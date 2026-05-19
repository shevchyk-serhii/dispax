package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*

object ClientCompanyRepositorySpec extends ZIOSpecDefault {

  val companyId      = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()

  def makeCompany(
      name: String = "Acme GmbH",
      taxiCompanyId: CompanyId = companyId,
      email: Option[String] = Some("acme@example.com"),
      address: Option[String] = Some("Hauptstr. 1")
  ): ClientCompany = ClientCompany(
    id = ClientCompanyId.generate(),
    name = name,
    taxiCompanyId = taxiCompanyId,
    email = email,
    address = address
  )

  val layers = InMemoryClientCompanyRepository.layer

  def spec = suite("ClientCompanyRepository")(
    suite("create and findById")(
      test("creates and finds by id") {
        val company = makeCompany()
        for {
          repo    <- ZIO.service[ClientCompanyRepository]
          created <- repo.create(company)
          found   <- repo.findById(company.id)
        } yield assertTrue(
          created == company &&
          found.contains(company)
        )
      }.provide(layers),
      test("returns None for unknown id") {
        for {
          repo  <- ZIO.service[ClientCompanyRepository]
          found <- repo.findById(ClientCompanyId.generate())
        } yield assertTrue(found.isEmpty)
      }.provide(layers)
    ),
    suite("findByTaxiCompany")(
      test("returns companies for correct taxi company") {
        val c1 = makeCompany(name = "A Corp", taxiCompanyId = companyId)
        val c2 = makeCompany(name = "B Corp", taxiCompanyId = companyId)
        val c3 = makeCompany(name = "C Corp", taxiCompanyId = otherCompanyId)
        for {
          repo  <- ZIO.service[ClientCompanyRepository]
          _     <- repo.create(c1)
          _     <- repo.create(c2)
          _     <- repo.create(c3)
          found <- repo.findByTaxiCompany(companyId)
        } yield assertTrue(
          found.size == 2 &&
          found.map(_.name).toSet == Set("A Corp", "B Corp")
        )
      }.provide(layers),
      test("returns empty for unknown taxi company") {
        val c = makeCompany(taxiCompanyId = companyId)
        for {
          repo  <- ZIO.service[ClientCompanyRepository]
          _     <- repo.create(c)
          found <- repo.findByTaxiCompany(otherCompanyId)
        } yield assertTrue(found.isEmpty)
      }.provide(layers),
      test("returns companies sorted by name") {
        val c1 = makeCompany(name = "Zebra Corp", taxiCompanyId = companyId)
        val c2 = makeCompany(name = "Alpha Corp", taxiCompanyId = companyId)
        val c3 = makeCompany(name = "Mango Corp", taxiCompanyId = companyId)
        for {
          repo  <- ZIO.service[ClientCompanyRepository]
          _     <- repo.create(c1)
          _     <- repo.create(c2)
          _     <- repo.create(c3)
          found <- repo.findByTaxiCompany(companyId)
        } yield assertTrue(found.map(_.name) == List("Alpha Corp", "Mango Corp", "Zebra Corp"))
      }.provide(layers)
    ),
    suite("update")(
      test("updates company fields") {
        val original = makeCompany(name = "Old Name", email = None)
        val updated  = original.copy(name = "New Name", email = Some("new@example.com"))
        for {
          repo      <- ZIO.service[ClientCompanyRepository]
          _         <- repo.create(original)
          _         <- repo.update(updated)
          found     <- repo.findById(original.id)
        } yield assertTrue(
          found.map(_.name).contains("New Name") &&
          found.flatMap(_.email).contains("new@example.com")
        )
      }.provide(layers)
    ),
    suite("delete")(
      test("deletes existing company") {
        val company = makeCompany()
        for {
          repo    <- ZIO.service[ClientCompanyRepository]
          _       <- repo.create(company)
          deleted <- repo.delete(company.id)
          found   <- repo.findById(company.id)
        } yield assertTrue(deleted && found.isEmpty)
      }.provide(layers),
      test("returns false when deleting unknown id") {
        for {
          repo    <- ZIO.service[ClientCompanyRepository]
          deleted <- repo.delete(ClientCompanyId.generate())
        } yield assertTrue(!deleted)
      }.provide(layers)
    )
  )
}
