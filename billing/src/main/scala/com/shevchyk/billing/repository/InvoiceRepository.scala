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
  def delete(id: InvoiceId): Task[Boolean]
  def addItems(items: List[InvoiceItem]): Task[Unit]
  def deleteItems(invoiceId: InvoiceId): Task[Unit]
  // Returns unbilled completed rides for a client company in a period
  def findUnbilledRides(clientCompanyId: ClientCompanyId, from: LocalDate, to: LocalDate): Task[List[UnbilledRide]]

final case class UnbilledRide(
    rideId: UUID,
    clientId: UUID,
    pickupAddress: String,
    dropoffAddress: String,
    pickupDatetime: java.time.Instant,
    price: BigDecimal
)

object InvoiceRepository:

  val layer: ZLayer[Any, Throwable, InvoiceRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresInvoiceRepository.layer
