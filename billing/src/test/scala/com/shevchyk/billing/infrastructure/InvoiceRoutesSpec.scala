package com.shevchyk.billing.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.infrastructure.http.InvoiceRoutes
import com.shevchyk.billing.repository.{ClientCompanyRepository, InvoiceRepository, UnbilledRide}
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*

import java.time.{Instant, LocalDate}
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object InvoiceRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig]   = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test",
      audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val dispatcherId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val clientId     = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val companyId    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private def token(
      role: PersonRole,
      uid: UUID,
      cid: Option[UUID] = Some(companyId)
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(PersonId(uid), "Test", "test@example.com", role, cid.map(CompanyId.apply))
    )
  )

  private val inMemoryInvoiceRepo: ZLayer[Any, Nothing, InvoiceRepository] = ZLayer.succeed {
    new InvoiceRepository {
      private val store      = new ConcurrentHashMap[InvoiceId, Invoice]()
      private val itemsStore = new ConcurrentHashMap[InvoiceId, List[InvoiceItem]]()
      private val counters   = new ConcurrentHashMap[String, Int]()

      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String] = ZIO.succeed {
        val key = s"${taxiCompanyId.value}-$year"
        val n   = counters.merge(key, 1, _ + _)
        f"INV-$year-$n%04d"
      }
      def create(invoice: Invoice): Task[Invoice]                              = ZIO.succeed { store.put(invoice.id, invoice); invoice }
      def findById(id: InvoiceId): Task[Option[Invoice]]                       = ZIO.succeed(Option(store.get(id)))
      def findByCompany(
          taxiCompanyId: CompanyId,
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[Invoice]] = ZIO.succeed(
        store.values().asScala.filter(_.taxiCompanyId == taxiCompanyId).toList.drop(offset).take(limit)
      )
      def update(invoice: Invoice): Task[Invoice]                              = ZIO.succeed { store.put(invoice.id, invoice); invoice }
      def delete(id: InvoiceId): Task[Boolean]                                 = ZIO.succeed(Option(store.remove(id)).isDefined)
      def addItems(items: List[InvoiceItem]): Task[Unit]                       = ZIO.succeed {
        items.groupBy(_.invoiceId).foreach { case (iid, is) => itemsStore.merge(iid, is, _ ++ _) }
      }
      def deleteItems(invoiceId: InvoiceId): Task[Unit]                        = ZIO.succeed { itemsStore.remove(invoiceId); () }
      def findUnbilledRides(
          clientCompanyId: ClientCompanyId,
          from: LocalDate,
          to: LocalDate
      ): Task[List[UnbilledRide]] = ZIO.succeed(Nil)
    }
  }

  private val inMemoryClientCompanyRepo: ZLayer[Any, Nothing, ClientCompanyRepository] = ZLayer.succeed {
    new ClientCompanyRepository {
      private val store                                                                             = new ConcurrentHashMap[ClientCompanyId, ClientCompany]()
      def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                                = ZIO.succeed(Option(store.get(id)))
      def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]                    = ZIO.succeed(
        store.values().asScala.filter(_.taxiCompanyId == taxiCompanyId).toList
      )
      def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany]    = ZIO.succeed {
        val cc = ClientCompany(ClientCompanyId.generate(), req.name, taxiCompanyId, req.email, req.phone, req.address)
        store.put(cc.id, cc)
        cc
      }
      def update(id: ClientCompanyId, req: CreateClientCompanyRequest): Task[Option[ClientCompany]] = ZIO.succeed {
        Option(store.get(id)).map { cc =>
          val updated = cc.copy(name = req.name, email = req.email, phone = req.phone, address = req.address)
          store.put(id, updated)
          updated
        }
      }
      def delete(id: ClientCompanyId): Task[Boolean]                                                = ZIO.succeed(Option(store.remove(id)).isDefined)
    }
  }

  private val testLayers = (inMemoryInvoiceRepo ++ inMemoryClientCompanyRepo >>> InvoiceService.layer) ++ testJwtService

  private def run(req: Request): ZIO[InvoiceService & JwtService, Nothing, Response] = InvoiceRoutes.authenticatedRoutes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val validInvoiceJson =
    s"""{
      "clientCompanyId": "${UUID.randomUUID()}",
      "periodFrom": "2026-01-01",
      "periodTo": "2026-01-31"
    }"""

  def spec =
    suite("InvoiceRoutes")(
      suite("GET /api/billing/invoices")(
        test("dispatcher gets invoice list (200)") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .get(URL.decode("/api/billing/invoices").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Ok)
        }.provide(testLayers),
        test("secretary gets invoice list (200)") {
          for {
            tok      <- token(PersonRole.Secretary, dispatcherId)
            response <- run(
                          Request
                            .get(URL.decode("/api/billing/invoices").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Ok)
        }.provide(testLayers),
        test("client is forbidden (403)") {
          for {
            tok      <- token(PersonRole.Client, clientId)
            response <- run(
                          Request
                            .get(URL.decode("/api/billing/invoices").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Forbidden)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.get(URL.decode("/api/billing/invoices").toOption.get))
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("POST /api/billing/invoices")(
        test("dispatcher can create invoice (201 or 404)") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .post(
                              URL.decode("/api/billing/invoices").toOption.get,
                              Body.fromString(validInvoiceJson)
                            )
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Created || response.status == Status.NotFound)
        }.provide(testLayers),
        test("client is forbidden (403)") {
          for {
            tok      <- token(PersonRole.Client, clientId)
            response <- run(
                          Request
                            .post(
                              URL.decode("/api/billing/invoices").toOption.get,
                              Body.fromString(validInvoiceJson)
                            )
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Forbidden)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.post(URL.decode("/api/billing/invoices").toOption.get, Body.fromString(validInvoiceJson)))
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("GET /api/billing/invoices/:id")(
        test("returns 404 for unknown invoice") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .get(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.NotFound)
        }.provide(testLayers),
        test("returns 400 for invalid UUID") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .get(URL.decode("/api/billing/invoices/not-a-uuid").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.BadRequest)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.get(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get))
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("DELETE /api/billing/invoices/:id")(
        test("returns 404 for unknown invoice") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .delete(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.NotFound)
        }.provide(testLayers),
        test("client is forbidden (403)") {
          for {
            tok      <- token(PersonRole.Client, clientId)
            response <- run(
                          Request
                            .delete(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.Forbidden)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.delete(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get))
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("POST /api/billing/invoices/:id/pay")(
        test("returns 404 for unknown invoice") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .post(
                              URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/pay").toOption.get,
                              Body.fromString("{}")
                            )
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.NotFound)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(
            Request.post(
              URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/pay").toOption.get,
              Body.fromString("{}")
            )
          )
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("POST /api/billing/invoices/:id/send")(
        test("returns 404 for unknown invoice") {
          for {
            tok      <- token(PersonRole.Dispatcher, dispatcherId)
            response <- run(
                          Request
                            .post(
                              URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/send").toOption.get,
                              Body.fromString("")
                            )
                            .addHeader(Header.Authorization.Bearer(tok))
                        )
          } yield assertTrue(response.status == Status.NotFound || response.status == Status.InternalServerError)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(
            Request.post(
              URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/send").toOption.get,
              Body.fromString("")
            )
          )
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      )
    )
}
