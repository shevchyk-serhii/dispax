package com.shevchyk.billing.repository

import com.shevchyk.billing.domain.*
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}
import zio.*

import java.time.LocalDate
import java.util.UUID

trait InvoiceRepository:
  def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]
  def create(invoice: Invoice): Task[Invoice]
  def findById(id: InvoiceId): Task[Option[Invoice]]

  def findByCompany(
      taxiCompanyId: CompanyId,
      status: Option[InvoiceStatus],
      limit: Int,
      offset: Int
  ): Task[List[Invoice]]
  def update(invoice: Invoice): Task[Invoice]
  // Sent, unpaid invoices whose due date has passed and which haven't been
  // reminded yet — the overdue-reminder candidate set (cross-tenant).
  def findOverdueUnpaid(now: java.time.Instant): Task[List[Invoice]]
  def delete(id: InvoiceId): Task[Boolean]
  def addItems(items: List[InvoiceItem]): Task[Unit]
  def deleteItems(invoiceId: InvoiceId): Task[Unit]
  // Atomically replace all items of an invoice: delete old items, insert new ones,
  // and link the referenced rides (restricted to taxiCompanyId) to this invoice.
  def replaceItems(invoiceId: InvoiceId, taxiCompanyId: CompanyId, items: List[InvoiceItem]): Task[Unit]
  // Detach all rides currently billed to this invoice (so a re-run of auto-fill sees them again),
  // restricted to the owning company.
  def unlinkRides(invoiceId: InvoiceId, taxiCompanyId: CompanyId): Task[Unit]
  // Returns unbilled completed rides for a client company in a period
  def findUnbilledRides(clientCompanyId: ClientCompanyId, from: LocalDate, to: LocalDate): Task[List[UnbilledRide]]

  // Returns unbilled completed rides for a client company, taxi-company scoped,
  // optionally bounded by a pickup-date range (the billable-rides listing).
  def findBillableRides(
      taxiCompanyId: CompanyId,
      clientCompanyId: ClientCompanyId,
      from: Option[LocalDate],
      to: Option[LocalDate]
  ): Task[List[UnbilledRide]]
  // Returns the given rides (by id), restricted to completed/unbilled rides of
  // this taxi company. Used to validate an explicit per-ride selection: any
  // requested id absent from the result is not billable (wrong company, not
  // completed, or already billed). Each row carries its client_company_id so the
  // service can enforce the single-client-company rule.
  def findRidesByIds(taxiCompanyId: CompanyId, rideIds: List[UUID]): Task[List[UnbilledRide]]
  // Returns a single completed ride (taxi-company scoped) for receipt generation.
  // Unlike findRidesByIds, this does NOT require the ride to be unbilled — a
  // per-ride Quittung must be printable even after the ride is on an invoice.
  def findRideForReceipt(taxiCompanyId: CompanyId, rideId: UUID): Task[Option[UnbilledRide]]

final case class UnbilledRide(
    rideId: UUID,
    clientId: UUID,
    clientCompanyId: UUID,
    pickupAddress: String,
    dropoffAddress: String,
    pickupDatetime: java.time.Instant,
    price: BigDecimal
)

object InvoiceRepository:

  val layer: ZLayer[Any, Throwable, InvoiceRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresInvoiceRepository.layer
