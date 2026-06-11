package com.shevchyk.core.application

import zio.*

/**
 * Ride confirmation data for email/SMS notifications
 */
final case class RideConfirmationData(
    rideId: String,
    clientName: String,
    pickupAddress: String,
    dropoffAddress: String,
    scheduledTime: Option[java.time.Instant] = None,
    driverName: Option[String] = None,
    estimatedPrice: Option[BigDecimal] = None
)

/**
 * Invoice email payload: the rendered PDF plus the fields needed to compose the subject/body. `isReminder`
 * distinguishes the first delivery from an overdue payment reminder.
 */
final case class InvoiceEmailData(
    toEmail: String,
    toName: String,
    invoiceNumber: String,
    totalAmount: BigDecimal,
    currency: String,
    dueDate: Option[java.time.LocalDate],
    isReminder: Boolean,
    pdfAttachment: Array[Byte],
    pdfFilename: String
)

/**
 * Service for sending email/SMS notifications. Implementations live in the notification module.
 */
trait EmailSmsService:
  def sendRideConfirmation(data: RideConfirmationData): Task[Unit]
  def sendDriverAssignment(data: RideConfirmationData): Task[Unit]
  // Sends an invoice (or an overdue reminder) with the PDF attached.
  def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit]
