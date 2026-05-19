package com.shevchyk.ride.infrastructure

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, PersonRole}
import com.shevchyk.ride.application.service.ClientAddressService
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.ClientAddressRoutes
import com.shevchyk.ride.repository.helpers.InMemoryClientAddressRepository
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object ClientAddressRoutesSpec extends ZIOSpecDefault {

  private val testLayers =
    InMemoryClientAddressRepository.layer >+>
    ClientAddressService.layer ++
    TestJWT.testJwtService

  private def runRequest(request: Request): ZIO[ClientAddressService & JwtService, Nothing, Response] =
    ClientAddressRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  private def clientToken(userId: UUID = TestData.testUserId): ZIO[JwtService, Throwable, String] =
    TestJWT.generateToken(
      userId = userId,
      email = "client@example.com",
      role = PersonRole.Client,
      companyId = Some(TestData.testCompanyId)
    )

  private def dispatcherToken: ZIO[JwtService, Throwable, String] =
    TestJWT.generateToken(
      userId = TestData.testUserId,
      email = "dispatcher@example.com",
      role = PersonRole.Dispatcher,
      companyId = Some(TestData.testCompanyId)
    )

  private val validAddressJson =
    """{"address":"Marienplatz 1, Munich","label":"Home"}"""

  private val clientIdStr = TestData.testUserId.toString

  def spec = suite("ClientAddressRoutes")(

    suite("GET /api/clients/:clientId/addresses")(
      test("client can access own addresses (returns 200)") {
        for {
          token    <- clientToken()
          request   = Request
                        .get(URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("dispatcher can access client addresses") {
        for {
          token    <- dispatcherToken
          request   = Request
                        .get(URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("other client cannot access another client's addresses (403)") {
        val otherId = UUID.randomUUID()
        for {
          token    <- clientToken(otherId)  // token for different user
          request   = Request
                        .get(URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without auth header") {
        val request = Request.get(URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get)
        runRequest(request).map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("POST /api/clients/:clientId/addresses")(
      test("client can save own address (201)") {
        for {
          token    <- clientToken()
          request   = Request
                        .post(
                          URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get,
                          Body.fromString(validAddressJson)
                        )
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Created)
      }.provide(testLayers),

      test("returns 500 for invalid JSON body") {
        for {
          token    <- clientToken()
          request   = Request
                        .post(
                          URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get,
                          Body.fromString("not-json")
                        )
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.InternalServerError)
      }.provide(testLayers),

      test("other client cannot post to another client's addresses (403)") {
        val otherId = UUID.randomUUID()
        for {
          token    <- clientToken(otherId)
          request   = Request
                        .post(
                          URL.decode(s"/api/clients/$clientIdStr/addresses").toOption.get,
                          Body.fromString(validAddressJson)
                        )
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    ),

    suite("DELETE /api/clients/:clientId/addresses/:addressId")(
      test("returns 400 for invalid UUID addressId") {
        for {
          token    <- clientToken()
          request   = Request
                        .delete(URL.decode(s"/api/clients/$clientIdStr/addresses/not-a-uuid").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.BadRequest || response.status == Status.InternalServerError)
      }.provide(testLayers),

      test("returns 403 when other client tries to delete") {
        val otherId = UUID.randomUUID()
        for {
          token    <- clientToken(otherId)
          request   = Request
                        .delete(URL.decode(s"/api/clients/$clientIdStr/addresses/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runRequest(request)
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    )
  )
}
