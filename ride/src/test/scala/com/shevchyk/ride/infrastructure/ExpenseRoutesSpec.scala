package com.shevchyk.ride.infrastructure

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, PersonRole}
import com.shevchyk.ride.domain.{ExpenseCategory, ExpenseId, Expense}
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.ExpenseRoutes
import com.shevchyk.ride.repository.ExpenseRepository
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object ExpenseRoutesSpec extends ZIOSpecDefault {

  private val testLayers = ExpenseRepository.inMemory ++ TestJWT.testJwtService

  private def runRequest(request: Request): ZIO[ExpenseRepository & JwtService, Nothing, Response] =
    ExpenseRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  private def driverToken: ZIO[JwtService, Throwable, String] =
    TestJWT.generateToken(
      userId = TestData.testDriverId,
      email = "driver@example.com",
      role = PersonRole.Driver,
      companyId = Some(TestData.testCompanyId)
    )

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

  private val validExpenseJson =
    """{"category":"Fuel","amount":45.50,"description":"Full tank"}"""

  def spec = suite("ExpenseRoutes")(

    suite("POST /api/expenses")(
      test("driver can create expense") {
        for {
          token    <- driverToken
          request   = Request
                        .post(URL.decode("/api/expenses").toOption.get, Body.fromString(validExpenseJson))
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Created)
      }.provide(testLayers),

      test("dispatcher can create expense") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .post(URL.decode("/api/expenses").toOption.get, Body.fromString(validExpenseJson))
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Created)
      }.provide(testLayers),

      test("client cannot create expense (403)") {
        for {
          token    <- clientToken
          request   = Request
                        .post(URL.decode("/api/expenses").toOption.get, Body.fromString(validExpenseJson))
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without auth header") {
        val request = Request.post(URL.decode("/api/expenses").toOption.get, Body.fromString(validExpenseJson))
        runRequest(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers),

      test("returns 500 for invalid JSON body") {
        for {
          token    <- driverToken
          request   = Request
                        .post(URL.decode("/api/expenses").toOption.get, Body.fromString("not-json"))
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.InternalServerError)
      }.provide(testLayers)
    ),

    suite("GET /api/expenses")(
      test("driver sees only own expenses") {
        for {
          repo     <- ZIO.service[ExpenseRepository]
          _        <- repo.create(Expense(
                        id = ExpenseId.generate(),
                        driverId = PersonId(TestData.testDriverId),
                        companyId = CompanyId(TestData.testCompanyId),
                        category = ExpenseCategory.Fuel,
                        amount = BigDecimal(50)
                      ))
          token    <- driverToken
          request   = Request
                        .get(URL.decode("/api/expenses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
          body     <- response.body.asString
        } yield assertTrue(response.status == Status.Ok && body.contains("Fuel"))
      }.provide(testLayers),

      test("dispatcher can list expenses (returns 200)") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode("/api/expenses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("returns 403 for client") {
        for {
          token    <- clientToken
          request   = Request
                        .get(URL.decode("/api/expenses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    ),

    suite("DELETE /api/expenses/:id")(
      test("driver can delete own expense") {
        for {
          repo      <- ZIO.service[ExpenseRepository]
          expense   <- repo.create(Expense(
                         id = ExpenseId.generate(),
                         driverId = PersonId(TestData.testDriverId),
                         companyId = CompanyId(TestData.testCompanyId),
                         category = ExpenseCategory.Fuel,
                         amount = BigDecimal(20)
                       ))
          token     <- driverToken
          request    = Request
                         .delete(URL.decode(s"/api/expenses/${expense.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
          response  <- runRequest(request)
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(testLayers),

      test("returns 400 for invalid UUID") {
        for {
          token    <- driverToken
          request   = Request
                        .delete(URL.decode("/api/expenses/not-a-uuid").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.BadRequest)
      }.provide(testLayers),

      test("returns 403 for client role") {
        for {
          token    <- clientToken
          request   = Request
                        .delete(URL.decode(s"/api/expenses/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    )
  )
}
