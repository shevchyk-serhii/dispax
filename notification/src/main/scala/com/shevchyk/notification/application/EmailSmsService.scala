package com.shevchyk.notification.application

import com.shevchyk.core.application.{EmailSmsService, InvoiceEmailData, RideConfirmationData}
import com.shevchyk.notification.domain.MessageTemplates
import zio.*

class LoggingEmailSmsService extends EmailSmsService:

  override def sendRideConfirmation(data: RideConfirmationData): Task[Unit] =
    val message = MessageTemplates.rideConfirmationText(data)
    ZIO.logInfo(s"[EMAIL/SMS PLACEHOLDER] Ride Confirmation: $message")

  override def sendDriverAssignment(data: RideConfirmationData): Task[Unit] =
    val message = MessageTemplates.driverAssignmentText(data)
    ZIO.logInfo(s"[EMAIL/SMS PLACEHOLDER] Driver Assignment: $message")

  // Mock transport for invoices. We deliberately do NOT log the recipient email,
  // the rendered body or the amounts: those are PII / financial data that must not
  // leak into centralised logs. A real SMTP implementation replaces this class
  // without touching the call sites.
  override def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit] = ZIO.logInfo(
    s"[EMAIL/SMS PLACEHOLDER] Invoice email queued | invoice: ${data.invoiceNumber} | " +
      s"attachment: ${data.pdfFilename} (${data.pdfAttachment.length} bytes)"
  )

object LoggingEmailSmsService:
  val layer: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new LoggingEmailSmsService)
