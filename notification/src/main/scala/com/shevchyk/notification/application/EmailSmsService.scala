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

  // Mock transport: logs the composed email and attachment size. A real SMTP
  // implementation replaces this class without touching the call sites.
  override def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit] =
    val subject = MessageTemplates.invoiceEmailSubject(data)
    val body    = MessageTemplates.invoiceEmailBody(data)
    ZIO.logInfo(
      s"[EMAIL/SMS PLACEHOLDER] Invoice email to ${data.toEmail} | subject: $subject | " +
        s"attachment: ${data.pdfFilename} (${data.pdfAttachment.length} bytes)\n$body"
    )

object LoggingEmailSmsService:
  val layer: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new LoggingEmailSmsService)
