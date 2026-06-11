package com.shevchyk.app

import com.shevchyk.billing.application.{InvoiceService, PaymentChecker}
import com.shevchyk.billing.repository.InvoiceRepository
import zio.*

import java.time.Instant

// Periodically finds sent, unpaid, overdue invoices and emails a one-off payment
// reminder. Before reminding, it consults PaymentChecker (a banking-integration
// stub today): if the invoice turns out to be paid, it's marked paid instead.
object InvoiceReminderScheduler:

  private val storageDir  = sys.env.getOrElse("PDF_STORAGE_DIR", "/tmp/invoices")
  private val companyName = sys.env.getOrElse("COMPANY_NAME", "Dispax GmbH")

  def start: ZIO[InvoiceService & InvoiceRepository & PaymentChecker, Nothing, Unit] =
    val oneTick = tick.catchAll(e => ZIO.logError(s"InvoiceReminderScheduler error: $e"))
    ZIO.logInfo("InvoiceReminderScheduler started") *>
      oneTick.repeat(Schedule.fixed(1.hour)).forkDaemon.unit

  // A single sweep: find overdue invoices and remind (or mark paid) each. Exposed
  // (package-private) so tests can drive one deterministic iteration without the
  // daemon/schedule wrapper.
  private[app] def tick: ZIO[InvoiceService & InvoiceRepository & PaymentChecker, Throwable, Unit] =
    for
      service     <- ZIO.service[InvoiceService]
      invoiceRepo <- ZIO.service[InvoiceRepository]
      payments    <- ZIO.service[PaymentChecker]
      now          = Instant.now()
      overdue     <- invoiceRepo.findOverdueUnpaid(now)
      _           <-
        ZIO.foreachDiscard(overdue) { invoice =>
          // Isolate failures per invoice so one bad row doesn't stop the batch.
          handleOne(service, payments, invoice)
            .catchAll(e => ZIO.logError(s"Reminder failed for invoice ${invoice.number}: $e"))
        }
    yield ()

  private def handleOne(
      service: InvoiceService,
      payments: PaymentChecker,
      invoice: com.shevchyk.billing.domain.Invoice
  ): Task[Unit] = payments
    .isPaid(invoice)
    .flatMap {
      case true  =>
        service
          .markPaid(invoice.id, invoice.taxiCompanyId, None)
          .unit
          .zipLeft(ZIO.logInfo(s"Invoice ${invoice.number} confirmed paid by bank; marked paid"))
      case false =>
        service
          .sendReminder(invoice.id, invoice.taxiCompanyId, companyName, storageDir)
          .unit
          .zipLeft(ZIO.logInfo(s"Payment reminder sent for invoice ${invoice.number}"))
    }
    .mapError(e => e: Throwable)
