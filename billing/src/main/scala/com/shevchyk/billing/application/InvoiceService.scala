package com.shevchyk.billing.application

import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{ClientCompanyRepository, CompanyBillingProfileRepository, InvoiceRepository}
import com.shevchyk.core.application.{EmailSmsService, InvoiceEmailData}
import com.shevchyk.core.domain.CompanyId
import zio.*

import java.time.{Instant, LocalDate}
import java.util.UUID

trait InvoiceService:
  def createInvoice(taxiCompanyId: CompanyId, req: CreateInvoiceRequest): IO[InvoiceError, Invoice]
  def getInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]

  def listInvoices(
      taxiCompanyId: CompanyId,
      status: Option[InvoiceStatus],
      limit: Int,
      offset: Int
  ): Task[List[Invoice]]
  def autoFillFromPeriod(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]
  // Fill a draft invoice from an explicit set of rides (per-ride billing). All
  // rideIds must be completed/unbilled rides of this taxi company AND belong to
  // the invoice's client company, otherwise fails with RideNotBillable.
  def fillFromRides(id: InvoiceId, taxiCompanyId: CompanyId, rideIds: List[UUID]): IO[InvoiceError, Invoice]

  // Lists completed, unbilled rides of a client company (taxi-company scoped),
  // optionally bounded by a pickup-date range — the selection table source.
  def listBillableRides(
      taxiCompanyId: CompanyId,
      clientCompanyId: com.shevchyk.core.domain.ClientCompanyId,
      from: Option[LocalDate],
      to: Option[LocalDate]
  ): Task[List[com.shevchyk.billing.repository.UnbilledRide]]

  def generatePdf(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Array[Byte]]

  // Generates a single-ride German taxi receipt ("Quittung") PDF, independent of
  // any invoice. The ride's price is treated as gross (Brutto); recipient is the
  // ride's client company; issuer is the company's billing profile.
  def generateRideReceipt(
      rideId: UUID,
      taxiCompanyId: CompanyId,
      taxRate: BigDecimal,
      companyName: String
  ): IO[InvoiceError, Array[Byte]]

  def sendInvoice(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Invoice]

  // Re-sends a sent-but-overdue invoice as a payment reminder (PDF attached) and
  // stamps reminderSentAt so it's sent at most once. Used by the background scheduler.
  def sendReminder(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Invoice]
  def markPaid(id: InvoiceId, taxiCompanyId: CompanyId, paidAt: Option[Instant]): IO[InvoiceError, Invoice]
  def deleteInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Unit]

class InvoiceServiceImpl(
    invoiceRepo: InvoiceRepository,
    clientCompanyRepo: ClientCompanyRepository,
    billingProfileRepo: CompanyBillingProfileRepository,
    emailService: EmailSmsService,
    defaultEmailLanguage: String = "de"
) extends InvoiceService:

  override def createInvoice(taxiCompanyId: CompanyId, req: CreateInvoiceRequest): IO[InvoiceError, Invoice] =
    for {
      // A tax rate outside [0, 100] distorts Netto/MwSt (at -100 it divides by zero in `recalculate`).
      _      <- ZIO.when(req.taxRate < 0 || req.taxRate > 100)(ZIO.fail(InvoiceError.InvalidTaxRate(req.taxRate)))
      year   <- ZIO.succeed(req.periodFrom.getYear)
      number <- invoiceRepo.nextInvoiceNumber(taxiCompanyId, year).mapError(InvoiceError.DatabaseError(_))
      _      <- clientCompanyRepo
                  .findById(com.shevchyk.core.domain.ClientCompanyId(req.clientCompanyId))
                  .mapError(InvoiceError.DatabaseError(_))
                  .flatMap(ZIO.fromOption(_).orElseFail(InvoiceError.ClientCompanyNotFound(req.clientCompanyId)))
      invoice = Invoice(
                  id = InvoiceId.generate(),
                  number = number,
                  clientCompanyId = com.shevchyk.core.domain.ClientCompanyId(req.clientCompanyId),
                  taxiCompanyId = taxiCompanyId,
                  status = InvoiceStatus.Draft,
                  periodFrom = req.periodFrom,
                  periodTo = req.periodTo,
                  subtotalAmount = BigDecimal(0),
                  taxRate = req.taxRate,
                  taxAmount = BigDecimal(0),
                  totalAmount = BigDecimal(0),
                  currency = req.currency,
                  notes = req.notes,
                  dueDate = req.dueDate
                )
      saved  <- invoiceRepo.create(invoice).mapError(InvoiceError.DatabaseError(_))
    } yield saved

  override def getInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice] =
    invoiceRepo
      .findById(id)
      .mapError(InvoiceError.DatabaseError(_))
      .flatMap(ZIO.fromOption(_).orElseFail(InvoiceError.NotFound(id)))
      // Company isolation: treat cross-tenant access as not found to avoid leaking existence.
      .filterOrFail(_.taxiCompanyId == taxiCompanyId)(InvoiceError.NotFound(id))

  override def listInvoices(
      taxiCompanyId: CompanyId,
      status: Option[InvoiceStatus],
      limit: Int,
      offset: Int
  ): Task[List[Invoice]] = invoiceRepo.findByCompany(taxiCompanyId, status, limit, offset)

  override def autoFillFromPeriod(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      _       <-
        ZIO.when(invoice.status != InvoiceStatus.Draft)(
          ZIO.fail(InvoiceError.NotDraft(id))
        )
      // Detach this invoice's own rides first, so re-running auto-fill rebuilds from the same set
      // instead of emptying the invoice (its rides would otherwise no longer count as unbilled).
      _       <- invoiceRepo.unlinkRides(id, taxiCompanyId).mapError(InvoiceError.DatabaseError(_))
      rides   <- invoiceRepo
                   .findUnbilledRides(invoice.clientCompanyId, invoice.periodFrom, invoice.periodTo)
                   .mapError(InvoiceError.DatabaseError(_))
      items    = rides.map(rideToItem(id, _))
      _       <- invoiceRepo.replaceItems(id, taxiCompanyId, items).mapError(InvoiceError.DatabaseError(_))
      updated <- recalculate(invoice.copy(items = items))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved.copy(items = items)

  // One invoice line per ride; shared by period auto-fill and per-ride filling.
  private def rideToItem(invoiceId: InvoiceId, ride: com.shevchyk.billing.repository.UnbilledRide): InvoiceItem =
    InvoiceItem(
      id = InvoiceItemId.generate(),
      invoiceId = invoiceId,
      rideId = Some(ride.rideId),
      description = s"${ride.pickupAddress} - ${ride.dropoffAddress}",
      quantity = BigDecimal(1),
      unitPrice = ride.price,
      total = ride.price,
      createdAt = ride.pickupDatetime
    )

  override def fillFromRides(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      rideIds: List[UUID]
  ): IO[InvoiceError, Invoice] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      _       <- ZIO.when(invoice.status != InvoiceStatus.Draft)(ZIO.fail(InvoiceError.NotDraft(id)))
      // Detach this invoice's own rides first (idempotency, same as auto-fill):
      // a ride already on this draft must re-count as billable on a re-run.
      _       <- invoiceRepo.unlinkRides(id, taxiCompanyId).mapError(InvoiceError.DatabaseError(_))
      fetched <- invoiceRepo.findRidesByIds(taxiCompanyId, rideIds).mapError(InvoiceError.DatabaseError(_))
      // Every requested ride must come back from the company/status/unbilled-filtered
      // query — a missing one is not billable on this invoice.
      missing  = rideIds.toSet -- fetched.map(_.rideId).toSet
      _       <- ZIO.foreachDiscard(missing.headOption)(rid => ZIO.fail(InvoiceError.RideNotBillable(rid)))
      // Single-client-company rule: every ride must belong to the invoice's client company.
      foreign  = fetched.find(_.clientCompanyId != invoice.clientCompanyId.value)
      _       <- ZIO.foreachDiscard(foreign)(r => ZIO.fail(InvoiceError.RideNotBillable(r.rideId)))
      items    = fetched.map(rideToItem(id, _))
      _       <- invoiceRepo.replaceItems(id, taxiCompanyId, items).mapError(InvoiceError.DatabaseError(_))
      updated <- recalculate(invoice.copy(items = items))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved.copy(items = items)

  override def listBillableRides(
      taxiCompanyId: CompanyId,
      clientCompanyId: com.shevchyk.core.domain.ClientCompanyId,
      from: Option[LocalDate],
      to: Option[LocalDate]
  ): Task[List[com.shevchyk.billing.repository.UnbilledRide]] = invoiceRepo.findBillableRides(
    taxiCompanyId,
    clientCompanyId,
    from,
    to
  )

  override def generatePdf(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Array[Byte]] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      cc      <- clientCompanyRepo
                   .findById(invoice.clientCompanyId)
                   .mapError(InvoiceError.DatabaseError(_))
                   .flatMap(
                     ZIO.fromOption(_).orElseFail(InvoiceError.ClientCompanyNotFound(invoice.clientCompanyId.value))
                   )
      // Issuer details come from the company's billing profile; fall back to the plain name.
      profile <- billingProfileRepo
                   .findByCompany(taxiCompanyId)
                   .mapBoth(
                     InvoiceError.DatabaseError(_),
                     _.getOrElse(CompanyBillingProfile(taxiCompanyId, legalName = Some(companyName)))
                   )
      bytes   <- PdfGenerator
                   .generateBytes(invoice, cc, profile)
                   .mapError(InvoiceError.PdfGenerationError(_))
      // Sanitise the invoice number into a safe filename: whitelist alphanumerics, dot,
      // dash and underscore. `replace('/', '-')` alone left `..` path-traversal sequences
      // intact, which could write the PDF outside `storageDir`.
      safeName = invoice.number.replaceAll("[^A-Za-z0-9._-]", "_").replace("..", "__")
      path     = s"$storageDir/$safeName.pdf"
      _       <- PdfGenerator
                   .generateToFile(invoice, cc, profile, path)
                   .mapError(InvoiceError.PdfGenerationError(_))
      _       <- invoiceRepo
                   .update(invoice.copy(pdfPath = Some(path)))
                   .mapError(InvoiceError.DatabaseError(_))
    } yield bytes

  override def generateRideReceipt(
      rideId: UUID,
      taxiCompanyId: CompanyId,
      taxRate: BigDecimal,
      companyName: String
  ): IO[InvoiceError, Array[Byte]] =
    for {
      // Reject an out-of-range tax rate before touching the DB or PDF generator:
      // a negative rate yields Netto > Brutto, and exactly -100 divides by zero
      // in PdfGenerator (gross / (1 + taxRate/100)).
      _            <- ZIO
                        .fail(InvoiceError.InvalidTaxRate(taxRate))
                        .when(taxRate < 0 || taxRate > 100)
      // Company isolation: a ride of another tenant returns empty → RideNotBillable,
      // never leaking that the ride exists.
      ride         <- invoiceRepo
                        .findRideForReceipt(taxiCompanyId, rideId)
                        .mapError(InvoiceError.DatabaseError(_))
                        .flatMap(ZIO.fromOption(_).orElseFail(InvoiceError.RideNotBillable(rideId)))
      cc           <- clientCompanyRepo
                        .findById(com.shevchyk.core.domain.ClientCompanyId(ride.clientCompanyId))
                        .mapError(InvoiceError.DatabaseError(_))
                        .flatMap(ZIO.fromOption(_).orElseFail(InvoiceError.ClientCompanyNotFound(ride.clientCompanyId)))
      profile      <- billingProfileRepo
                        .findByCompany(taxiCompanyId)
                        .mapBoth(
                          InvoiceError.DatabaseError(_),
                          _.getOrElse(CompanyBillingProfile(taxiCompanyId, legalName = Some(companyName)))
                        )
      // Stable, idempotent receipt number derived from the ride (no shared counter).
      receiptNumber = s"Q-${ride.rideId.toString.take(8).toUpperCase}"
      bytes        <- PdfGenerator
                        .generateReceiptBytes(
                          receiptNumber,
                          ride.pickupAddress,
                          ride.dropoffAddress,
                          ride.pickupDatetime,
                          ride.price,
                          taxRate,
                          profile,
                          cc
                        )
                        .mapError(InvoiceError.PdfGenerationError(_))
    } yield bytes

  // Generate the PDF, load the recipient, and email the invoice (or reminder).
  // Fails with NoRecipientEmail when the client company has no address. Shared by
  // sendInvoice and sendReminder so the "PDF → recipient → email" path lives once.
  private def emailInvoice(
      invoice: Invoice,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String,
      isReminder: Boolean
  ): IO[InvoiceError, Unit] =
    for {
      pdf   <- generatePdf(invoice.id, taxiCompanyId, companyName, storageDir)
      cc    <- clientCompanyRepo
                 .findById(invoice.clientCompanyId)
                 .mapError(InvoiceError.DatabaseError(_))
                 .flatMap(
                   ZIO.fromOption(_).orElseFail(InvoiceError.ClientCompanyNotFound(invoice.clientCompanyId.value))
                 )
      email <- ZIO.fromOption(cc.email).orElseFail(InvoiceError.NoRecipientEmail(invoice.id))
      lang   = cc.preferredLanguage.filter(_.nonEmpty).getOrElse(defaultEmailLanguage)
      _     <- emailService
                 .sendInvoiceEmail(
                   InvoiceEmailData(
                     toEmail = email,
                     toName = cc.name,
                     invoiceNumber = invoice.number,
                     totalAmount = invoice.totalAmount,
                     currency = invoice.currency,
                     dueDate = invoice.dueDate,
                     isReminder = isReminder,
                     pdfAttachment = pdf,
                     pdfFilename = s"${invoice.number.replace('/', '-')}.pdf",
                     language = lang
                   )
                 )
                 .mapError(InvoiceError.EmailDeliveryError(_))
    } yield ()

  override def sendInvoice(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Invoice] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      _       <-
        ZIO.when(invoice.status != InvoiceStatus.Draft)(
          ZIO.fail(InvoiceError.NotDraft(id))
        )
      // An empty draft would email a €0.00 PDF, an invalid financial document.
      _       <-
        ZIO.when(invoice.items.isEmpty)(
          ZIO.fail(InvoiceError.EmptyInvoice(id))
        )
      _       <- emailInvoice(invoice, taxiCompanyId, companyName, storageDir, isReminder = false)
      updated  = invoice.copy(status = InvoiceStatus.Sent, sentAt = Some(Instant.now()))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved

  override def sendReminder(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Invoice] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      // Only sent, unpaid invoices get a reminder; ignore anything already paid/cancelled/draft.
      _       <-
        ZIO.when(invoice.status != InvoiceStatus.Sent)(
          ZIO.fail(InvoiceError.InvalidStatus(invoice.status, "sent"))
        )
      _       <- emailInvoice(invoice, taxiCompanyId, companyName, storageDir, isReminder = true)
      updated  = invoice.copy(reminderSentAt = Some(Instant.now()))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved

  override def markPaid(id: InvoiceId, taxiCompanyId: CompanyId, paidAt: Option[Instant]): IO[InvoiceError, Invoice] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      _       <-
        ZIO.when(invoice.status == InvoiceStatus.Draft || invoice.status == InvoiceStatus.Cancelled)(
          ZIO.fail(InvoiceError.InvalidStatus(invoice.status, "sent"))
        )
      updated  = invoice.copy(status = InvoiceStatus.Paid, paidAt = Some(paidAt.getOrElse(Instant.now())))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved

  override def deleteInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Unit] =
    for {
      invoice <- getInvoice(id, taxiCompanyId)
      _       <-
        ZIO.when(invoice.status != InvoiceStatus.Draft)(
          ZIO.fail(InvoiceError.NotDraft(id))
        )
      _       <- invoiceRepo.delete(id, taxiCompanyId).mapError(InvoiceError.DatabaseError(_))
    } yield ()

  private def recalculate(invoice: Invoice): UIO[Invoice] = ZIO.succeed {
    // Each ride's price is GROSS (Brutto, incl. MwSt) — see `rideToItem` and `generateRideReceipt`.
    // So the line totals sum to the gross invoice amount; Netto and MwSt are DERIVED from it
    // (net = gross / (1 + rate)), matching the receipt path in PdfGenerator. Previously this treated
    // the sum as Netto and added tax on top, double-charging MwSt and overstating the total.
    // Round monetary values to 2 decimals (HALF_UP) so stored amounts match the PDF/DATEV output.
    val gross    = invoice.items.map(_.total).sum.setScale(2, BigDecimal.RoundingMode.HALF_UP)
    // Defense-in-depth: `createInvoice` rejects an out-of-range taxRate, but a legacy/corrupt row could
    // still reach here. Clamp an invalid rate to 0 (treat gross as net, no tax) rather than divide by
    // zero (taxRate = -100) since this UIO can't fail.
    val safeRate = if invoice.taxRate < 0 || invoice.taxRate > 100 then BigDecimal(0) else invoice.taxRate
    val net      = (gross / (1 + safeRate / 100)).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val tax      = (gross - net).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    invoice.copy(subtotalAmount = net, taxAmount = tax, totalAmount = gross)
  }

object InvoiceService:

  def layerWithLanguage(defaultEmailLanguage: String): ZLayer[
    InvoiceRepository & ClientCompanyRepository & CompanyBillingProfileRepository & EmailSmsService,
    Nothing,
    InvoiceService
  ] = ZLayer.fromFunction(InvoiceServiceImpl(_, _, _, _, defaultEmailLanguage))

  val layer: ZLayer[
    InvoiceRepository & ClientCompanyRepository & CompanyBillingProfileRepository & EmailSmsService,
    Nothing,
    InvoiceService
  ] = ZLayer.fromFunction(InvoiceServiceImpl(_, _, _, _))
