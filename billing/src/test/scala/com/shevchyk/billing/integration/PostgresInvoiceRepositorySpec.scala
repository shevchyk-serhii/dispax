package com.shevchyk.billing.integration

import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.PostgresInvoiceRepository
import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.{Instant, LocalDate}
import java.util.UUID

object PostgresInvoiceRepositorySpec extends ZIOSpecDefault {

  val testCompanyId   = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientCompanyId = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000001"))
  val clientId        = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'Test GmbH', 'company@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                 VALUES (${clientCompanyId.value}, 'Test Client GmbH', ${testCompanyId.value}, 'client@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Test Client', 'person@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanInvoices(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM invoice_items".update.run.transact(xa) *>
      sql"DELETE FROM invoices".update.run.transact(xa) *>
      sql"DELETE FROM invoice_sequences WHERE company_id = ${testCompanyId.value}".update.run.transact(xa).unit

  private def makeInvoice(
      id: InvoiceId = InvoiceId.generate(),
      number: String = "INV-2026-0001",
      status: InvoiceStatus = InvoiceStatus.Draft
  ): Invoice = Invoice(
    id = id,
    number = number,
    clientCompanyId = clientCompanyId,
    taxiCompanyId = testCompanyId,
    status = status,
    periodFrom = LocalDate.of(2026, 1, 1),
    periodTo = LocalDate.of(2026, 1, 31),
    subtotalAmount = BigDecimal("100.00"),
    taxRate = BigDecimal("19.00"),
    taxAmount = BigDecimal("19.00"),
    totalAmount = BigDecimal("119.00"),
    currency = "EUR"
  )

  private def makeItem(invoiceId: InvoiceId, price: BigDecimal = BigDecimal("50.00")): InvoiceItem = InvoiceItem(
    id = InvoiceItemId.generate(),
    invoiceId = invoiceId,
    rideId = None,
    description = "Test ride",
    quantity = BigDecimal(1),
    unitPrice = price,
    total = price
  )

  def spec =
    suite("PostgresInvoiceRepository")(
      test("create and findById round-trip") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice()
          _      <- repo.create(invoice)
          found  <- repo.findById(invoice.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == invoice.id,
          found.get.number == "INV-2026-0001",
          found.get.clientCompanyId == clientCompanyId,
          found.get.taxiCompanyId == testCompanyId,
          found.get.status == InvoiceStatus.Draft,
          found.get.subtotalAmount == BigDecimal("100.00"),
          found.get.taxRate == BigDecimal("19.00"),
          found.get.currency == "EUR"
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          repo   = PostgresInvoiceRepository(xa)
          found <- repo.findById(InvoiceId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("update changes status and sentAt") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice()
          _      <- repo.create(invoice)
          now     = Instant.now()
          updated = invoice.copy(status = InvoiceStatus.Sent, sentAt = Some(now))
          _      <- repo.update(updated)
          found  <- repo.findById(invoice.id)
        } yield assertTrue(
          found.get.status == InvoiceStatus.Sent,
          found.get.sentAt.isDefined
        )
      },
      test("delete removes draft invoice") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanInvoices(xa)
          repo     = PostgresInvoiceRepository(xa)
          invoice  = makeInvoice()
          _       <- repo.create(invoice)
          deleted <- repo.delete(invoice.id)
          found   <- repo.findById(invoice.id)
        } yield assertTrue(deleted, found.isEmpty)
      },
      test("delete does not remove non-draft invoice") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanInvoices(xa)
          repo     = PostgresInvoiceRepository(xa)
          invoice  = makeInvoice(status = InvoiceStatus.Sent)
          _       <- repo.create(invoice)
          deleted <- repo.delete(invoice.id)
        } yield assertTrue(!deleted)
      },
      test("addItems and findById includes items") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice()
          _      <- repo.create(invoice)
          item1   = makeItem(invoice.id, BigDecimal("50.00"))
          item2   = makeItem(invoice.id, BigDecimal("30.00"))
          _      <- repo.addItems(List(item1, item2))
          found  <- repo.findById(invoice.id)
        } yield assertTrue(
          found.get.items.length == 2,
          found.get.items.map(_.total).sum == BigDecimal("80.00")
        )
      },
      test("deleteItems removes all items for invoice") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice()
          _      <- repo.create(invoice)
          _      <- repo.addItems(List(makeItem(invoice.id)))
          _      <- repo.deleteItems(invoice.id)
          found  <- repo.findById(invoice.id)
        } yield assertTrue(found.get.items.isEmpty)
      },
      test("findByCompany returns paginated invoices") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          _      <- repo.create(makeInvoice(number = "INV-2026-0001"))
          _      <- repo.create(makeInvoice(number = "INV-2026-0002"))
          _      <- repo.create(makeInvoice(number = "INV-2026-0003", status = InvoiceStatus.Sent))
          all    <- repo.findByCompany(testCompanyId, None, 10, 0)
          drafts <- repo.findByCompany(testCompanyId, Some(InvoiceStatus.Draft), 10, 0)
          sent   <- repo.findByCompany(testCompanyId, Some(InvoiceStatus.Sent), 10, 0)
          paged  <- repo.findByCompany(testCompanyId, None, 2, 0)
          other  <- repo.findByCompany(CompanyId(UUID.randomUUID()), None, 10, 0)
        } yield assertTrue(
          all.length == 3,
          drafts.length == 2,
          sent.length == 1,
          paged.length == 2,
          other.isEmpty
        )
      },
      test("nextInvoiceNumber generates sequential numbers") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanInvoices(xa)
          repo = PostgresInvoiceRepository(xa)
          n1  <- repo.nextInvoiceNumber(testCompanyId, 2026)
          n2  <- repo.nextInvoiceNumber(testCompanyId, 2026)
          n3  <- repo.nextInvoiceNumber(testCompanyId, 2026)
        } yield assertTrue(
          n1 == "INV-2026-0001",
          n2 == "INV-2026-0002",
          n3 == "INV-2026-0003"
        )
      },
      test("nextInvoiceNumber is idempotent across companies") {
        val otherCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <-
            sql"""INSERT INTO companies (id, name, email)
                      VALUES (${otherCompanyId.value}, 'Other GmbH', 'other@test.com')
                      ON CONFLICT DO NOTHING""".update.run.transact(xa)
          _   <- cleanInvoices(xa)
          repo = PostgresInvoiceRepository(xa)
          n1  <- repo.nextInvoiceNumber(testCompanyId, 2026)
          n2  <- repo.nextInvoiceNumber(otherCompanyId, 2026)
        } yield assertTrue(
          n1 == "INV-2026-0001",
          n2 == "INV-2026-0001"
        )
      },
      test("notes and dueDate round-trip") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice().copy(
                      notes = Some("Bitte bis Ende des Monats bezahlen"),
                      dueDate = Some(LocalDate.of(2026, 2, 28))
                    )
          _      <- repo.create(invoice)
          found  <- repo.findById(invoice.id)
        } yield assertTrue(
          found.get.notes.contains("Bitte bis Ende des Monats bezahlen"),
          found.get.dueDate.contains(LocalDate.of(2026, 2, 28))
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
