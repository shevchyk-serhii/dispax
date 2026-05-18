package com.shevchyk.billing.domain

import com.shevchyk.core.domain.{ClientCompanyId, CompanyId, PersonId}
import zio.json.*
import com.github.f4b6a3.uuid.UuidCreator

import java.time.{Instant, LocalDate}
import java.util.UUID

case class InvoiceId(value: UUID) derives JsonCodec

object InvoiceId:
  def generate(): InvoiceId = InvoiceId(UuidCreator.getTimeOrderedEpoch())

case class InvoiceItemId(value: UUID) derives JsonCodec

object InvoiceItemId:
  def generate(): InvoiceItemId = InvoiceItemId(UuidCreator.getTimeOrderedEpoch())

enum InvoiceStatus derives JsonCodec:
  case Draft, Sent, Paid, Cancelled

object InvoiceStatus:

  def fromString(s: String): InvoiceStatus =
    s.toLowerCase match
      case "draft"     => Draft
      case "sent"      => Sent
      case "paid"      => Paid
      case "cancelled" => Cancelled
      case _           => Draft

  def asString(s: InvoiceStatus): String = s.toString.toLowerCase

final case class InvoiceItem(
    id: InvoiceItemId,
    invoiceId: InvoiceId,
    rideId: Option[UUID],
    description: String,
    quantity: BigDecimal,
    unitPrice: BigDecimal,
    total: BigDecimal,
    createdAt: Instant = Instant.now()
) derives JsonCodec

final case class Invoice(
    id: InvoiceId,
    number: String,
    clientCompanyId: ClientCompanyId,
    taxiCompanyId: CompanyId,
    status: InvoiceStatus,
    periodFrom: LocalDate,
    periodTo: LocalDate,
    subtotalAmount: BigDecimal,
    taxRate: BigDecimal,
    taxAmount: BigDecimal,
    totalAmount: BigDecimal,
    currency: String = "EUR",
    notes: Option[String] = None,
    dueDate: Option[LocalDate] = None,
    sentAt: Option[Instant] = None,
    paidAt: Option[Instant] = None,
    pdfPath: Option[String] = None,
    items: List[InvoiceItem] = Nil,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class CreateInvoiceRequest(
    clientCompanyId: UUID,
    periodFrom: LocalDate,
    periodTo: LocalDate,
    taxRate: BigDecimal = BigDecimal(0),
    currency: String = "EUR",
    notes: Option[String] = None,
    dueDate: Option[LocalDate] = None
) derives JsonCodec

final case class MarkPaidRequest(
    paidAt: Option[Instant] = None
) derives JsonCodec

enum InvoiceError extends Throwable:
  case NotFound(id: InvoiceId)
  case ClientCompanyNotFound(id: UUID)
  case InvalidStatus(current: InvoiceStatus, required: String)
  case NotDraft(id: InvoiceId)
  case DatabaseError(cause: Throwable)
  case PdfGenerationError(cause: Throwable)
