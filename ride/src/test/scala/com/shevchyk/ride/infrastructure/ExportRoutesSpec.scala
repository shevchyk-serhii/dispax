package com.shevchyk.ride.infrastructure

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EmailSmsService, EventHub, RideConfirmationData}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{BlacklistRepository, InMemoryPersonRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.ExportRoutes
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository, RideRatingRepository}
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object ExportRoutesSpec extends ZIOSpecDefault {

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
    ExpenseRepository.inMemory ++
    RideRatingRepository.inMemory ++
    TestJWT.testJwtService

  private val allLayers = testLayers >+> RideService.layer

  private def runRequest(request: Request): ZIO[RideService & ExpenseRepository & PersonRepository & JwtService, Nothing, Response] =
    ExportRoutes.authenticatedRoutes.run(request).either.map {
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

  def spec = suite("ExportRoutes")(

    suite("GET /api/export/datev")(
      test("returns 200 with JSON export for dispatcher") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/export/datev?month=2026-05").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok &&
          body.contains("revenue") &&
          body.contains("expenses") &&
          body.contains("summary") &&
          body.contains("2026-05")
        )
      }.provide(allLayers),

      test("returns 403 for non-dispatcher") {
        for {
          token    <- clientToken
          request   = Request
                        .get(URL.decode("/api/export/datev").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers),

      test("returns 401 without auth header") {
        val request = Request.get(URL.decode("/api/export/datev").toOption.get)
        runRequest(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(allLayers),

      test("defaults to current month when month param absent") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/export/datev").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(response.status == Status.Ok && body.contains("month"))
      }.provide(allLayers),

      test("revenue CSV contains header and completed ride row") {
        for {
          personRepo <- ZIO.service[PersonRepository]
          _          <- personRepo.create(TestData.createTestClient())
          _          <- personRepo.create(
                          Person(
                            id = PersonId(TestData.testDriverId),
                            name = "Driver",
                            email = "driver@example.com",
                            role = PersonRole.Driver,
                            companyId = Some(CompanyId(TestData.testCompanyId))
                          )
                        )
          service    <- ZIO.service[RideService]
          ride       <- service.createRide(TestData.createRideRequest())
          assigned   <- service.assignDriver(ride.id, PersonId(TestData.testDriverId))
          started    <- service.startRide(assigned.id, PersonId(TestData.testDriverId))
          _          <- service.completeRide(started.id)

          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/export/datev/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok &&
          body.contains("Umsatz") &&
          body.contains("8400") &&
          body.contains("EUR")
        )
      }.provide(allLayers)
    ),

    suite("GET /api/export/datev/rides")(
      test("returns CSV content-type with header row") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/export/datev/rides?month=2026-05").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok &&
          body.startsWith("Umsatz (ohne Soll/Haben-Kz)")
        )
      }.provide(allLayers),

      test("returns 403 for client role") {
        for {
          token    <- clientToken
          request   = Request
                        .get(URL.decode("/api/export/datev/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers)
    ),

    suite("GET /api/export/datev/expenses")(
      test("returns CSV with expense header when no expenses") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/export/datev/expenses?month=2026-05").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok &&
          body.startsWith("Umsatz (ohne Soll/Haben-Kz)")
        )
      }.provide(allLayers),

      test("returns 403 for non-dispatcher") {
        for {
          token    <- clientToken
          request   = Request
                        .get(URL.decode("/api/export/datev/expenses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(allLayers),

      test("includes expense row when expense exists") {
        for {
          expenseRepo <- ZIO.service[ExpenseRepository]
          _           <- expenseRepo.create(
                           Expense(
                             id = ExpenseId.generate(),
                             driverId = PersonId(TestData.testDriverId),
                             companyId = CompanyId(TestData.testCompanyId),
                             category = ExpenseCategory.Fuel,
                             amount = BigDecimal(45.50),
                             createdAt = Instant.now()
                           )
                         )
          token       <- dispatcherToken
          request      = Request
                           .get(URL.decode("/api/export/datev/expenses").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
          response    <- runRequest(request)
          body        <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok &&
          body.contains("4530") &&   // Fuel account
          body.contains("70000") &&  // counter account
          body.contains("45.50")
        )
      }.provide(allLayers)
    )
  )
}
