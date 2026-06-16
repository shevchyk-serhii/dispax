package com.shevchyk.billing.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.openapi.BillingSecure.*
import com.shevchyk.core.domain.ClientCompanyId
import com.shevchyk.core.openapi.ApiError

import java.time.LocalDate
import java.util.UUID
import sttp.model.{HeaderNames, MediaType, StatusCode}
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the invoice endpoints. Replaces the zio-http handlers in `InvoiceRoutes`
 * while keeping the exact paths, request/response shapes, status codes, role checks and company isolation. The PDF
 * endpoint streams the raw bytes with `application/pdf` + a `Content-Disposition` attachment header, mirroring the
 * original handler.
 */
object InvoiceApi:

  private val invoiceTag = "Invoices"

  private val storageDir  = sys.env.getOrElse("PDF_STORAGE_DIR", "/tmp/invoices")
  private val companyName = sys.env.getOrElse("COMPANY_NAME", "Dispax GmbH")

  // -- Environment ---------------------------------------------------------
  type BillingEnv = InvoiceService & JwtService

  // -- Schemas (next to the zio-json codecs the DTOs already derive) -------
  given Schema[InvoiceId]            = Schema.string
  given Schema[InvoiceItemId]        = Schema.string
  given Schema[InvoiceStatus]        = Schema.derivedEnumeration[InvoiceStatus].defaultStringBased
  given Schema[InvoiceItem]          = Schema.derived
  given Schema[Invoice]              = Schema.derived
  given Schema[CreateInvoiceRequest] = Schema.derived
  given Schema[MarkPaidRequest]      = Schema.derived
  given Schema[FillFromRidesRequest] = Schema.derived
  given Schema[BillableRideDto]      = Schema.derived

  // ======================================================================
  // Endpoint descriptions
  // ======================================================================

  val listInvoicesEndpoint = secureEndpoint.get
    .in("api" / "billing" / "invoices")
    .in(query[Option[String]]("status"))
    .in(query[Option[Int]]("limit"))
    .in(query[Option[Int]]("offset"))
    .out(jsonBody[List[Invoice]])
    .tag(invoiceTag)
    .summary("List invoices (paginated, optional status filter)")

  val createInvoiceEndpoint = secureEndpoint.post
    .in("api" / "billing" / "invoices")
    .in(jsonBody[CreateInvoiceRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[Invoice]))
    .tag(invoiceTag)
    .summary("Create an invoice")

  val getInvoiceEndpoint = secureEndpoint.get
    .in("api" / "billing" / "invoices" / path[String]("id"))
    .out(jsonBody[Invoice])
    .tag(invoiceTag)
    .summary("Get an invoice by id")

  val autoFillInvoiceEndpoint = secureEndpoint.post
    .in("api" / "billing" / "invoices" / path[String]("id") / "auto-fill")
    .out(jsonBody[Invoice])
    .tag(invoiceTag)
    .summary("Auto-fill an invoice from its billing period")

  val fillFromRidesEndpoint = secureEndpoint.post
    .in("api" / "billing" / "invoices" / path[String]("id") / "fill-from-rides")
    .in(jsonBody[FillFromRidesRequest])
    .out(jsonBody[Invoice])
    .tag(invoiceTag)
    .summary("Fill an invoice from an explicit set of completed, unbilled rides")

  val billableRidesEndpoint = secureEndpoint.get
    .in("api" / "billing" / "billable-rides")
    .in(query[String]("clientCompanyId"))
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[List[BillableRideDto]])
    .tag(invoiceTag)
    .summary("List completed, unbilled rides eligible for invoicing")

  val rideReceiptEndpoint = secureEndpoint.get
    .in("api" / "billing" / "rides" / path[String]("rideId") / "receipt")
    .in(query[Option[String]]("taxRate"))
    .out(byteArrayBody)
    .out(header(sttp.model.Header.contentType(MediaType.ApplicationPdf)))
    .out(header[String](HeaderNames.ContentDisposition))
    .tag(invoiceTag)
    .summary("Download a single-ride receipt (Quittung) as a PDF")

  val invoicePdfEndpoint = secureEndpoint.get
    .in("api" / "billing" / "invoices" / path[String]("id") / "pdf")
    .out(byteArrayBody)
    .out(header(sttp.model.Header.contentType(MediaType.ApplicationPdf)))
    .out(header[String](HeaderNames.ContentDisposition))
    .tag(invoiceTag)
    .summary("Download an invoice as a PDF")

  val sendInvoiceEndpoint = secureEndpoint.post
    .in("api" / "billing" / "invoices" / path[String]("id") / "send")
    .out(jsonBody[Invoice])
    .tag(invoiceTag)
    .summary("Send an invoice")

  val payInvoiceEndpoint = secureEndpoint.post
    .in("api" / "billing" / "invoices" / path[String]("id") / "pay")
    .in(jsonBody[MarkPaidRequest])
    .out(jsonBody[Invoice])
    .tag(invoiceTag)
    .summary("Mark an invoice as paid")

  val deleteInvoiceEndpoint = secureEndpoint.delete
    .in("api" / "billing" / "invoices" / path[String]("id"))
    .out(statusCode(StatusCode.NoContent))
    .tag(invoiceTag)
    .summary("Delete an invoice")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    listInvoicesEndpoint,
    createInvoiceEndpoint,
    getInvoiceEndpoint,
    autoFillInvoiceEndpoint,
    fillFromRidesEndpoint,
    billableRidesEndpoint,
    rideReceiptEndpoint,
    invoicePdfEndpoint,
    sendInvoiceEndpoint,
    payInvoiceEndpoint,
    deleteInvoiceEndpoint
  )

  // ======================================================================
  // Server logic
  // ======================================================================

  private val listInvoicesServer: ZServerEndpoint[BillingEnv, Any] = listInvoicesEndpoint.serverLogic {
    user => (statusOpt, limitOpt, offsetOpt) =>
      for {
        companyId <- requireCompanyId(user.companyId)
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        status     = statusOpt.flatMap(s => scala.util.Try(InvoiceStatus.fromString(s)).toOption)
        limit      = limitOpt.getOrElse(50)
        offset     = offsetOpt.getOrElse(0)
        service   <- ZIO.service[InvoiceService]
        invoices  <- service.listInvoices(companyId, status, limit, offset).mapError(_ => internalError)
      } yield invoices
  }

  private val createInvoiceServer: ZServerEndpoint[BillingEnv, Any] = createInvoiceEndpoint.serverLogic { user => req =>
    for {
      companyId <- requireCompanyId(user.companyId)
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      service   <- ZIO.service[InvoiceService]
      invoice   <- service.createInvoice(companyId, req).mapError(fromInvoiceError)
    } yield invoice
  }

  private val getInvoiceServer: ZServerEndpoint[BillingEnv, Any] = getInvoiceEndpoint.serverLogic { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      invoiceId <- parseInvoiceId(id)
      service   <- ZIO.service[InvoiceService]
      invoice   <- service.getInvoice(invoiceId, companyId).mapError(fromInvoiceError)
    } yield invoice
  }

  private val autoFillInvoiceServer: ZServerEndpoint[BillingEnv, Any] = autoFillInvoiceEndpoint.serverLogic {
    user => id =>
      for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        invoiceId <- parseInvoiceId(id)
        service   <- ZIO.service[InvoiceService]
        invoice   <- service.autoFillFromPeriod(invoiceId, companyId).mapError(fromInvoiceError)
      } yield invoice
  }

  private val fillFromRidesServer: ZServerEndpoint[BillingEnv, Any] = fillFromRidesEndpoint.serverLogic {
    user => (id, req) =>
      for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        invoiceId <- parseInvoiceId(id)
        _         <- ZIO
                       .fail((StatusCode.BadRequest, ApiError("rideIds must not be empty")))
                       .when(req.rideIds.isEmpty)
        service   <- ZIO.service[InvoiceService]
        invoice   <- service.fillFromRides(invoiceId, companyId, req.rideIds).mapError(fromInvoiceError)
      } yield invoice
  }

  private val billableRidesServer: ZServerEndpoint[BillingEnv, Any] = billableRidesEndpoint.serverLogic {
    user => (clientCompanyIdStr, fromOpt, toOpt) =>
      for {
        companyId       <- requireCompanyId(user.companyId)
        _               <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        clientCompanyId <- parseClientCompanyId(clientCompanyIdStr)
        from             = fromOpt.flatMap(s => scala.util.Try(LocalDate.parse(s)).toOption)
        to               = toOpt.flatMap(s => scala.util.Try(LocalDate.parse(s)).toOption)
        service         <- ZIO.service[InvoiceService]
        rides           <- service.listBillableRides(companyId, clientCompanyId, from, to).mapError(_ => internalError)
        dtos             = rides.map(r =>
                             BillableRideDto(r.rideId, r.clientId, r.pickupAddress, r.dropoffAddress, r.pickupDatetime, r.price)
                           )
      } yield dtos
  }

  private val rideReceiptServer: ZServerEndpoint[BillingEnv, Any] = rideReceiptEndpoint.serverLogic {
    user => (rideId, taxRateOpt) =>
      for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        rid       <- parseUuid(rideId)
        taxRate    = taxRateOpt.flatMap(s => scala.util.Try(BigDecimal(s)).toOption).getOrElse(BigDecimal(19))
        service   <- ZIO.service[InvoiceService]
        bytes     <- service.generateRideReceipt(rid, companyId, taxRate, companyName).mapError(fromInvoiceError)
      } yield (bytes, s"""attachment; filename="quittung-$rideId.pdf"""")
  }

  private val invoicePdfServer: ZServerEndpoint[BillingEnv, Any] = invoicePdfEndpoint.serverLogic { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      invoiceId <- parseInvoiceId(id)
      service   <- ZIO.service[InvoiceService]
      bytes     <- service.generatePdf(invoiceId, companyId, companyName, storageDir).mapError(fromInvoiceError)
    } yield (bytes, s"""attachment; filename="invoice-$id.pdf"""")
  }

  private val sendInvoiceServer: ZServerEndpoint[BillingEnv, Any] = sendInvoiceEndpoint.serverLogic { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      invoiceId <- parseInvoiceId(id)
      service   <- ZIO.service[InvoiceService]
      invoice   <- service.sendInvoice(invoiceId, companyId, companyName, storageDir).mapError(fromInvoiceError)
    } yield invoice
  }

  private val payInvoiceServer: ZServerEndpoint[BillingEnv, Any] = payInvoiceEndpoint.serverLogic { user => (id, req) =>
    for {
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      invoiceId <- parseInvoiceId(id)
      service   <- ZIO.service[InvoiceService]
      invoice   <- service.markPaid(invoiceId, companyId, req.paidAt).mapError(fromInvoiceError)
    } yield invoice
  }

  private val deleteInvoiceServer: ZServerEndpoint[BillingEnv, Any] = deleteInvoiceEndpoint.serverLogic { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      invoiceId <- parseInvoiceId(id)
      service   <- ZIO.service[InvoiceService]
      _         <- service.deleteInvoice(invoiceId, companyId).mapError(fromInvoiceError)
    } yield ()
  }

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[BillingEnv, Any]] = List(
    listInvoicesServer,
    createInvoiceServer,
    getInvoiceServer,
    autoFillInvoiceServer,
    fillFromRidesServer,
    billableRidesServer,
    rideReceiptServer,
    invoicePdfServer,
    sendInvoiceServer,
    payInvoiceServer,
    deleteInvoiceServer
  )
