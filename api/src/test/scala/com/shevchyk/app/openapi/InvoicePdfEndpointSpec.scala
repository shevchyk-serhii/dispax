package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.openapi.InvoiceApi
import com.shevchyk.billing.repository.UnbilledRide
import com.shevchyk.core.domain.*
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.time.{Instant, LocalDate}
import java.util.UUID

/**
 * REGRESSION — 406 Not Acceptable on PDF endpoints (commit bc06549).
 *
 * Before the fix, `invoicePdfEndpoint` and `rideReceiptEndpoint` declared `byteArrayBody` which announces
 * `application/octet-stream`. Tapir's `NotAcceptableInterceptor` rejected any request carrying `Accept:
 * application/pdf` (and even `Accept: *_/_*` in some Tapir versions) with HTTP 406, making the PDF download completely
 * broken for all clients.
 *
 * The fix replaced `byteArrayBody` with a custom `pdfBody` whose `CodecFormat` declares `application/pdf`.
 * Content-negotiation now passes for `Accept: application/pdf` and `Accept: *_/_*`. The response `Content-Type` header
 * is correctly set to `application/pdf`. The Flutter client was also updated to send `Accept: application/pdf` (instead
 * of the default `Accept: application/json`) when downloading PDFs.
 *
 * Note: `Accept: application/json` SHOULD remain 406 on a PDF endpoint — that is correct content-negotiation behaviour.
 * The pre-fix bug was that `Accept: application/pdf` was also rejected (because the endpoint declared
 * `application/octet-stream`).
 *
 * This spec exercises the endpoint via `ZioHttpInterpreter` against an in-memory `InvoiceService` stub — no network
 * I/O, no Testcontainers.
 */
object InvoicePdfEndpointSpec extends ZIOSpecDefault:

  // ── IDs ─────────────────────────────────────────────────────────────────────

  private val companyAId  = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId  = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val invoiceAId  = InvoiceId(UUID.fromString("AAAAAAAA-0000-0000-0000-000000000001"))
  private val invoiceBId  = InvoiceId(UUID.fromString("BBBBBBBB-0000-0000-0000-000000000001"))

  private val dispatcherA = Person(
    id = PersonId(UUID.fromString("0000AADD-0000-0000-0000-000000000001")),
    name = "Dispatcher A",
    email = "dispatch@companya.de",
    role = PersonRole.Dispatcher,
    companyId = Some(companyAId)
  )

  // Minimal valid PDF header so the stub looks realistic.
  private val fakePdfBytes: Array[Byte] = "%PDF-1.4 fake content".getBytes("US-ASCII")

  // ── JWT helpers ──────────────────────────────────────────────────────────────

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private def generateToken(person: Person): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(person)
  )

  // ── In-memory InvoiceService stub ────────────────────────────────────────────
  //
  // * invoiceAId belongs to companyA  → generatePdf returns fakePdfBytes
  // * invoiceBId belongs to companyB  → cross-tenant: should result in 404, not 406
  // * any other id                    → NotFound

  private val stubInvoiceService: ZLayer[Any, Nothing, InvoiceService] = ZLayer.succeed(
    new InvoiceService:

      private def notImpl = ZIO.die(new NotImplementedError("InvoicePdfEndpointSpec stub"))

      override def createInvoice(taxiCompanyId: CompanyId, req: CreateInvoiceRequest): IO[InvoiceError, Invoice] =
        notImpl
      override def getInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]                = notImpl
      override def listInvoices(
          taxiCompanyId: CompanyId,
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[Invoice]] = ZIO.succeed(Nil)
      override def autoFillFromPeriod(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Invoice]        = notImpl
      override def fillFromRides(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          rideIds: List[UUID]
      ): IO[InvoiceError, Invoice] = notImpl
      override def listBillableRides(
          taxiCompanyId: CompanyId,
          clientCompanyId: ClientCompanyId,
          from: Option[LocalDate],
          to: Option[LocalDate]
      ): Task[List[UnbilledRide]] = ZIO.succeed(Nil)

      override def generatePdf(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Array[Byte]] =
        // invoiceBId belongs to companyB; any access from companyA is cross-tenant → NotFound
        val invoiceBelongsTo: Map[InvoiceId, CompanyId] = Map(invoiceAId -> companyAId, invoiceBId -> companyBId)
        invoiceBelongsTo.get(id) match
          case Some(owner) if owner == taxiCompanyId => ZIO.succeed(fakePdfBytes)
          case _                                     => ZIO.fail(InvoiceError.NotFound(id))

      override def generateRideReceipt(
          rideId: UUID,
          taxiCompanyId: CompanyId,
          taxRate: BigDecimal,
          companyName: String
      ): IO[InvoiceError, Array[Byte]] =
        if taxiCompanyId == companyAId then ZIO.succeed(fakePdfBytes)
        else ZIO.fail(InvoiceError.RideNotBillable(rideId))

      override def sendInvoice(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Invoice] = notImpl
      override def sendReminder(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          companyName: String,
          storageDir: String
      ): IO[InvoiceError, Invoice] = notImpl
      override def markPaid(
          id: InvoiceId,
          taxiCompanyId: CompanyId,
          paidAt: Option[Instant]
      ): IO[InvoiceError, Invoice] = notImpl
      override def deleteInvoice(id: InvoiceId, taxiCompanyId: CompanyId): IO[InvoiceError, Unit]                = notImpl
  )

  // ── Route runner ─────────────────────────────────────────────────────────────

  private val pdfRoutes = ZioHttpInterpreter().toHttp(InvoiceApi.serverEndpoints)

  private def run(req: Request): ZIO[InvoiceApi.BillingEnv, Nothing, Response] = pdfRoutes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // ── Combined test layer ───────────────────────────────────────────────────────

  private val testLayers: ZLayer[Any, Throwable, InvoiceApi.BillingEnv] = testJwtService ++ stubInvoiceService

  // ── Tests ────────────────────────────────────────────────────────────────────

  def spec =
    suite("InvoiceApi — PDF endpoint 406 regression")(
      // -- invoicePdfEndpoint --------------------------------------------------

      suite("GET /api/billing/invoices/{id}/pdf")(
        // REGRESSION: the root cause of the bug was that byteArrayBody declares
        // application/octet-stream, so NotAcceptableInterceptor rejected Accept: application/pdf.
        // After the fix, the endpoint declares application/pdf via PdfCodecFormat, and
        // Accept: application/pdf must no longer be rejected.
        test("[REGRESSION] Accept: application/pdf → NOT 406 (core regression — was rejected before fix)") {
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/invoices/${invoiceAId.value}/pdf").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
          } yield assertTrue(resp.status != Status.NotAcceptable)
        },
        test("Accept: */* → NOT 406") {
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/invoices/${invoiceAId.value}/pdf").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "*/*")
            resp  <- run(req)
          } yield assertTrue(resp.status != Status.NotAcceptable)
        },
        test("valid invoice in own company → 200 with Content-Type: application/pdf") {
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/invoices/${invoiceAId.value}/pdf").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
            ctRaw  = resp.rawHeader("Content-Type").getOrElse("")
          } yield assertTrue(
            resp.status == Status.Ok,
            ctRaw.contains("application/pdf")
          )
        },

        // CRITICAL tenant-isolation negative test: companyA JWT + companyB invoice → 404, not 200
        test("[CRITICAL] invoice of another company → 404 (tenant isolation, not 406)") {
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/invoices/${invoiceBId.value}/pdf").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
          } yield assertTrue(
            resp.status == Status.NotFound,
            resp.status != Status.NotAcceptable
          )
        },
        test("unauthenticated request → 401") {
          val req = Request.get(URL.decode(s"/api/billing/invoices/${invoiceAId.value}/pdf").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        },
        test("invalid UUID in path → 400") {
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode("/api/billing/invoices/not-a-uuid/pdf").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.BadRequest)
        }
      ),

      // -- rideReceiptEndpoint -------------------------------------------------

      suite("GET /api/billing/rides/{rideId}/receipt")(
        // REGRESSION: same 406 bug existed on the receipt endpoint (same byteArrayBody root cause).
        // Before the fix, Accept: application/pdf was rejected with 406 because the endpoint
        // declared application/octet-stream via byteArrayBody.
        test("[REGRESSION] Accept: application/pdf → NOT 406 (core regression on receipt endpoint)") {
          val rideId = UUID.randomUUID()
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/rides/$rideId/receipt").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
          } yield assertTrue(resp.status != Status.NotAcceptable)
        },
        test("Accept: */* → NOT 406") {
          val rideId = UUID.randomUUID()
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/rides/$rideId/receipt").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "*/*")
            resp  <- run(req)
          } yield assertTrue(resp.status != Status.NotAcceptable)
        },
        test("valid ride in own company → 200 with Content-Type: application/pdf") {
          val rideId = UUID.randomUUID()
          for {
            token <- generateToken(dispatcherA)
            req    = Request
                       .get(URL.decode(s"/api/billing/rides/$rideId/receipt").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader("Accept", "application/pdf")
            resp  <- run(req)
            ctRaw  = resp.rawHeader("Content-Type").getOrElse("")
          } yield assertTrue(
            resp.status == Status.Ok,
            ctRaw.contains("application/pdf")
          )
        },
        test("unauthenticated request → 401") {
          val rideId = UUID.randomUUID()
          val req    = Request.get(URL.decode(s"/api/billing/rides/$rideId/receipt").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      )
    ).provide(testLayers) @@ TestAspect.sequential
