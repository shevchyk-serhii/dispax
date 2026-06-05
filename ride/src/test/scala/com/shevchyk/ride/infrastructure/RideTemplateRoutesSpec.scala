package com.shevchyk.ride.infrastructure

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EmailSmsService, EventHub, RideConfirmationData, GeocodingService}
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole}
import com.shevchyk.core.repository.{BlacklistRepository, InMemoryPersonRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.RideTemplateRoutes
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository, RideRatingRepository, RideTemplateRepository}
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object RideTemplateRoutesSpec extends ZIOSpecDefault {

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
  )

  private val testLayers =
    InMemoryRideRepository.layer ++
    InMemoryPersonRepository.layer ++
    EventHub.layer ++
    noopEmailSms ++
    AuditService.inMemory ++
    BlacklistRepository.inMemory ++
    GeocodingService.noop ++
    ExpenseRepository.inMemory ++
    RideRatingRepository.inMemory ++
    RideTemplateRepository.inMemory ++
    TestJWT.testJwtService

  private val allLayers = testLayers >+> RideService.layer

  private def runRequest(request: Request): ZIO[RideTemplateRepository & RideService & JwtService, Nothing, Response] =
    RideTemplateRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  private def dispatcherToken: ZIO[JwtService, Throwable, String] =
    TestJWT.generateToken(
      userId = TestData.testUserId,
      email = "dispatcher@example.com",
      role = PersonRole.Dispatcher,
      companyId = Some(TestData.testCompanyId)
    )

  private def clientToken: ZIO[JwtService, Throwable, String] =
    TestJWT.generateToken(
      userId = TestData.testUserId,
      email = "client@example.com",
      role = PersonRole.Client,
      companyId = Some(TestData.testCompanyId)
    )

  private val validTemplateJson =
    s"""{
      "clientId": "${TestData.testUserId}",
      "name": "Weekly Airport",
      "fromAddress": "Home",
      "toAddress": "Airport",
      "pickupTime": "08:00",
      "recurrencePattern": "Weekly",
      "recurrenceDays": [1, 5]
    }"""

  def spec = suite("RideTemplateRoutes")(

    suite("GET /api/ride-templates")(
      test("dispatcher can list templates (returns 200)") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/ride-templates").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Ok)
      }.provide(allLayers),

      test("returns 403 for client role") {
        for {
          token    <- clientToken
          request   = Request
                        .get(URL.decode("/api/ride-templates").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers),

      test("returns 401 without auth header") {
        val request = Request.get(URL.decode("/api/ride-templates").toOption.get)
        runRequest(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(allLayers)
    ),

    suite("POST /api/ride-templates")(
      test("returns 403 for client role") {
        for {
          token    <- clientToken
          request   = Request
                        .post(URL.decode("/api/ride-templates").toOption.get, Body.fromString(validTemplateJson))
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers),

      test("returns 401 without auth header") {
        val request = Request.post(URL.decode("/api/ride-templates").toOption.get, Body.fromString(validTemplateJson))
        runRequest(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(allLayers)
    ),

    suite("DELETE /api/ride-templates/:id")(
      test("returns 400 for invalid UUID") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .delete(URL.decode("/api/ride-templates/not-a-uuid").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.BadRequest)
      }.provide(allLayers),

      test("returns 403 for client role") {
        for {
          token    <- clientToken
          request   = Request
                        .delete(URL.decode(s"/api/ride-templates/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers)
    )
  )
}
