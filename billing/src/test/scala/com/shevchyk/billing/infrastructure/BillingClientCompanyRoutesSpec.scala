package com.shevchyk.billing.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.infrastructure.http.ClientCompanyRoutes
import com.shevchyk.billing.repository.ClientCompanyRepository
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object BillingClientCompanyRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test", audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val dispatcherId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val clientId     = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val companyId    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private def token(role: PersonRole, uid: UUID, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(
      Person(PersonId(uid), "Test", "test@example.com", role, cid.map(CompanyId.apply))
    ))

  private val inMemoryClientCompanyRepo: ZLayer[Any, Nothing, ClientCompanyRepository] = ZLayer.succeed {
    new ClientCompanyRepository {
      private val store = new ConcurrentHashMap[ClientCompanyId, ClientCompany]()
      def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                              = ZIO.succeed(Option(store.get(id)))
      def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]                 = ZIO.succeed(store.values().asScala.filter(_.taxiCompanyId == taxiCompanyId).toList)
      def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany] = ZIO.succeed {
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
      def delete(id: ClientCompanyId): Task[Boolean] = ZIO.succeed(Option(store.remove(id)).isDefined)
    }
  }

  private val testLayers = inMemoryClientCompanyRepo ++ testJwtService

  private def run(req: Request): ZIO[ClientCompanyRepository & JwtService, Nothing, Response] =
    ClientCompanyRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val validCompanyJson = """{"name":"Acme Corp","address":"Berlin"}"""

  def spec = suite("billing/ClientCompanyRoutes")(

    suite("GET /api/billing/companies")(
      test("dispatcher gets list (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode("/api/billing/companies").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("secretary gets list (200)") {
        for {
          tok      <- token(PersonRole.Secretary, dispatcherId)
          response <- run(Request.get(URL.decode("/api/billing/companies").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/billing/companies").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode("/api/billing/companies").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("POST /api/billing/companies")(
      test("dispatcher can create company (201)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.post(
                        URL.decode("/api/billing/companies").toOption.get,
                        Body.fromString(validCompanyJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Created)
      }.provide(testLayers),

      test("secretary cannot create company (403)") {
        for {
          tok      <- token(PersonRole.Secretary, dispatcherId)
          response <- run(Request.post(
                        URL.decode("/api/billing/companies").toOption.get,
                        Body.fromString(validCompanyJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.post(URL.decode("/api/billing/companies").toOption.get, Body.fromString(validCompanyJson)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("PUT /api/billing/companies/:id")(
      test("returns 404 for unknown company") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.put(
                        URL.decode(s"/api/billing/companies/${UUID.randomUUID()}").toOption.get,
                        Body.fromString(validCompanyJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound)
      }.provide(testLayers),

      test("returns 400 for invalid UUID") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.put(
                        URL.decode("/api/billing/companies/not-a-uuid").toOption.get,
                        Body.fromString(validCompanyJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.BadRequest)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.put(URL.decode(s"/api/billing/companies/${UUID.randomUUID()}").toOption.get, Body.fromString(validCompanyJson)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("DELETE /api/billing/companies/:id")(
      test("returns 404 for unknown company") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.delete(URL.decode(s"/api/billing/companies/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.delete(URL.decode(s"/api/billing/companies/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.delete(URL.decode(s"/api/billing/companies/${UUID.randomUUID()}").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    )
  )
}
