package com.shevchyk.ride.infrastructure

import com.shevchyk.core.domain.PersonRole
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService, EmailSmsService, RideConfirmationData, GeocodingService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.StatsRoutes
import com.shevchyk.core.repository.InMemoryPersonRepository
import com.shevchyk.ride.repository.{InMemoryRideRepository, ExpenseRepository, RideRatingRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

import java.time.{Instant, LocalDate, ZoneOffset}
import java.util.UUID

object StatsRoutesSpec extends ZIOSpecDefault {

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
  )

  private val testDriver = Person(
    id = PersonId(TestData.testDriverId),
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(CompanyId(TestData.testCompanyId))
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
      TestJWT.testJwtService

  private val allLayers = testLayers >+> RideService.layer

  private def runRequest(
      request: Request
  ): ZIO[RideService & ExpenseRepository & PersonRepository & RideRatingRepository & JwtService, Nothing, Response] =
    StatsRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  def spec =
    suite("StatsRoutes")(
      suite("GET /api/stats/payroll")(
        test("returns payroll summary for a driver") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(testDriver)
            _          <- personRepo.create(TestData.createTestClient())

            service  <- ZIO.service[RideService]
            ride     <- service.createRide(TestData.createRideRequest())
            assigned <- service.assignDriver(ride.id, testDriver.id)
            started  <- service.startRide(assigned.id, testDriver.id)
            _        <- service.completeRide(started.id)

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            today = LocalDate.now()
            from  = today.minusDays(1).toString
            to    = today.plusDays(1).toString

            request   = Request
                          .get(
                            URL
                              .decode(s"/api/stats/payroll?driverId=${TestData.testDriverId}&from=$from&to=$to")
                              .toOption
                              .get
                          )
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
            body     <- response.body.asString
          } yield assertTrue(
            response.status == Status.Ok &&
              body.contains("totalRides") &&
              body.contains("totalEarnings") &&
              body.contains("netPay")
          )
        }.provide(allLayers)
      ),
      suite("GET /api/stats/cancellations")(
        test("returns cancellation stats") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(TestData.createTestClient())

            service <- ZIO.service[RideService]
            ride    <- service.createRide(TestData.createRideRequest())
            _       <- service.cancelRideWithReason(
                         ride.id,
                         PersonId(TestData.testUserId),
                         PersonRole.Client,
                         CancelRideRequest(reason = "Changed plans")
                       )

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/cancellations").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
            body     <- response.body.asString
          } yield assertTrue(
            response.status == Status.Ok &&
              body.contains("reason") &&
              body.contains("count")
          )
        }.provide(allLayers)
      ),
      suite("GET /api/stats/peak-hours")(
        test("returns peak hours analysis") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(TestData.createTestClient())

            service <- ZIO.service[RideService]
            _       <- service.createRide(TestData.createRideRequest())
            _       <- service.createRide(TestData.createRideRequest())

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/peak-hours?days=7").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
            body     <- response.body.asString
          } yield assertTrue(response.status == Status.Ok)
        }.provide(allLayers)
      ),
      suite("GET /api/stats/client-value")(
        test("returns client lifetime value") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(TestData.createTestClient())
            _          <- personRepo.create(testDriver)

            service  <- ZIO.service[RideService]
            ride     <- service.createRide(TestData.createRideRequest())
            assigned <- service.assignDriver(ride.id, testDriver.id)
            started  <- service.startRide(assigned.id, testDriver.id)
            _        <- service.completeRide(started.id)

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/client-value").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
            body     <- response.body.asString
          } yield assertTrue(
            response.status == Status.Ok &&
              body.contains("clientName") &&
              body.contains("totalRevenue")
          )
        }.provide(allLayers)
      ),
      suite("GET /api/stats/driver-performance")(
        test("returns driver performance scorecard") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(testDriver)
            _          <- personRepo.create(TestData.createTestClient())

            service  <- ZIO.service[RideService]
            ride     <- service.createRide(TestData.createRideRequest())
            assigned <- service.assignDriver(ride.id, testDriver.id)
            started  <- service.startRide(assigned.id, testDriver.id)
            _        <- service.completeRide(started.id)

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/driver-performance").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
            body     <- response.body.asString
          } yield assertTrue(
            response.status == Status.Ok &&
              body.contains("driverName") &&
              body.contains("completionRate") &&
              body.contains("totalEarnings")
          )
        }.provide(allLayers)
      ),
      suite("GET /api/stats/driver-ratings")(
        test("returns driver ratings") {
          for {
            personRepo <- ZIO.service[PersonRepository]
            _          <- personRepo.create(testDriver)

            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "dispatcher@example.com",
                       role = PersonRole.Dispatcher,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/driver-ratings").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
          } yield assertTrue(response.status == Status.Ok)
        }.provide(allLayers)
      ),
      suite("authorization")(
        test("rejects non-dispatcher users") {
          for {
            token <- TestJWT.generateToken(
                       userId = TestData.testUserId,
                       email = "client@example.com",
                       role = PersonRole.Client,
                       companyId = Some(TestData.testCompanyId)
                     )

            request   = Request
                          .get(URL.decode("/api/stats/cancellations").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            response <- runRequest(request)
          } yield assertTrue(response.status == Status.Forbidden || response.status == Status.Unauthorized)
        }.provide(allLayers)
      )
    )
}
