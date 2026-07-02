package com.shevchyk.billing.domain

import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}
import zio.json.*
import com.github.f4b6a3.uuid.UuidCreator

import java.time.{Instant, LocalDate}
import java.util.UUID

// Like the core ID types, serialize as a flat JSON string, not {"value":...}.
private def idEncoder[A](unwrap: A => UUID): JsonEncoder[A] = JsonEncoder[String].contramap(a => unwrap(a).toString)

private def idDecoder[A](wrap: UUID => A): JsonDecoder[A] = JsonDecoder[String].mapOrFail(s =>
  scala.util.Try(UUID.fromString(s)).toEither.left.map(_ => s"Invalid UUID: $s").map(wrap)
)

case class InvoiceId(value: UUID)

object InvoiceId:
  def generate(): InvoiceId    = InvoiceId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[InvoiceId] = idEncoder(_.value)
  given JsonDecoder[InvoiceId] = idDecoder(InvoiceId.apply)

case class InvoiceItemId(value: UUID)

object InvoiceItemId:
  def generate(): InvoiceItemId    = InvoiceItemId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[InvoiceItemId] = idEncoder(_.value)
  given JsonDecoder[InvoiceItemId] = idDecoder(InvoiceItemId.apply)

enum InvoiceStatus derives JsonCodec:
  case Draft, Sent, Paid, Cancelled

object InvoiceStatus:

  // Safe parser: an unknown/corrupted status must NOT silently become Draft.
  // Invoices are financial/legal documents; misreading a paid invoice as a draft
  // is a correctness bug. Callers decide how to handle None (e.g. the DB read path
  // fails loudly instead of fabricating a Draft).
  def fromString(s: String): Option[InvoiceStatus] =
    s.toLowerCase match
      case "draft"     => Some(Draft)
      case "sent"      => Some(Sent)
      case "paid"      => Some(Paid)
      case "cancelled" => Some(Cancelled)
      case _           => None

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
    // When an overdue-payment reminder was last sent; set once so a reminder is sent at most once.
    reminderSentAt: Option[Instant] = None,
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

// Build an invoice from an explicit set of completed, unbilled rides (per-ride
// billing), as an alternative to filling by period.
final case class FillFromRidesRequest(
    rideIds: List[UUID]
) derives JsonCodec

// A completed, unbilled ride eligible to be added to an invoice, shaped for the
// billable-rides listing the dispatcher selects from.
final case class BillableRideDto(
    rideId: UUID,
    clientId: UUID,
    pickupAddress: String,
    dropoffAddress: String,
    pickupDatetime: Instant,
    price: BigDecimal
) derives JsonCodec

enum InvoiceError extends Throwable:
  case NotFound(id: InvoiceId)
  case ClientCompanyNotFound(id: UUID)
  case InvalidStatus(current: InvoiceStatus, required: String)
  case NotDraft(id: InvoiceId)
  // The invoice has no line items: an empty draft must not be sent (it would
  // email a €0.00 PDF, an invalid financial document).
  case EmptyInvoice(id: InvoiceId)
  // A selected ride can't be billed on this invoice: it belongs to another
  // client company, another taxi company, isn't completed, or is already billed.
  case RideNotBillable(rideId: UUID)
  // The invoice's client company has no email address to send to.
  case NoRecipientEmail(id: InvoiceId)
  // The tax rate (percent) is outside the valid range [0, 100]: a negative rate
  // distorts Netto/MwSt (at -100 it divides by zero), and >100 understates the tax.
  case InvalidTaxRate(taxRate: BigDecimal)
  case DatabaseError(cause: Throwable)
  case PdfGenerationError(cause: Throwable)
  case EmailDeliveryError(cause: Throwable)
