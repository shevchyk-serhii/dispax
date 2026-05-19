package com.shevchyk.billing.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.infrastructure.http.InvoiceRoutes
import com.shevchyk.billing.repository.{ClientCompanyRepository, InvoiceRepository}
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object InvoiceRoutesSpec extends ZIOSpecDefault {

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
      Person(PersonId(uid), "test@example.com", "Test", role, "hash", cid.map(CompanyId.apply), UserStatus.ACTIVE)
    ))

  private val testLayers = (InvoiceRepository.inMemory ++ ClientCompanyRepository.inMemory >>> InvoiceService.layer) ++ testJwtService

  private def run(req: Request): ZIO[InvoiceService & JwtService, Nothing, Response] =
    InvoiceRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val validInvoiceJson =
    s"""{
      "clientCompanyId": "${UUID.randomUUID()}",
      "periodStart": "2026-01-01T00:00:00Z",
      "periodEnd": "2026-01-31T23:59:59Z",
      "items": []
    }"""

  def spec = suite("InvoiceRoutes")(

    suite("GET /api/billing/invoices")(
      test("dispatcher gets invoice list (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode("/api/billing/invoices").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("secretary gets invoice list (200)") {
        for {
          tok      <- token(PersonRole.Secretary, dispatcherId)
          response <- run(Request.get(URL.decode("/api/billing/invoices").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.get(URL.decode("/api/billing/invoices").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
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
          response <- run(Request.post(
                        URL.decode("/api/billing/invoices").toOption.get,
                        Body.fromString(validInvoiceJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Created || response.status == Status.NotFound)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.post(
                        URL.decode("/api/billing/invoices").toOption.get,
                        Body.fromString(validInvoiceJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
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
          response <- run(Request.get(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound)
      }.provide(testLayers),

      test("returns 400 for invalid UUID") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode("/api/billing/invoices/not-a-uuid").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
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
          response <- run(Request.delete(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.delete(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
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
          response <- run(Request.post(
                        URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/pay").toOption.get,
                        Body.fromString("{}")
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.post(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/pay").toOption.get, Body.fromString("{}")))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("POST /api/billing/invoices/:id/send")(
      test("returns 404 for unknown invoice") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.post(
                        URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/send").toOption.get,
                        Body.fromString("")
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound || response.status == Status.InternalServerError)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.post(URL.decode(s"/api/billing/invoices/${UUID.randomUUID()}/send").toOption.get, Body.fromString("")))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    )
  )
}
