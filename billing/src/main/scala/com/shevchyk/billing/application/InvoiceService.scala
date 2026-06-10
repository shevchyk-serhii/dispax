package com.shevchyk.billing.application

import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{ClientCompanyRepository, CompanyBillingProfileRepository, InvoiceRepository}
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

  def generatePdf(
      id: InvoiceId,
      taxiCompanyId: CompanyId,
      companyName: String,
      storageDir: String
  ): IO[InvoiceError, Array[Byte]]

  def sendInvoice(
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
    billingProfileRepo: CompanyBillingProfileRepository
) extends InvoiceService:

  override def createInvoice(taxiCompanyId: CompanyId, req: CreateInvoiceRequest): IO[InvoiceError, Invoice] =
    for {
      year   <- ZIO.succeed(req.periodFrom.getYear)
      number <- invoiceRepo.nextInvoiceNumber(taxiCompanyId, year).mapError(InvoiceError.DatabaseError(_))
      _      <- clientCompanyRepo
                  .findById(com.shevchyk.core.domain.ClientCompanyId(req.clientCompanyId))
                  .mapError(InvoiceError.DatabaseError(_))
                  .flatMap(ZIO.fromOption(_).mapError(_ => InvoiceError.ClientCompanyNotFound(req.clientCompanyId)))
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
      .flatMap(ZIO.fromOption(_).mapError(_ => InvoiceError.NotFound(id)))
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
      _       <- invoiceRepo.unlinkRides(id).mapError(InvoiceError.DatabaseError(_))
      rides   <- invoiceRepo
                   .findUnbilledRides(invoice.clientCompanyId, invoice.periodFrom, invoice.periodTo)
                   .mapError(InvoiceError.DatabaseError(_))
      items    = rides.map { ride =>
                   InvoiceItem(
                     id = InvoiceItemId.generate(),
                     invoiceId = id,
                     rideId = Some(ride.rideId),
                     description = s"${ride.pickupAddress} - ${ride.dropoffAddress}",
                     quantity = BigDecimal(1),
                     unitPrice = ride.price,
                     total = ride.price,
                     createdAt = ride.pickupDatetime
                   )
                 }
      _       <- invoiceRepo.replaceItems(id, items).mapError(InvoiceError.DatabaseError(_))
      updated <- recalculate(invoice.copy(items = items))
      saved   <- invoiceRepo.update(updated).mapError(InvoiceError.DatabaseError(_))
    } yield saved.copy(items = items)

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
                     ZIO.fromOption(_).mapError(_ => InvoiceError.ClientCompanyNotFound(invoice.clientCompanyId.value))
                   )
      // Issuer details come from the company's billing profile; fall back to the plain name.
      profile <- billingProfileRepo
                   .findByCompany(taxiCompanyId)
                   .mapError(InvoiceError.DatabaseError(_))
                   .map(_.getOrElse(CompanyBillingProfile(taxiCompanyId, legalName = Some(companyName))))
      bytes   <- PdfGenerator
                   .generateBytes(invoice, cc, profile)
                   .mapError(InvoiceError.PdfGenerationError(_))
      path     = s"$storageDir/${invoice.number.replace('/', '-')}.pdf"
      _       <- PdfGenerator
                   .generateToFile(invoice, cc, profile, path)
                   .mapError(InvoiceError.PdfGenerationError(_))
      _       <- invoiceRepo
                   .update(invoice.copy(pdfPath = Some(path)))
                   .mapError(InvoiceError.DatabaseError(_))
    } yield bytes

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
      _       <- generatePdf(id, taxiCompanyId, companyName, storageDir)
      updated  = invoice.copy(status = InvoiceStatus.Sent, sentAt = Some(Instant.now()))
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
      _       <- invoiceRepo.delete(id).mapError(InvoiceError.DatabaseError(_))
    } yield ()

  private def recalculate(invoice: Invoice): UIO[Invoice] = ZIO.succeed {
    // Round monetary values to 2 decimals (HALF_UP) so stored amounts match the PDF/DATEV output.
    val subtotal = invoice.items.map(_.total).sum.setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val tax      = (subtotal * invoice.taxRate / 100).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val total    = (subtotal + tax).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    invoice.copy(subtotalAmount = subtotal, taxAmount = tax, totalAmount = total)
  }

object InvoiceService:

  val layer: ZLayer[
    InvoiceRepository & ClientCompanyRepository & CompanyBillingProfileRepository,
    Nothing,
    InvoiceService
  ] = ZLayer.fromFunction(InvoiceServiceImpl(_, _, _))
