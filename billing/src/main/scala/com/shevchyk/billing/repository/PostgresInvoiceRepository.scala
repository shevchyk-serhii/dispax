package com.shevchyk.billing.repository

import com.shevchyk.billing.domain.*
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}
import doobie.*
import doobie.implicits.*
import doobie.implicits.javasql.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, LocalDate, OffsetDateTime, ZoneOffset}
import java.util.UUID

final class PostgresInvoiceRepository(xa: Transactor[Task]) extends InvoiceRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[OffsetDateTime].imap(_.toInstant)((i: Instant) => i.atOffset(ZoneOffset.UTC))

  implicit val localDateMeta: Meta[LocalDate] =
    Meta[java.sql.Date].imap(_.toLocalDate)((d: LocalDate) => java.sql.Date.valueOf(d))

  implicit val bigDecimalMeta: Meta[BigDecimal] = Meta[java.math.BigDecimal].imap(BigDecimal(_))(_.bigDecimal)

  private def toInvoice(
      id: UUID,
      number: String,
      clientCompanyId: UUID,
      taxiCompanyId: UUID,
      status: String,
      periodFrom: LocalDate,
      periodTo: LocalDate,
      subtotal: BigDecimal,
      taxRate: BigDecimal,
      taxAmount: BigDecimal,
      total: BigDecimal,
      currency: String,
      notes: Option[String],
      dueDate: Option[LocalDate],
      sentAt: Option[Instant],
      paidAt: Option[Instant],
      pdfPath: Option[String],
      createdAt: Instant,
      updatedAt: Instant
  ): Invoice = Invoice(
    id = InvoiceId(id),
    number = number,
    clientCompanyId = ClientCompanyId(clientCompanyId),
    taxiCompanyId = CompanyId(taxiCompanyId),
    status = InvoiceStatus.fromString(status),
    periodFrom = periodFrom,
    periodTo = periodTo,
    subtotalAmount = subtotal,
    taxRate = taxRate,
    taxAmount = taxAmount,
    totalAmount = total,
    currency = currency,
    notes = notes,
    dueDate = dueDate,
    sentAt = sentAt,
    paidAt = paidAt,
    pdfPath = pdfPath,
    createdAt = createdAt,
    updatedAt = updatedAt
  )

  private def toItem(
      id: UUID,
      invoiceId: UUID,
      rideId: Option[UUID],
      description: String,
      quantity: BigDecimal,
      unitPrice: BigDecimal,
      total: BigDecimal,
      createdAt: Instant
  ): InvoiceItem = InvoiceItem(
    id = InvoiceItemId(id),
    invoiceId = InvoiceId(invoiceId),
    rideId = rideId,
    description = description,
    quantity = quantity,
    unitPrice = unitPrice,
    total = total,
    createdAt = createdAt
  )

  override def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String] =
    // Upsert sequence row, atomically increment, return formatted number
    (for {
      _ <-
        sql"""
        INSERT INTO invoice_sequences (company_id, last_number)
        VALUES (${taxiCompanyId.value}, 0)
        ON CONFLICT (company_id) DO NOTHING
      """.update.run
      n <-
        sql"""
        UPDATE invoice_sequences
        SET last_number = last_number + 1
        WHERE company_id = ${taxiCompanyId.value}
        RETURNING last_number
      """.query[Int].unique
    } yield f"INV-$year-$n%04d").transact(xa)

  override def create(invoice: Invoice): Task[Invoice] =
    sql"""
      INSERT INTO invoices
        (id, number, client_company_id, taxi_company_id, status,
         period_from, period_to, subtotal_amount, tax_rate, tax_amount, total_amount,
         currency, notes, due_date, created_at, updated_at)
      VALUES
        (${invoice.id.value}, ${invoice.number}, ${invoice.clientCompanyId.value},
         ${invoice.taxiCompanyId.value}, ${InvoiceStatus.asString(invoice.status)},
         ${invoice.periodFrom}, ${invoice.periodTo},
         ${invoice.subtotalAmount.bigDecimal}, ${invoice.taxRate.bigDecimal},
         ${invoice.taxAmount.bigDecimal}, ${invoice.totalAmount.bigDecimal},
         ${invoice.currency}, ${invoice.notes}, ${invoice.dueDate},
         ${invoice.createdAt}, ${invoice.updatedAt})
    """.update.run.transact(xa).as(invoice)

  override def findById(id: InvoiceId): Task[Option[Invoice]] =
    for {
      invoiceOpt <-
        sql"""
        SELECT id, number, client_company_id, taxi_company_id, status,
               period_from, period_to, subtotal_amount, tax_rate, tax_amount, total_amount,
               currency, notes, due_date, sent_at, paid_at, pdf_path, created_at, updated_at
        FROM invoices WHERE id = ${id.value}
      """.query[
          (
              UUID,
              String,
              UUID,
              UUID,
              String,
              LocalDate,
              LocalDate,
              BigDecimal,
              BigDecimal,
              BigDecimal,
              BigDecimal,
              String,
              Option[String],
              Option[LocalDate],
              Option[Instant],
              Option[Instant],
              Option[String],
              Instant,
              Instant
          )
        ].option
          .transact(xa)
          .map(_.map(toInvoice.tupled))
      items      <-
        invoiceOpt match
          case None    => ZIO.succeed(Nil)
          case Some(_) => findItems(id)
    } yield invoiceOpt.map(_.copy(items = items))

  private def findItems(invoiceId: InvoiceId): Task[List[InvoiceItem]] =
    sql"""
      SELECT id, invoice_id, ride_id, description, quantity, unit_price, total, created_at
      FROM invoice_items WHERE invoice_id = ${invoiceId.value}
      ORDER BY created_at
    """
      .query[(UUID, UUID, Option[UUID], String, BigDecimal, BigDecimal, BigDecimal, Instant)]
      .to[List]
      .transact(xa)
      .map(_.map(toItem.tupled))

  override def findByCompany(
      taxiCompanyId: CompanyId,
      status: Option[InvoiceStatus],
      limit: Int,
      offset: Int
  ): Task[List[Invoice]] =
    val statusFilter = status.map(s => fr"AND status = ${InvoiceStatus.asString(s)}").getOrElse(fr"")
    val q            =
      fr"""
      SELECT id, number, client_company_id, taxi_company_id, status,
             period_from, period_to, subtotal_amount, tax_rate, tax_amount, total_amount,
             currency, notes, due_date, sent_at, paid_at, pdf_path, created_at, updated_at
      FROM invoices
      WHERE taxi_company_id = ${taxiCompanyId.value}
    """ ++ statusFilter ++ fr"ORDER BY created_at DESC LIMIT $limit OFFSET $offset"
    q.query[
      (
          UUID,
          String,
          UUID,
          UUID,
          String,
          LocalDate,
          LocalDate,
          BigDecimal,
          BigDecimal,
          BigDecimal,
          BigDecimal,
          String,
          Option[String],
          Option[LocalDate],
          Option[Instant],
          Option[Instant],
          Option[String],
          Instant,
          Instant
      )
    ].to[List]
      .transact(xa)
      .map(_.map(toInvoice.tupled))

  override def update(invoice: Invoice): Task[Invoice] =
    sql"""
      UPDATE invoices SET
        status = ${InvoiceStatus.asString(invoice.status)},
        subtotal_amount = ${invoice.subtotalAmount.bigDecimal},
        tax_amount = ${invoice.taxAmount.bigDecimal},
        total_amount = ${invoice.totalAmount.bigDecimal},
        notes = ${invoice.notes},
        due_date = ${invoice.dueDate},
        sent_at = ${invoice.sentAt},
        paid_at = ${invoice.paidAt},
        pdf_path = ${invoice.pdfPath},
        updated_at = NOW()
      WHERE id = ${invoice.id.value}
    """.update.run.transact(xa).as(invoice)

  override def delete(id: InvoiceId): Task[Boolean] =
    sql"DELETE FROM invoices WHERE id = ${id.value} AND status = 'draft'".update.run.transact(xa).map(_ > 0)

  override def addItems(items: List[InvoiceItem]): Task[Unit] =
    val inserts = items.map { item =>
      sql"""
        INSERT INTO invoice_items (id, invoice_id, ride_id, description, quantity, unit_price, total, created_at)
        VALUES (${item.id.value}, ${item.invoiceId.value}, ${item.rideId},
                ${item.description}, ${item.quantity.bigDecimal}, ${item.unitPrice.bigDecimal},
                ${item.total.bigDecimal}, ${item.createdAt})
      """.update.run
    }
    inserts
      .foldLeft(doobie.free.connection.pure(0)) { (acc, ins) =>
        acc.flatMap(_ => ins)
      }
      .transact(xa)
      .unit

  override def deleteItems(invoiceId: InvoiceId): Task[Unit] =
    sql"DELETE FROM invoice_items WHERE invoice_id = ${invoiceId.value}".update.run.transact(xa).unit

  override def findUnbilledRides(
      clientCompanyId: ClientCompanyId,
      from: LocalDate,
      to: LocalDate
  ): Task[List[UnbilledRide]] =
    sql"""
      SELECT r.id, r.client_id, r.from_address, r.to_address,
             r.pickup_datetime,
             COALESCE(r.final_price_amount, r.estimated_price_amount, 0)
      FROM rides r
      JOIN persons p ON r.client_id = p.id
      WHERE p.client_company_id = ${clientCompanyId.value}
        AND r.status = 'Completed'
        AND r.invoice_id IS NULL
        AND r.pickup_datetime::date >= $from
        AND r.pickup_datetime::date <= $to
      ORDER BY r.pickup_datetime
    """
      .query[(UUID, UUID, String, String, Instant, BigDecimal)]
      .to[List]
      .transact(xa)
      .map(_.map { case (rideId, clientId, from, to, dt, price) =>
        UnbilledRide(rideId, clientId, from, to, dt, price)
      })

object PostgresInvoiceRepository:
  val layer: ZLayer[Transactor[Task], Nothing, InvoiceRepository] = ZLayer.fromFunction(PostgresInvoiceRepository(_))
