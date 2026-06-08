package com.shevchyk.billing.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.*
import com.shevchyk.core.domain.CompanyId
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

object InvoiceRoutes:

  private val storageDir  = sys.env.getOrElse("PDF_STORAGE_DIR", "/tmp/invoices")
  private val companyName = sys.env.getOrElse("COMPANY_NAME", "Dispax GmbH")

  private def handleError(ex: InvoiceError): UIO[Response] =
    val (status, msg) =
      ex match
        case InvoiceError.NotFound(_)              => (Status.NotFound, "Invoice not found")
        case InvoiceError.ClientCompanyNotFound(_) => (Status.NotFound, "Client company not found")
        case InvoiceError.NotDraft(_)              => (Status.Conflict, "Invoice must be in draft status")
        case InvoiceError.InvalidStatus(cur, req)  => (Status.Conflict, s"Invalid status: ${cur}, required: $req")
        case InvoiceError.DatabaseError(c)         =>
          ZIO.logError(s"DB error: ${c.getMessage}")
          (Status.InternalServerError, "Internal server error")
        case InvoiceError.PdfGenerationError(c)    =>
          ZIO.logError(s"PDF error: ${c.getMessage}")
          (Status.InternalServerError, "PDF generation failed")
    ZIO
      .logError(s"Invoice error: $msg")
      .as(
        Response(status, body = Body.fromString(s"""{"error":"$msg"}"""))
      )

  val authenticatedRoutes: Routes[InvoiceService & JwtService, Response] = Routes(
    // GET /api/billing/invoices
    Method.GET / "api" / "billing" / "invoices" -> authenticatedHandler[InvoiceService] { (user, request) =>
      (for {
        companyId <- UuidParser.requireCompanyId(user.companyId)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        status     = request.url.queryParam("status").flatMap { s =>
                       scala.util.Try(InvoiceStatus.fromString(s)).toOption
                     }
        limit      = request.url.queryParam("limit").flatMap(_.toIntOption).getOrElse(50)
        offset     = request.url.queryParam("offset").flatMap(_.toIntOption).getOrElse(0)
        service   <- ZIO.service[InvoiceService]
        invoices  <- service.listInvoices(companyId, status, limit, offset)
      } yield Response.json(invoices.toJson)).catchAll {
        case r: Response  => ZIO.succeed(r)
        case e: Throwable => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    },

    // POST /api/billing/invoices
    Method.POST / "api" / "billing" / "invoices" -> authenticatedJsonHandler[InvoiceService, CreateInvoiceRequest] {
      (user, req) =>
        (for {
          companyId <- UuidParser.requireCompanyId(user.companyId)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
          service   <- ZIO.service[InvoiceService]
          invoice   <- service.createInvoice(companyId, req).mapError(e => e: Throwable)
        } yield Response(Status.Created, body = Body.fromString(invoice.toJson))).catchAll {
          case r: Response     => ZIO.succeed(r)
          case e: InvoiceError => handleError(e)
          case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
        }
    },

    // GET /api/billing/invoices/:id
    Method.GET / "api" / "billing" / "invoices" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        service   <- ZIO.service[InvoiceService]
        invoice   <- service.getInvoice(invoiceId, companyId).mapError(e => e: Throwable)
      } yield Response.json(invoice.toJson)).catchAll {
        case r: Response     => ZIO.succeed(r)
        case e: InvoiceError => handleError(e)
        case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    },

    // POST /api/billing/invoices/:id/auto-fill
    Method.POST / "api" / "billing" / "invoices" / string("id") / "auto-fill" -> handler {
      (id: String, request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
          service   <- ZIO.service[InvoiceService]
          invoice   <- service.autoFillFromPeriod(invoiceId, companyId).mapError(e => e: Throwable)
        } yield Response.json(invoice.toJson)).catchAll {
          case r: Response     => ZIO.succeed(r)
          case e: InvoiceError => handleError(e)
          case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
        }
    },

    // GET /api/billing/invoices/:id/pdf  — download bytes
    Method.GET / "api" / "billing" / "invoices" / string("id") / "pdf" -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        service   <- ZIO.service[InvoiceService]
        bytes     <- service.generatePdf(invoiceId, companyId, companyName, storageDir).mapError(e => e: Throwable)
      } yield Response(
        Status.Ok,
        headers = Headers(
          Header.ContentType(MediaType.application.pdf),
          Header.Custom("Content-Disposition", s"""attachment; filename="invoice-$id.pdf"""")
        ),
        body = Body.fromChunk(zio.Chunk.fromArray(bytes))
      )).catchAll {
        case r: Response     => ZIO.succeed(r)
        case e: InvoiceError => handleError(e)
        case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    },

    // POST /api/billing/invoices/:id/send
    Method.POST / "api" / "billing" / "invoices" / string("id") / "send" -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        service   <- ZIO.service[InvoiceService]
        invoice   <- service.sendInvoice(invoiceId, companyId, companyName, storageDir).mapError(e => e: Throwable)
      } yield Response.json(invoice.toJson)).catchAll {
        case r: Response     => ZIO.succeed(r)
        case e: InvoiceError => handleError(e)
        case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    },

    // POST /api/billing/invoices/:id/pay
    Method.POST / "api" / "billing" / "invoices" / string("id") / "pay" -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[MarkPaidRequest].left.map(_ => MarkPaidRequest()))
                       .orElse(ZIO.succeed(MarkPaidRequest()))
        service   <- ZIO.service[InvoiceService]
        invoice   <- service.markPaid(invoiceId, companyId, req.paidAt).mapError(e => e: Throwable)
      } yield Response.json(invoice.toJson)).catchAll {
        case r: Response     => ZIO.succeed(r)
        case e: InvoiceError => handleError(e)
        case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    },

    // DELETE /api/billing/invoices/:id
    Method.DELETE / "api" / "billing" / "invoices" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY", "ADMIN")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        invoiceId <- ZIO.attempt(InvoiceId(UUID.fromString(id))).mapError(_ => Response.status(Status.BadRequest))
        service   <- ZIO.service[InvoiceService]
        _         <- service.deleteInvoice(invoiceId, companyId).mapError(e => e: Throwable)
      } yield Response.status(Status.NoContent)).catchAll {
        case r: Response     => ZIO.succeed(r)
        case e: InvoiceError => handleError(e)
        case e: Throwable    => ZIO.logError(e.getMessage).as(Response.status(Status.InternalServerError))
      }
    }
  )
