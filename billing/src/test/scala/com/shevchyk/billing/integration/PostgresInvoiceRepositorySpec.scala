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
        sql"""INSERT INTO persons (id, name, email, role, company_id, client_company_id, password_hash)
                 VALUES (${clientId.value}, 'Test Client', 'person@test.com', 'client'::person_role, ${testCompanyId.value}, ${clientCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  /**
   * Insert a Completed ride for the seeded client with the given prices. Either price may be None to model a price-less
   * ride (both None = the €0.00 case that must be excluded from invoicing).
   */
  private def seedRide(
      xa: Transactor[Task],
      rideId: UUID,
      estimated: Option[BigDecimal],
      finalPrice: Option[BigDecimal],
      pickup: Instant = Instant.parse("2026-01-15T10:00:00Z")
  ): Task[Unit] =
    sql"""INSERT INTO rides
            (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime, status,
             estimated_price_amount, final_price_amount)
          VALUES
            ($rideId, ${clientId.value}, ${clientId.value}, ${testCompanyId.value},
             'Marienplatz', 'Flughafen', $pickup, 'Completed'::ride_status, $estimated, $finalPrice)
          ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  /**
   * Insert a provisional client (linked to the seeded client company) plus a priced, Completed ride for it. Models the
   * reachable case where a provisional client carries a clientCompanyId but keeps provisional = true — such rides must
   * stay out of the billable set (NOT p.provisional).
   */
  private def seedProvisionalClientWithRide(
      xa: Transactor[Task],
      provClientId: UUID,
      rideId: UUID,
      price: BigDecimal
  ): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, client_company_id, password_hash, provisional)
                 VALUES ($provClientId, 'Walk-in', ${s"prov+$provClientId@test.local"}, 'client'::person_role,
                         ${testCompanyId.value}, ${clientCompanyId.value}, 'placeholder', true)
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO rides
                (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime, status,
                 estimated_price_amount, final_price_amount)
              VALUES
                ($rideId, $provClientId, $provClientId, ${testCompanyId.value},
                 'Marienplatz', 'Flughafen', ${Instant.parse("2026-01-16T10:00:00Z")}, 'Completed'::ride_status,
                 $price, NULL)
              ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM rides WHERE company_id = ${testCompanyId.value}".update.run.transact(xa).unit

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
          cross   <- repo.delete(invoice.id, CompanyId(UUID.randomUUID())) // cross-tenant: no-op
          still   <- repo.findById(invoice.id)
          deleted <- repo.delete(invoice.id, testCompanyId)
          found   <- repo.findById(invoice.id)
        } yield assertTrue(!cross, still.isDefined, deleted, found.isEmpty)
      },
      test("delete does not remove non-draft invoice") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanInvoices(xa)
          repo     = PostgresInvoiceRepository(xa)
          invoice  = makeInvoice(status = InvoiceStatus.Sent)
          _       <- repo.create(invoice)
          deleted <- repo.delete(invoice.id, testCompanyId)
        } yield assertTrue(!deleted)
      },
      test("findById fails on a corrupted status instead of silently reading Draft") {
        // Regression: a paid invoice whose status column is corrupted/unknown must
        // NOT be read back as Draft. The read has to fail loudly.
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanInvoices(xa)
          repo    = PostgresInvoiceRepository(xa)
          invoice = makeInvoice()
          _      <- repo.create(invoice)
          _      <- sql"UPDATE invoices SET status = 'totally-bogus' WHERE id = ${invoice.id.value}".update.run
                      .transact(xa)
          result <- repo.findById(invoice.id).either
        } yield assertTrue(
          result.isLeft,
          result.left.toOption.exists(_.isInstanceOf[InvoiceError.DatabaseError])
        )
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
      },
      // -------------------------------------------------------------------------
      // Platform-level (cross-tenant) analytics — Testcontainers integration
      // These tests insert invoices for TWO different companies and assert that
      // the platform methods aggregate across company boundaries (no company_id
      // filter) and that per-company breakdowns split correctly.
      // -------------------------------------------------------------------------
      test("findAllPlatform returns invoices from both companies (cross-tenant)") {
        val company2Id       = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        val clientCompany2Id = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000002"))
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <-
            (for {
              _ <-
                sql"""INSERT INTO companies (id, name, email)
                                 VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
              _ <-
                sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                                 VALUES (${clientCompany2Id.value}, 'Client 2 GmbH', ${company2Id.value}, 'client2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
            } yield ()).transact(xa)
          _   <- cleanInvoices(xa)
          repo = PostgresInvoiceRepository(xa)
          // Company 1: 1 Draft invoice
          _   <- repo.create(makeInvoice(number = "INV-2026-C1-001", status = InvoiceStatus.Draft))
          // Company 2: 1 Sent invoice
          _   <- repo.create(
                   makeInvoice(number = "INV-2026-C2-001", status = InvoiceStatus.Sent)
                     .copy(clientCompanyId = clientCompany2Id, taxiCompanyId = company2Id)
                 )
          all <- repo.findAllPlatform(None, 100, 0)
          nums = all.map(_.number)
        } yield assertTrue(
          // Both companies' invoices are returned — no company_id filter applied
          nums.contains("INV-2026-C1-001"),
          nums.contains("INV-2026-C2-001"),
          all.length == 2
        )
      },
      test("findAllPlatform filters by status across all companies") {
        val company2Id       = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        val clientCompany2Id = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000002"))
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <-
            (for {
              _ <-
                sql"""INSERT INTO companies (id, name, email)
                                 VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
              _ <-
                sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                                 VALUES (${clientCompany2Id.value}, 'Client 2 GmbH', ${company2Id.value}, 'client2@test.com')
                                 ON CONFLICT DO NOTHING""".update.run
            } yield ()).transact(xa)
          _    <- cleanInvoices(xa)
          repo  = PostgresInvoiceRepository(xa)
          _    <- repo.create(makeInvoice(number = "INV-DRAFT-C1", status = InvoiceStatus.Draft))
          _    <- repo.create(
                    makeInvoice(number = "INV-SENT-C2", status = InvoiceStatus.Sent)
                      .copy(clientCompanyId = clientCompany2Id, taxiCompanyId = company2Id)
                  )
          // Filter for Sent only — should return only company2's invoice
          sent <- repo.findAllPlatform(Some(InvoiceStatus.Sent), 100, 0)
        } yield assertTrue(
          sent.length == 1,
          sent.head.number == "INV-SENT-C2",
          sent.head.taxiCompanyId == company2Id
        )
      },
      test("sumRevenueByCompany splits Paid invoice totals by company") {
        val company2Id       = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        val clientCompany2Id = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000002"))
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <-
            (for {
              _ <-
                sql"""INSERT INTO companies (id, name, email)
                                    VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                    ON CONFLICT DO NOTHING""".update.run
              _ <-
                sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                                    VALUES (${clientCompany2Id.value}, 'Client 2 GmbH', ${company2Id.value}, 'client2@test.com')
                                    ON CONFLICT DO NOTHING""".update.run
            } yield ()).transact(xa)
          _       <- cleanInvoices(xa)
          repo     = PostgresInvoiceRepository(xa)
          now      = Instant.now()
          from     = now.minusSeconds(3600 * 24 * 7)
          to       = now.plusSeconds(3600)
          // Company 1: Paid invoice worth 300
          _       <- repo.create(
                       makeInvoice(number = "INV-PAID-C1", status = InvoiceStatus.Paid)
                         .copy(totalAmount = BigDecimal("300.00"))
                     )
          // Company 2: Paid invoice worth 500
          _       <- repo.create(
                       makeInvoice(number = "INV-PAID-C2", status = InvoiceStatus.Paid)
                         .copy(
                           clientCompanyId = clientCompany2Id,
                           taxiCompanyId = company2Id,
                           totalAmount = BigDecimal("500.00")
                         )
                     )
          // Draft invoice must NOT count towards revenue
          _       <- repo.create(
                       makeInvoice(number = "INV-DRAFT-C1", status = InvoiceStatus.Draft)
                         .copy(totalAmount = BigDecimal("999.00"))
                     )
          revenue <- repo.sumRevenueByCompany(from, to)
        } yield assertTrue(
          // Company 1 and Company 2 appear separately; draft invoice excluded
          revenue.getOrElse(testCompanyId.value, BigDecimal("0")) == BigDecimal("300.00"),
          revenue.getOrElse(company2Id.value, BigDecimal("0")) == BigDecimal("500.00")
        )
      },
      test("countOverdueByCompany counts sent invoices past due date by company") {
        val company2Id       = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
        val clientCompany2Id = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000002"))
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedTestData(xa)
          _        <-
            (for {
              _ <-
                sql"""INSERT INTO companies (id, name, email)
                                   VALUES (${company2Id.value}, 'Company 2 GmbH', 'c2@test.com')
                                   ON CONFLICT DO NOTHING""".update.run
              _ <-
                sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                                   VALUES (${clientCompany2Id.value}, 'Client 2 GmbH', ${company2Id.value}, 'client2@test.com')
                                   ON CONFLICT DO NOTHING""".update.run
            } yield ()).transact(xa)
          _        <- cleanInvoices(xa)
          repo      = PostgresInvoiceRepository(xa)
          pastDue   = LocalDate.of(2020, 1, 1)   // safely in the past
          futureDue = LocalDate.of(2099, 12, 31) // safely in the future
          // Company 1: 2 overdue (sent + past due date)
          _        <- repo.create(
                        makeInvoice(number = "INV-OVD-C1-1", status = InvoiceStatus.Sent)
                          .copy(dueDate = Some(pastDue))
                      )
          _        <- repo.create(
                        makeInvoice(number = "INV-OVD-C1-2", status = InvoiceStatus.Sent)
                          .copy(dueDate = Some(pastDue))
                      )
          // Company 1: 1 sent but NOT overdue (future due date) — must NOT count
          _        <- repo.create(
                        makeInvoice(number = "INV-NOT-OVD-C1", status = InvoiceStatus.Sent)
                          .copy(dueDate = Some(futureDue))
                      )
          // Company 2: 1 overdue
          _        <- repo.create(
                        makeInvoice(number = "INV-OVD-C2", status = InvoiceStatus.Sent)
                          .copy(
                            clientCompanyId = clientCompany2Id,
                            taxiCompanyId = company2Id,
                            dueDate = Some(pastDue)
                          )
                      )
          // Draft invoice with past due date — must NOT count (wrong status)
          _        <- repo.create(
                        makeInvoice(number = "INV-DRAFT-C1", status = InvoiceStatus.Draft)
                          .copy(dueDate = Some(pastDue))
                      )
          counts   <- repo.countOverdueByCompany()
        } yield assertTrue(
          // Company 1 has 2 overdue; company 2 has 1; both appear in the map
          counts.getOrElse(testCompanyId.value, 0) == 2,
          counts.getOrElse(company2Id.value, 0) == 1
        )
      },
      // ── provisional-client rides excluded from the billable set (regression for the auto-fill/manual
      //    divergence: period auto-fill now shares findBillableRides, so a provisional client that happens to
      //    carry a clientCompanyId must NOT be billed) ──
      test("findBillableRides excludes a provisional client's ride even with a clientCompanyId") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedTestData(xa)
          _           <- cleanRides(xa)
          repo         = PostgresInvoiceRepository(xa)
          normalRide   = UUID.randomUUID()
          provRide     = UUID.randomUUID()
          provClient   = UUID.randomUUID()
          _           <- seedRide(xa, normalRide, estimated = Some(BigDecimal("42.00")), finalPrice = None)
          // A provisional client linked to the SAME client company, with a priced completed ride.
          _           <- seedProvisionalClientWithRide(xa, provClient, provRide, price = BigDecimal("77.00"))
          rides       <- repo.findBillableRides(testCompanyId, clientCompanyId, None, None)
        } yield assertTrue(
          // Only the normal client's ride is billable; the provisional one is excluded by NOT p.provisional.
          rides.map(_.rideId).toSet == Set(normalRide)
        )
      },
      test("findBillableRides also skips price-less rides") {
        for {
          xa       <- ZIO.service[Transactor[Task]]
          _        <- seedTestData(xa)
          _        <- cleanRides(xa)
          repo      = PostgresInvoiceRepository(xa)
          priced    = UUID.randomUUID()
          priceless = UUID.randomUUID()
          _        <- seedRide(xa, priced, estimated = None, finalPrice = Some(BigDecimal("99.00")))
          _        <- seedRide(xa, priceless, estimated = None, finalPrice = None)
          rides    <- repo.findBillableRides(testCompanyId, clientCompanyId, None, None)
        } yield assertTrue(rides.map(_.rideId).toSet == Set(priced))
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
