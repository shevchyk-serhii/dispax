package com.shevchyk.billing.integration

import com.shevchyk.billing.application.{InvoiceService, InvoiceServiceImpl}
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{
  PostgresClientCompanyRepository,
  PostgresCompanyBillingProfileRepository,
  PostgresInvoiceRepository
}
import com.shevchyk.core.application.InvoiceEmailData
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

  val testCompanyId   = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000011"))
  val clientCompanyId = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000011"))
  val clientPersonId  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000011"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'Service Test GmbH', 'svc@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                 VALUES (${clientCompanyId.value}, 'Service Client GmbH', ${testCompanyId.value}, 'svclient@test.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
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

  // No-op email transport for tests: sendInvoice/sendReminder shouldn't need a real mailer here.
  private val noopEmail =
    new com.shevchyk.core.application.EmailSmsService:
      def sendRideConfirmation(d: com.shevchyk.core.application.RideConfirmationData): Task[Unit] = ZIO.unit
      def sendDriverAssignment(d: com.shevchyk.core.application.RideConfirmationData): Task[Unit] = ZIO.unit
      def sendInvoiceEmail(d: com.shevchyk.core.application.InvoiceEmailData): Task[Unit]         = ZIO.unit

  private def makeService(xa: Transactor[Task]): InvoiceService = InvoiceServiceImpl(
    PostgresInvoiceRepository(xa),
    PostgresClientCompanyRepository(xa),
    PostgresCompanyBillingProfileRepository(xa),
    noopEmail
  )

  def spec =
    suite("InvoiceService")(
      test("createInvoice creates a Draft invoice with sequential number") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanData(xa)
          svc  = makeService(xa)
          inv <- svc.createInvoice(testCompanyId, makeRequest())
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
          case _                                                     => false
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
          case _                                 => false
        )
      },
      test("listInvoices filters by status") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          svc     = makeService(xa)
          req     = makeRequest()
          inv1   <- svc.createInvoice(testCompanyId, req)
          inv2   <- svc.createInvoice(testCompanyId, req)
          repo    = PostgresInvoiceRepository(xa)
          _      <- repo.update(inv2.copy(status = InvoiceStatus.Sent))
          all    <- svc.listInvoices(testCompanyId, None, 10, 0)
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
          case _                                                        => false
        )
      },
      test("markPaid fails for Cancelled invoice") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanData(xa)
          svc  = makeService(xa)
          repo = PostgresInvoiceRepository(xa)
          inv <- svc.createInvoice(testCompanyId, makeRequest())
          _   <- repo.update(inv.copy(status = InvoiceStatus.Cancelled))
          res <- svc.markPaid(inv.id, testCompanyId, None).either
        } yield assertTrue(res match
          case Left(InvoiceError.InvalidStatus(InvoiceStatus.Cancelled, _)) => true
          case _                                                            => false
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
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanData(xa)
          svc  = makeService(xa)
          repo = PostgresInvoiceRepository(xa)
          inv <- svc.createInvoice(testCompanyId, makeRequest())
          _   <- repo.update(inv.copy(status = InvoiceStatus.Sent))
          res <- svc.deleteInvoice(inv.id, testCompanyId).either
        } yield assertTrue(res match
          case Left(InvoiceError.NotDraft(_)) => true
          case _                              => false
        )
      },
      test("getInvoice enforces company isolation (cross-tenant → NotFound)") {
        val otherCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000ff"))
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanData(xa)
          svc    = makeService(xa)
          inv   <- svc.createInvoice(testCompanyId, makeRequest())
          own   <- svc.getInvoice(inv.id, testCompanyId).either
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
          item1 = InvoiceItem(
                    InvoiceItemId.generate(),
                    inv.id,
                    None,
                    "Ride A",
                    BigDecimal(2),
                    BigDecimal("50.00"),
                    BigDecimal("100.00")
                  )
          item2 = InvoiceItem(
                    InvoiceItemId.generate(),
                    inv.id,
                    None,
                    "Ride B",
                    BigDecimal(1),
                    BigDecimal("30.00"),
                    BigDecimal("30.00")
                  )
          _    <- repo.addItems(List(item1, item2))
          full <- repo.findById(inv.id).map(_.get)
          // Manually trigger recalculate via autoFillFromPeriod is complex (needs rides),
          // so verify via direct repository reads that saved items are correct
        } yield assertTrue(
          full.items.length == 2,
          full.items.map(_.total).sum == BigDecimal("130.00")
        )
      },
      // -- Edge cases added by test audit 2026-06 -----------------------------
      test("autoFillFromPeriod fails for non-Draft invoice") {
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedTestData(xa)
          _   <- cleanData(xa)
          svc  = makeService(xa)
          repo = PostgresInvoiceRepository(xa)
          inv <- svc.createInvoice(testCompanyId, makeRequest())
          _   <- repo.update(inv.copy(status = InvoiceStatus.Sent))
          res <- svc.autoFillFromPeriod(inv.id, testCompanyId).either
        } yield assertTrue(res match
          case Left(InvoiceError.NotDraft(_)) => true
          case _                              => false
        )
      },
      test("autoFillFromPeriod with taxRate=0 yields zero tax and total == subtotal") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          _      <- insertCompletedRide(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest(taxRate = BigDecimal("0")))
          filled <- svc.autoFillFromPeriod(inv.id, testCompanyId)
        } yield assertTrue(
          filled.subtotalAmount == BigDecimal("40.00"),
          filled.taxAmount == BigDecimal(0),
          filled.totalAmount == filled.subtotalAmount
        )
      },
      test("autoFillFromPeriod rounds fractional tax to 2 decimals (HALF_UP)") {
        // 33.33 * 19% = 6.3327 → rounded to 6.33; total 33.33 + 6.33 = 39.66.
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          _      <- insertCompletedRide(xa, BigDecimal("33.33"), LocalDate.of(2026, 1, 12))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest(taxRate = BigDecimal("19")))
          filled <- svc.autoFillFromPeriod(inv.id, testCompanyId)
        } yield assertTrue(
          filled.subtotalAmount == BigDecimal("33.33"),
          filled.taxAmount == BigDecimal("6.33"),
          filled.totalAmount == BigDecimal("39.66"),
          // Rounded values must carry exactly 2 decimal places.
          filled.taxAmount.scale == 2,
          filled.totalAmount.scale == 2
        )
      },
      test("autoFillFromPeriod links billed rides to the invoice") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          filled <- svc.autoFillFromPeriod(inv.id, testCompanyId)
          linked <- rideInvoiceId(xa, rideId)
        } yield assertTrue(
          filled.items.length == 1,
          linked.contains(inv.id.value)
        )
      },
      test("autoFillFromPeriod is idempotent: a second run does not duplicate items") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          _      <- insertCompletedRide(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          first  <- svc.autoFillFromPeriod(inv.id, testCompanyId)
          second <- svc.autoFillFromPeriod(inv.id, testCompanyId)
        } yield assertTrue(
          first.items.length == 1,
          // Re-running must not pick the ride up twice nor accumulate items.
          second.items.length == 1,
          second.subtotalAmount == first.subtotalAmount
        )
      },
      test("deleteInvoice unlinks its rides (FK ON DELETE SET NULL)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          _      <- svc.autoFillFromPeriod(inv.id, testCompanyId)
          _      <- svc.deleteInvoice(inv.id, testCompanyId)
          linked <- rideInvoiceId(xa, rideId)
        } yield assertTrue(linked.isEmpty)
      },
      test("autoFillFromPeriod never links a ride owned by another company") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedTestData(xa)
          _           <- cleanData(xa)
          _           <- linkClientToCompany(xa)
          foreignRide <- insertForeignCompanyRide(xa, BigDecimal("99.00"), LocalDate.of(2026, 1, 15))
          svc          = makeService(xa)
          inv         <- svc.createInvoice(testCompanyId, makeRequest())
          _           <- svc.autoFillFromPeriod(inv.id, testCompanyId)
          foreignLink <- rideInvoiceId(xa, foreignRide)
        } yield assertTrue(
          // The ride matches the client company, but belongs to a different taxi company,
          // so the company-scoped UPDATE must leave it untouched.
          foreignLink.isEmpty
        )
      },
      test("fillFromRides links only the selected rides and leaves the rest unbilled") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          ride1  <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          ride2  <- insertCompletedRideReturningId(xa, BigDecimal("55.00"), LocalDate.of(2026, 1, 11))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          filled <- svc.fillFromRides(inv.id, testCompanyId, List(ride1))
          link1  <- rideInvoiceId(xa, ride1)
          link2  <- rideInvoiceId(xa, ride2)
        } yield assertTrue(
          filled.items.length == 1,
          filled.subtotalAmount == BigDecimal("40.00"),
          link1.contains(inv.id.value),
          link2.isEmpty
        )
      },
      test("fillFromRides rejects a ride from another client company (same taxi company)") {
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- cleanData(xa)
          _         <- linkClientToCompany(xa)
          otherRide <- insertOtherClientCompanyRide(xa, BigDecimal("70.00"), LocalDate.of(2026, 1, 13))
          svc        = makeService(xa)
          inv       <- svc.createInvoice(testCompanyId, makeRequest())
          result    <- svc.fillFromRides(inv.id, testCompanyId, List(otherRide)).either
          otherLink <- rideInvoiceId(xa, otherRide)
        } yield assertTrue(
          result match
            case Left(InvoiceError.RideNotBillable(id)) => id == otherRide
            case _                                      => false
          ,
          // Nothing must have been linked.
          otherLink.isEmpty
        )
      },
      test("fillFromRides rejects an already-billed ride") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv1   <- svc.createInvoice(testCompanyId, makeRequest())
          _      <- svc.fillFromRides(inv1.id, testCompanyId, List(rideId))
          inv2   <- svc.createInvoice(testCompanyId, makeRequest())
          result <- svc.fillFromRides(inv2.id, testCompanyId, List(rideId)).either
        } yield assertTrue(
          result match
            case Left(InvoiceError.RideNotBillable(id)) => id == rideId
            case _                                      => false
        )
      },
      test("fillFromRides rejects a non-completed ride") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertRequestedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          result <- svc.fillFromRides(inv.id, testCompanyId, List(rideId)).either
        } yield assertTrue(
          result match
            case Left(InvoiceError.RideNotBillable(id)) => id == rideId
            case _                                      => false
        )
      },
      test("fillFromRides fails for a non-Draft invoice") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          _      <- svc.fillFromRides(inv.id, testCompanyId, List(rideId))
          _      <- svc.sendInvoice(inv.id, testCompanyId, "Test GmbH", "/tmp")
          result <- svc.fillFromRides(inv.id, testCompanyId, List(rideId)).either
        } yield assertTrue(
          result match
            case Left(InvoiceError.NotDraft(_)) => true
            case _                              => false
        )
      },
      test("fillFromRides is idempotent: a re-run with the same ids does not duplicate") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          first  <- svc.fillFromRides(inv.id, testCompanyId, List(rideId))
          second <- svc.fillFromRides(inv.id, testCompanyId, List(rideId))
        } yield assertTrue(
          first.items.length == 1,
          second.items.length == 1,
          second.subtotalAmount == first.subtotalAmount
        )
      },
      test("fillFromRides never links a ride owned by another taxi company") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedTestData(xa)
          _           <- cleanData(xa)
          _           <- linkClientToCompany(xa)
          foreignRide <- insertForeignCompanyRide(xa, BigDecimal("99.00"), LocalDate.of(2026, 1, 15))
          svc          = makeService(xa)
          inv         <- svc.createInvoice(testCompanyId, makeRequest())
          result      <- svc.fillFromRides(inv.id, testCompanyId, List(foreignRide)).either
          foreignLink <- rideInvoiceId(xa, foreignRide)
        } yield assertTrue(
          result match
            case Left(InvoiceError.RideNotBillable(id)) => id == foreignRide
            case _                                      => false
          ,
          foreignLink.isEmpty
        )
      },
      test("listBillableRides returns the client company's completed unbilled rides") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanData(xa)
          _     <- linkClientToCompany(xa)
          _     <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 1, 10))
          _     <- insertCompletedRideReturningId(xa, BigDecimal("55.00"), LocalDate.of(2026, 1, 11))
          svc    = makeService(xa)
          rides <- svc.listBillableRides(testCompanyId, clientCompanyId, None, None)
        } yield assertTrue(
          rides.length == 2,
          rides.forall(_.clientCompanyId == clientCompanyId.value)
        )
      },
      test("sendInvoice emails the invoice (isReminder=false) and transitions Draft → Sent") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          sent   <- Ref.make(List.empty[InvoiceEmailData])
          svc     = makeRecordingService(xa, sent)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          result <- svc.sendInvoice(inv.id, testCompanyId, "Test GmbH", storageDir)
          emails <- sent.get
        } yield assertTrue(
          result.status == InvoiceStatus.Sent,
          result.sentAt.isDefined,
          emails.length == 1,
          !emails.head.isReminder,
          emails.head.toEmail == "svclient@test.com",
          emails.head.invoiceNumber == inv.number,
          emails.head.pdfAttachment.nonEmpty
        )
      },
      test("sendInvoice fails with NoRecipientEmail when client company has no email") {
        // Uses a separate client company with NULL email so it doesn't mutate the shared seed row.
        val noEmailClient = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-000000000099"))
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <-
            sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                          VALUES (${noEmailClient.value}, 'No Email GmbH', ${testCompanyId.value}, NULL)
                          ON CONFLICT (id) DO UPDATE SET email = NULL""".update.run.transact(xa)
          sent   <- Ref.make(List.empty[InvoiceEmailData])
          svc     = makeRecordingService(xa, sent)
          inv    <- svc.createInvoice(testCompanyId, makeRequest(clientId = noEmailClient.value))
          result <- svc.sendInvoice(inv.id, testCompanyId, "Test GmbH", storageDir).either
          emails <- sent.get
        } yield assertTrue(
          result match
            case Left(InvoiceError.NoRecipientEmail(id)) => id == inv.id
            case _                                       => false
          ,
          emails.isEmpty
        )
      },
      test("sendReminder emails a reminder (isReminder=true) and stamps reminderSentAt once") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanData(xa)
          sent    <- Ref.make(List.empty[InvoiceEmailData])
          svc      = makeRecordingService(xa, sent)
          inv     <- svc.createInvoice(testCompanyId, makeRequest())
          _       <- svc.sendInvoice(inv.id, testCompanyId, "Test GmbH", storageDir)
          updated <- svc.sendReminder(inv.id, testCompanyId, "Test GmbH", storageDir)
          emails  <- sent.get
        } yield assertTrue(
          updated.reminderSentAt.isDefined,
          emails.length == 2,
          !emails.head.isReminder,
          emails(1).isReminder
        )
      },
      test("generateRideReceipt produces a PDF for a completed ride") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("159.00"), LocalDate.of(2026, 3, 5))
          svc     = makeService(xa)
          bytes  <- svc.generateRideReceipt(rideId, testCompanyId, BigDecimal("19"), "Test GmbH")
        } yield assertTrue(bytes.nonEmpty, bytes.take(4).sameElements("%PDF".getBytes("US-ASCII")))
      },
      test("generateRideReceipt works even after the ride has been billed") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("80.00"), LocalDate.of(2026, 3, 6))
          svc     = makeService(xa)
          inv    <- svc.createInvoice(testCompanyId, makeRequest())
          _      <- svc.fillFromRides(inv.id, testCompanyId, List(rideId))
          bytes  <- svc.generateRideReceipt(rideId, testCompanyId, BigDecimal("19"), "Test GmbH")
        } yield assertTrue(bytes.nonEmpty)
      },
      test("generateRideReceipt enforces company isolation (cross-tenant → RideNotBillable)") {
        val otherCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000ee"))
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanData(xa)
          _      <- linkClientToCompany(xa)
          rideId <- insertCompletedRideReturningId(xa, BigDecimal("40.00"), LocalDate.of(2026, 3, 7))
          svc     = makeService(xa)
          result <- svc.generateRideReceipt(rideId, otherCompanyId, BigDecimal("19"), "Test GmbH").either
        } yield assertTrue(result match
          case Left(InvoiceError.RideNotBillable(`rideId`)) => true
          case _                                            => false
        )
      },
      test("findOverdueUnpaid returns sent, unpaid, overdue, not-yet-reminded invoices") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanData(xa)
          repo     = PostgresInvoiceRepository(xa)
          sent    <- Ref.make(List.empty[InvoiceEmailData])
          svc      = makeRecordingService(xa, sent)
          // Overdue, sent, unpaid — should be picked up.
          overdue <- svc.createInvoice(
                       testCompanyId,
                       makeRequest().copy(dueDate = Some(LocalDate.now().minusDays(3)))
                     )
          _       <- svc.sendInvoice(overdue.id, testCompanyId, "Test GmbH", storageDir)
          // Still in the future — should be skipped.
          future  <- svc.createInvoice(
                       testCompanyId,
                       makeRequest().copy(dueDate = Some(LocalDate.now().plusDays(10)))
                     )
          _       <- svc.sendInvoice(future.id, testCompanyId, "Test GmbH", storageDir)
          found   <- repo.findOverdueUnpaid(java.time.Instant.now())
        } yield assertTrue(
          found.map(_.id).contains(overdue.id),
          !found.map(_.id).contains(future.id)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")

  private val storageDir = "/tmp/dispax-test-invoices"

  // Records every sent invoice email so tests can assert delivery and the isReminder flag.
  private def makeRecordingService(xa: Transactor[Task], sent: Ref[List[InvoiceEmailData]]): InvoiceService =
    val recording =
      new com.shevchyk.core.application.EmailSmsService:
        def sendRideConfirmation(d: com.shevchyk.core.application.RideConfirmationData): Task[Unit] = ZIO.unit
        def sendDriverAssignment(d: com.shevchyk.core.application.RideConfirmationData): Task[Unit] = ZIO.unit
        def sendInvoiceEmail(d: InvoiceEmailData): Task[Unit]                                       = sent.update(_ :+ d)
    InvoiceServiceImpl(
      PostgresInvoiceRepository(xa),
      PostgresClientCompanyRepository(xa),
      PostgresCompanyBillingProfileRepository(xa),
      recording
    )

  // Link the seeded client person to the client company so findUnbilledRides' JOIN matches.
  private def linkClientToCompany(xa: Transactor[Task]): Task[Unit] =
    sql"""UPDATE persons SET client_company_id = ${clientCompanyId.value}
          WHERE id = ${clientPersonId.value}""".update.run.transact(xa).unit

  private def insertCompletedRide(xa: Transactor[Task], price: BigDecimal, day: LocalDate): Task[Unit] =
    insertCompletedRideReturningId(xa, price, day).unit

  private def insertCompletedRideReturningId(xa: Transactor[Task], price: BigDecimal, day: LocalDate): Task[UUID] =
    val rideId = UUID.randomUUID()
    val pickup = day.atTime(10, 0).atZone(java.time.ZoneOffset.UTC).toInstant
    sql"""INSERT INTO rides
            (id, client_id, creator_id, company_id, from_address, to_address,
             pickup_datetime, status, final_price_amount)
          VALUES ($rideId, ${clientPersonId.value}, ${clientPersonId.value},
                  ${testCompanyId.value}, 'Pickup', 'Dropoff',
                  $pickup, 'Completed'::ride_status, $price)""".update.run.transact(xa).as(rideId)

  // A completed ride owned by a *different* company, but whose client belongs to our client company.
  private def insertForeignCompanyRide(xa: Transactor[Task], price: BigDecimal, day: LocalDate): Task[UUID] =
    val otherCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000aa"))
    val rideId         = UUID.randomUUID()
    val pickup         = day.atTime(10, 0).atZone(java.time.ZoneOffset.UTC).toInstant
    val program        =
      for {
        _ <-
          sql"""INSERT INTO companies (id, name, email)
                   VALUES (${otherCompanyId.value}, 'Other Taxi GmbH', 'other@test.com')
                   ON CONFLICT DO NOTHING""".update.run
        _ <-
          sql"""INSERT INTO rides
                     (id, client_id, creator_id, company_id, from_address, to_address,
                      pickup_datetime, status, final_price_amount)
                   VALUES ($rideId, ${clientPersonId.value}, ${clientPersonId.value},
                           ${otherCompanyId.value}, 'Pickup', 'Dropoff',
                           $pickup, 'Completed'::ride_status, $price)""".update.run
      } yield ()
    program.transact(xa).as(rideId)

  private def rideInvoiceId(xa: Transactor[Task], rideId: UUID): Task[Option[UUID]] =
    sql"SELECT invoice_id FROM rides WHERE id = $rideId".query[Option[UUID]].unique.transact(xa)

  // A completed ride of OUR taxi company, but whose client belongs to a DIFFERENT
  // client company — exercises the single-client-company rule in fillFromRides.
  private def insertOtherClientCompanyRide(xa: Transactor[Task], price: BigDecimal, day: LocalDate): Task[UUID] =
    val otherClientCompanyId = ClientCompanyId(UUID.fromString("00000003-0000-0000-0000-0000000000bb"))
    val otherClientPersonId  = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000bb"))
    val rideId               = UUID.randomUUID()
    val pickup               = day.atTime(10, 0).atZone(java.time.ZoneOffset.UTC).toInstant
    val program              =
      for {
        _ <-
          sql"""INSERT INTO client_companies (id, name, taxi_company_id, email)
                   VALUES (${otherClientCompanyId.value}, 'Other Client GmbH', ${testCompanyId.value}, 'otherclient@test.com')
                   ON CONFLICT DO NOTHING""".update.run
        _ <-
          sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash, client_company_id)
                   VALUES (${otherClientPersonId.value}, 'Other Client', 'otherclientp@test.com', 'client'::person_role,
                           ${testCompanyId.value}, 'placeholder', ${otherClientCompanyId.value})
                   ON CONFLICT DO NOTHING""".update.run
        _ <-
          sql"""INSERT INTO rides
                     (id, client_id, creator_id, company_id, from_address, to_address,
                      pickup_datetime, status, final_price_amount)
                   VALUES ($rideId, ${otherClientPersonId.value}, ${otherClientPersonId.value},
                           ${testCompanyId.value}, 'Pickup', 'Dropoff',
                           $pickup, 'Completed'::ride_status, $price)""".update.run
      } yield ()
    program.transact(xa).as(rideId)

  private def insertRequestedRideReturningId(xa: Transactor[Task], price: BigDecimal, day: LocalDate): Task[UUID] =
    val rideId = UUID.randomUUID()
    val pickup = day.atTime(10, 0).atZone(java.time.ZoneOffset.UTC).toInstant
    sql"""INSERT INTO rides
            (id, client_id, creator_id, company_id, from_address, to_address,
             pickup_datetime, status, final_price_amount)
          VALUES ($rideId, ${clientPersonId.value}, ${clientPersonId.value},
                  ${testCompanyId.value}, 'Pickup', 'Dropoff',
                  $pickup, 'Requested'::ride_status, $price)""".update.run.transact(xa).as(rideId)
}
