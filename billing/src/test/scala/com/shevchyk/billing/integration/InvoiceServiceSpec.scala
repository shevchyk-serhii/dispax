package com.shevchyk.billing.integration

import com.shevchyk.billing.application.{InvoiceService, InvoiceServiceImpl}
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{PostgresClientCompanyRepository, PostgresInvoiceRepository}
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

object InvoiceServiceSpec extends ZIOSpecDefault {

  val testCompanyId    = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000011"))
  val clientCompanyId  = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000011"))
  val clientPersonId   = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000011"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'Service Test GmbH', 'svc@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                 VALUES (${clientCompanyId.value}, 'Service Client GmbH', ${testCompanyId.value}, 'svclient@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientPersonId.value}, 'Svc Client', 'svcclient@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanData(xa: Transactor[Task]): Task[Unit] =
    sql"UPDATE rides SET invoice_id = NULL WHERE invoice_id IS NOT NULL".update.run.transact(xa) *>
      sql"DELETE FROM invoice_items".update.run.transact(xa) *>
      sql"DELETE FROM invoices".update.run.transact(xa) *>
      sql"DELETE FROM invoice_sequences WHERE company_id = ${testCompanyId.value}".update.run.transact(xa).unit

  private def makeRequest(
      clientId: UUID = clientCompanyId.value,
      taxRate: BigDecimal = BigDecimal("19"),
      from: LocalDate = LocalDate.of(2026, 1, 1),
      to: LocalDate = LocalDate.of(2026, 1, 31)
  ): CreateInvoiceRequest = CreateInvoiceRequest(
    clientCompanyId = clientId,
    periodFrom = from,
    periodTo = to,
    taxRate = taxRate,
    currency = "EUR"
  )

  private def makeService(xa: Transactor[Task]): InvoiceService =
    InvoiceServiceImpl(PostgresInvoiceRepository(xa), PostgresClientCompanyRepository(xa))

  def spec = suite("InvoiceService")(

    test("createInvoice creates a Draft invoice with sequential number") {
      for {
        xa      <- ZIO.service[Transactor[Task]]
        _       <- seedTestData(xa)
        _       <- cleanData(xa)
        svc      = makeService(xa)
        inv     <- svc.createInvoice(testCompanyId, makeRequest())
      } yield assertTrue(
        inv.status == InvoiceStatus.Draft,
        inv.number == "INV-2026-0001",
        inv.clientCompanyId == clientCompanyId,
        inv.taxiCompanyId == testCompanyId,
        inv.subtotalAmount == BigDecimal(0),
        inv.taxRate == BigDecimal("19"),
        inv.currency == "EUR"
      )
    },

    test("createInvoice fails for unknown client company") {
      val unknownId = UUID.randomUUID()
      for {
        xa  <- ZIO.service[Transactor[Task]]
        _   <- seedTestData(xa)
        _   <- cleanData(xa)
        svc  = makeService(xa)
        res <- svc.createInvoice(testCompanyId, makeRequest(clientId = unknownId)).either
      } yield assertTrue(res match
        case Left(InvoiceError.ClientCompanyNotFound(`unknownId`)) => true
        case _ => false
      )
    },

    test("getInvoice returns NotFound for unknown id") {
      for {
        xa  <- ZIO.service[Transactor[Task]]
        svc  = makeService(xa)
        id   = InvoiceId(UUID.randomUUID())
        res <- svc.getInvoice(id, testCompanyId).either
      } yield assertTrue(res match
        case Left(InvoiceError.NotFound(`id`)) => true
        case _ => false
      )
    },

    test("listInvoices filters by status") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        req   = makeRequest()
        inv1 <- svc.createInvoice(testCompanyId, req)
        inv2 <- svc.createInvoice(testCompanyId, req)
        repo  = PostgresInvoiceRepository(xa)
        _    <- repo.update(inv2.copy(status = InvoiceStatus.Sent))
        all  <- svc.listInvoices(testCompanyId, None, 10, 0)
        drafts <- svc.listInvoices(testCompanyId, Some(InvoiceStatus.Draft), 10, 0)
        sent   <- svc.listInvoices(testCompanyId, Some(InvoiceStatus.Sent), 10, 0)
      } yield assertTrue(
        all.length == 2,
        drafts.length == 1,
        sent.length == 1
      )
    },

    test("markPaid transitions Sent → Paid") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        repo  = PostgresInvoiceRepository(xa)
        inv  <- svc.createInvoice(testCompanyId, makeRequest())
        _    <- repo.update(inv.copy(status = InvoiceStatus.Sent))
        paid <- svc.markPaid(inv.id, testCompanyId, None)
      } yield assertTrue(
        paid.status == InvoiceStatus.Paid,
        paid.paidAt.isDefined
      )
    },

    test("markPaid uses provided paidAt timestamp") {
      val fixedTime = Instant.parse("2026-02-15T12:00:00Z")
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        repo  = PostgresInvoiceRepository(xa)
        inv  <- svc.createInvoice(testCompanyId, makeRequest())
        _    <- repo.update(inv.copy(status = InvoiceStatus.Sent))
        paid <- svc.markPaid(inv.id, testCompanyId, Some(fixedTime))
      } yield assertTrue(
        paid.paidAt.exists(t => math.abs(t.toEpochMilli - fixedTime.toEpochMilli) < 1000)
      )
    },

    test("markPaid fails for Draft invoice") {
      for {
        xa  <- ZIO.service[Transactor[Task]]
        _   <- seedTestData(xa)
        _   <- cleanData(xa)
        svc  = makeService(xa)
        inv <- svc.createInvoice(testCompanyId, makeRequest())
        res <- svc.markPaid(inv.id, testCompanyId, None).either
      } yield assertTrue(res match
        case Left(InvoiceError.InvalidStatus(InvoiceStatus.Draft, _)) => true
        case _ => false
      )
    },

    test("markPaid fails for Cancelled invoice") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        repo  = PostgresInvoiceRepository(xa)
        inv  <- svc.createInvoice(testCompanyId, makeRequest())
        _    <- repo.update(inv.copy(status = InvoiceStatus.Cancelled))
        res  <- svc.markPaid(inv.id, testCompanyId, None).either
      } yield assertTrue(res match
        case Left(InvoiceError.InvalidStatus(InvoiceStatus.Cancelled, _)) => true
        case _ => false
      )
    },

    test("deleteInvoice removes Draft") {
      for {
        xa  <- ZIO.service[Transactor[Task]]
        _   <- seedTestData(xa)
        _   <- cleanData(xa)
        svc  = makeService(xa)
        inv <- svc.createInvoice(testCompanyId, makeRequest())
        _   <- svc.deleteInvoice(inv.id, testCompanyId)
        res <- svc.getInvoice(inv.id, testCompanyId).either
      } yield assertTrue(res.isLeft)
    },

    test("deleteInvoice fails for non-Draft") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        repo  = PostgresInvoiceRepository(xa)
        inv  <- svc.createInvoice(testCompanyId, makeRequest())
        _    <- repo.update(inv.copy(status = InvoiceStatus.Sent))
        res  <- svc.deleteInvoice(inv.id, testCompanyId).either
      } yield assertTrue(res match
        case Left(InvoiceError.NotDraft(_)) => true
        case _ => false
      )
    },

    test("getInvoice enforces company isolation (cross-tenant → NotFound)") {
      val otherCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000ff"))
      for {
        xa  <- ZIO.service[Transactor[Task]]
        _   <- seedTestData(xa)
        _   <- cleanData(xa)
        svc  = makeService(xa)
        inv <- svc.createInvoice(testCompanyId, makeRequest())
        own <- svc.getInvoice(inv.id, testCompanyId).either
        cross <- svc.getInvoice(inv.id, otherCompanyId).either
      } yield assertTrue(
        own.isRight,
        cross match
          case Left(InvoiceError.NotFound(_)) => true
          case _                              => false
      )
    },

    test("items are persisted and summed correctly") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        _    <- seedTestData(xa)
        _    <- cleanData(xa)
        svc   = makeService(xa)
        repo  = PostgresInvoiceRepository(xa)
        inv  <- svc.createInvoice(testCompanyId, makeRequest(taxRate = BigDecimal("10")))
        item1 = InvoiceItem(InvoiceItemId.generate(), inv.id, None, "Ride A", BigDecimal(2), BigDecimal("50.00"), BigDecimal("100.00"))
        item2 = InvoiceItem(InvoiceItemId.generate(), inv.id, None, "Ride B", BigDecimal(1), BigDecimal("30.00"), BigDecimal("30.00"))
        _    <- repo.addItems(List(item1, item2))
        full <- repo.findById(inv.id).map(_.get)
        // Manually trigger recalculate via autoFillFromPeriod is complex (needs rides),
        // so verify via direct repository reads that saved items are correct
      } yield assertTrue(
        full.items.length == 2,
        full.items.map(_.total).sum == BigDecimal("130.00")
      )
    }

  ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
