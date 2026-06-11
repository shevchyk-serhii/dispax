package com.shevchyk.app

import com.shevchyk.billing.application.{InvoiceService, PaymentChecker}
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{InvoiceRepository, UnbilledRide}
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}
import zio.*
import zio.test.*

import java.time.{Instant, LocalDate}
import java.util.UUID

object InvoiceReminderSchedulerSpec extends ZIOSpecDefault:

  private val taxiCompanyId   = CompanyId(UUID.randomUUID())
  private val clientCompanyId = ClientCompanyId(UUID.randomUUID())

  private def overdueInvoice(number: String): Invoice = Invoice(
    id = InvoiceId.generate(),
    number = number,
    clientCompanyId = clientCompanyId,
    taxiCompanyId = taxiCompanyId,
    status = InvoiceStatus.Sent,
    periodFrom = LocalDate.of(2026, 1, 1),
    periodTo = LocalDate.of(2026, 1, 31),
    subtotalAmount = BigDecimal(100),
    taxRate = BigDecimal(19),
    taxAmount = BigDecimal(19),
    totalAmount = BigDecimal(119),
    dueDate = Some(LocalDate.of(2026, 2, 1))
  )

  // Records which service calls the scheduler made, per invoice.
  final case class Calls(reminded: List[InvoiceId], markedPaid: List[InvoiceId])

  // InvoiceService stub: only sendReminder/markPaid are exercised; the rest fail
  // loudly if the scheduler ever calls them (it shouldn't).
  private def serviceStub(
      ref: Ref[Calls],
      failReminderFor: Set[InvoiceId] = Set.empty
  ): InvoiceService =
    new InvoiceService:
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected InvoiceService.$m")

      def sendReminder(
          id: InvoiceId,
          companyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Invoice] =
        if failReminderFor.contains(id) then ZIO.fail(InvoiceError.NoRecipientEmail(id))
        else ref.update(c => c.copy(reminded = c.reminded :+ id)).as(overdueInvoice("X"))

      def markPaid(id: InvoiceId, companyId: CompanyId, paidAt: Option[Instant]): IO[InvoiceError, Invoice] = ref
        .update(c => c.copy(markedPaid = c.markedPaid :+ id))
        .as(overdueInvoice("X"))

      def createInvoice(taxiCompanyId: CompanyId, req: CreateInvoiceRequest): IO[InvoiceError, Invoice]          = nope(
        "createInvoice"
      )
      def getInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]                         = nope("getInvoice")
      def listInvoices(
          taxiCompanyId: CompanyId,
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[Invoice]] = nope("listInvoices")
      def autoFillFromPeriod(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]                 = nope(
        "autoFillFromPeriod"
      )
      def fillFromRides(id: InvoiceId, taxiCompanyId: CompanyId, rideIds: List[UUID]): IO[InvoiceError, Invoice] = nope(
        "fillFromRides"
      )
      def listBillableRides(
          taxiCompanyId: CompanyId,
          clientCompanyId: ClientCompanyId,
          from: Option[LocalDate],
          to: Option[LocalDate]
      ): Task[List[UnbilledRide]] = nope("listBillableRides")
      def generatePdf(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Array[Byte]] = nope("generatePdf")
      def generateRideReceipt(
          rideId: UUID,
          taxiCompanyId: CompanyId,
          taxRate: BigDecimal,
          companyName: String
      ): IO[InvoiceError, Array[Byte]] = nope("generateRideReceipt")
      def sendInvoice(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Invoice] = nope("sendInvoice")
      def deleteInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Unit]                         = nope("deleteInvoice")

  // InvoiceRepository stub: returns the given overdue set; everything else is unused.
  private def repoStub(overdue: List[Invoice]): InvoiceRepository =
    new InvoiceRepository:
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected InvoiceRepository.$m")

      def findOverdueUnpaid(now: Instant): Task[List[Invoice]] = ZIO.succeed(overdue)

      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]                               = nope("nextInvoiceNumber")
      def create(invoice: Invoice): Task[Invoice]                                                            = nope("create")
      def findById(id: InvoiceId): Task[Option[Invoice]]                                                     = nope("findById")
      def findByCompany(
          taxiCompanyId: CompanyId,
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[Invoice]] = nope("findByCompany")
      def update(invoice: Invoice): Task[Invoice]                                                            = nope("update")
      def delete(id: InvoiceId): Task[Boolean]                                                               = nope("delete")
      def addItems(items: List[InvoiceItem]): Task[Unit]                                                     = nope("addItems")
      def deleteItems(invoiceId: InvoiceId): Task[Unit]                                                      = nope("deleteItems")
      def replaceItems(invoiceId: InvoiceId, taxiCompanyId: CompanyId, items: List[InvoiceItem]): Task[Unit] = nope(
        "replaceItems"
      )
      def unlinkRides(invoiceId: InvoiceId, taxiCompanyId: CompanyId): Task[Unit]                            = nope("unlinkRides")
      def findUnbilledRides(
          clientCompanyId: ClientCompanyId,
          from: LocalDate,
          to: LocalDate
      ): Task[List[UnbilledRide]] = nope("findUnbilledRides")
      def findBillableRides(
          taxiCompanyId: CompanyId,
          clientCompanyId: ClientCompanyId,
          from: Option[LocalDate],
          to: Option[LocalDate]
      ): Task[List[UnbilledRide]] = nope("findBillableRides")
      def findRidesByIds(taxiCompanyId: CompanyId, rideIds: List[UUID]): Task[List[UnbilledRide]]            = nope(
        "findRidesByIds"
      )
      def findRideForReceipt(taxiCompanyId: CompanyId, rideId: UUID): Task[Option[UnbilledRide]]             = nope(
        "findRideForReceipt"
      )

  private def paymentStub(paid: Boolean): PaymentChecker =
    new PaymentChecker:
      def isPaid(invoice: Invoice): Task[Boolean] = ZIO.succeed(paid)

  // Drives exactly one scheduler sweep with the given stubs.
  private def runTick(
      overdue: List[Invoice],
      paid: Boolean,
      calls: Ref[Calls],
      failReminderFor: Set[InvoiceId] = Set.empty
  ): Task[Unit] = InvoiceReminderScheduler.tick.provide(
    ZLayer.succeed(serviceStub(calls, failReminderFor)),
    ZLayer.succeed(repoStub(overdue)),
    ZLayer.succeed(paymentStub(paid))
  )

  def spec =
    suite("InvoiceReminderScheduler.tick")(
      test("sends a reminder for an overdue, unpaid invoice (PaymentChecker says unpaid)") {
        val inv = overdueInvoice("INV-2026-0001")
        for
          calls <- Ref.make(Calls(Nil, Nil))
          _     <- runTick(List(inv), paid = false, calls)
          c     <- calls.get
        yield assertTrue(c.reminded == List(inv.id), c.markedPaid.isEmpty)
      },
      test("marks the invoice paid instead of reminding when PaymentChecker reports it paid") {
        val inv = overdueInvoice("INV-2026-0002")
        for
          calls <- Ref.make(Calls(Nil, Nil))
          _     <- runTick(List(inv), paid = true, calls)
          c     <- calls.get
        yield assertTrue(c.markedPaid == List(inv.id), c.reminded.isEmpty)
      },
      test("does nothing when there are no overdue invoices") {
        for
          calls <- Ref.make(Calls(Nil, Nil))
          _     <- runTick(Nil, paid = false, calls)
          c     <- calls.get
        yield assertTrue(c.reminded.isEmpty, c.markedPaid.isEmpty)
      },
      test("a failing invoice does not stop the rest of the batch") {
        val bad  = overdueInvoice("INV-2026-BAD")
        val good = overdueInvoice("INV-2026-GOOD")
        for
          calls <- Ref.make(Calls(Nil, Nil))
          // tick must not fail even though sendReminder fails for `bad`.
          _     <- runTick(List(bad, good), paid = false, calls, failReminderFor = Set(bad.id))
          c     <- calls.get
        yield assertTrue(c.reminded == List(good.id), c.markedPaid.isEmpty)
      }
    )
