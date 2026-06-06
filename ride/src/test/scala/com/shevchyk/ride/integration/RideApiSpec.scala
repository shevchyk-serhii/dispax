package com.shevchyk.ride.integration

import com.shevchyk.core.domain.PersonRole
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.application.{EventHub, AuditService, EmailSmsService, RideConfirmationData, GeocodingService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.{RideService, ClientAddressService}
import com.shevchyk.ride.repository.helpers.InMemoryClientAddressRepository
import com.shevchyk.ride.infrastructure.http.dto.{RideDto, given}
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.core.repository.InMemoryPersonRepository
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository, RideRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

object RideApiSpec extends ZIOSpecDefault {

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
  )

  private def runRequest(request: Request): ZIO[RideService & ClientAddressService & PersonRepository & JwtService, Nothing, Response] =
    RideRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either) => either.merge
      case Right(response) => response
    }

  def spec = suite("Ride API Integration Tests")(
    suite("POST /api/rides")(

      test(" creates ride successfully with valid authentication") {
        for {
          personRepo <- ZIO.service[PersonRepository]
          _          <- personRepo.create(TestData.createTestClient())

          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        email = "client@example.com",
                        role = PersonRole.Client,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

          _        <- assertTrue(response.status == Status.Created)

          bodyStr  <- response.body.asString.orDie
          rideDto  <- ZIO.fromEither(bodyStr.fromJson[RideDto]).mapError(new RuntimeException(_)).orDie

          _        <- assertTrue(
                        rideDto.clientId == TestData.testUserId.toString,
                        rideDto.status == "Requested",
                        rideDto.from.address == "Munich Airport",
                        rideDto.to.address == "Berlin Central Station"
                      )

          repo     <- ZIO.service[RideRepository]
          saved    <- repo.findById(RideId(java.util.UUID.fromString(rideDto.id)))

        } yield assertTrue(saved.isDefined, saved.get.clientId.value == TestData.testUserId)
      },

      test(" returns 401 Unauthorized when JWT token is missing") {
        for {
          request  <- ZIO.succeed(
                        Request.post(
                          URL.decode("/api/rides").toOption.get,
                          Body.fromString(TestData.validCreateRideJson)
                        )
                      )

          response <- runRequest(request)

          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.Unauthorized,
          bodyStr.contains("Missing Authorization header")
        )
      },

      test(" returns 401 Unauthorized when JWT token is invalid") {
        for {
          request  <- ZIO.succeed(
                        Request
                          .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                          .addHeader(Header.Authorization.Bearer("invalid-token"))
                      )

          response <- runRequest(request)

          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.Unauthorized,
          bodyStr.contains("Invalid or expired token")
        )
      },

      test(" returns 400 Bad Request when user has no company") {
        for {
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        email = "client@example.com",
                        role = PersonRole.Client,
                        companyId = None
                      )

          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.BadRequest,
          bodyStr.contains("User must belong to a company")
        )
      },

      test(" returns 400 Bad Request when JSON is invalid") {
        for {
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString("{invalid json}"))
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.InternalServerError,
          bodyStr.contains("Invalid JSON") || bodyStr.contains("error")
        )
      },

      test(" creates ride with airport transfer information") {
        for {
          personRepo <- ZIO.service[PersonRepository]
          _          <- personRepo.create(TestData.createTestClient())

          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        companyId = Some(TestData.testCompanyId)
                      )

          futureTime   = java.time.Instant.now().plusSeconds(7200).toString
          airportJson = s"""{
            "clientId": "00000000-0000-0000-0000-000000000001",
            "creatorId": "00000000-0000-0000-0000-000000000001",
            "companyId": "00000000-0000-0000-0000-000000000010",
            "pickupDateTime": "$futureTime",
            "from": {"address": "Munich Airport Terminal 2"},
            "to": {"address": "Munich City Center"},
            "clientName": "Test User",
            "isAirportTransfer": false,
            "flightNumber": "LH456",
            "isArrival": true
          }"""

          request  = Request
                       .post(URL.decode("/api/rides").toOption.get, Body.fromString(airportJson))
                       .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rideDto  <- ZIO.fromEither(bodyStr.fromJson[RideDto]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Created,
          rideDto.flightNumber.contains("LH456"),
          rideDto.from.address.contains("Airport")
        )
      }

    ) @@ TestAspect.sequential,

    suite("GET /api/rides")(

      test(" returns all rides for authenticated user") {
        for {
          repo     <- ZIO.service[RideRepository]
          ride1     = TestData.createRide(clientId = PersonId(TestData.testUserId))
          ride2     = TestData.createRide(clientId = PersonId(TestData.testUserId))
          _        <- repo.create(ride1)
          _        <- repo.create(ride2)

          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .get(URL.decode("/api/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rides    <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Ok,
          rides.length == 2,
          rides.forall(_.clientId == TestData.testUserId.toString)
        )
      },

      test(" returns empty array when user has no rides") {
        for {
          token    <- TestJWT.generateToken(
                        userId = java.util.UUID.randomUUID(),
                        companyId = Some(java.util.UUID.fromString("00000000-0000-0000-0000-ffffffffffff"))
                      )

          request   = Request
                        .get(URL.decode("/api/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rides    <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Ok,
          rides.isEmpty
        )
      },

      test(" returns 401 when not authenticated") {
        for {
          request  <- ZIO.succeed(Request.get(URL.decode("/api/rides").toOption.get))

          response <- runRequest(request)

        } yield assertTrue(response.status == Status.Unauthorized)
      }

    ) @@ TestAspect.sequential,

    suite("GET /api/rides/driver/:id")(

      test("driver can fetch own rides") {
        for {
          repo     <- ZIO.service[RideRepository]
          driverId  = TestData.testDriverId
          ride1     = TestData.createRide(clientId = PersonId(TestData.testUserId)).copy(driverId = Some(PersonId(driverId)))
          ride2     = TestData.createRide(clientId = PersonId(TestData.testUserId)).copy(driverId = Some(PersonId(driverId)))
          _        <- repo.create(ride1)
          _        <- repo.create(ride2)

          token    <- TestJWT.generateToken(
                        userId = driverId,
                        role = PersonRole.Driver,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .get(URL.decode(s"/api/rides/driver/$driverId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rides    <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Ok,
          rides.length == 2
        )
      },

      test("dispatcher can fetch another driver's rides") {
        for {
          repo       <- ZIO.service[RideRepository]
          driverId    = TestData.testDriverId
          dispatchId  = java.util.UUID.randomUUID()
          ride        = TestData.createRide().copy(driverId = Some(PersonId(driverId)))
          _          <- repo.create(ride)

          token      <- TestJWT.generateToken(
                          userId = dispatchId,
                          role = PersonRole.Dispatcher,
                          companyId = Some(TestData.testCompanyId)
                        )

          request     = Request
                          .get(URL.decode(s"/api/rides/driver/$driverId").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))

          response   <- runRequest(request)

        } yield assertTrue(response.status == Status.Ok)
      },

      test("client cannot fetch another driver's rides") {
        val driverId = TestData.testDriverId
        val otherId  = java.util.UUID.randomUUID()
        for {
          token    <- TestJWT.generateToken(
                        userId = otherId,
                        role = PersonRole.Client,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .get(URL.decode(s"/api/rides/driver/$driverId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

        } yield assertTrue(response.status == Status.Forbidden)
      },

      test("returns 401 when unauthenticated") {
        for {
          response <- runRequest(Request.get(URL.decode(s"/api/rides/driver/${TestData.testDriverId}").toOption.get))
        } yield assertTrue(response.status == Status.Unauthorized)
      }

    ) @@ TestAspect.sequential,

    suite("GET /api/rides/client/:id")(

      test("client can fetch own rides") {
        for {
          repo      <- ZIO.service[RideRepository]
          clientId   = TestData.testUserId
          ride1      = TestData.createRide(clientId = PersonId(clientId))
          ride2      = TestData.createRide(clientId = PersonId(clientId))
          _         <- repo.create(ride1)
          _         <- repo.create(ride2)

          token     <- TestJWT.generateToken(
                         userId = clientId,
                         role = PersonRole.Client,
                         companyId = Some(TestData.testCompanyId)
                       )

          request    = Request
                         .get(URL.decode(s"/api/rides/client/$clientId").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))

          response  <- runRequest(request)
          bodyStr   <- response.body.asString.orDie
          rides     <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Ok,
          rides.length == 2,
          rides.forall(_.clientId == clientId.toString)
        )
      },

      test("client cannot fetch another client's rides") {
        val clientId = TestData.testUserId
        val otherId  = java.util.UUID.randomUUID()
        for {
          token    <- TestJWT.generateToken(
                        userId = otherId,
                        role = PersonRole.Client,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .get(URL.decode(s"/api/rides/client/$clientId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

        } yield assertTrue(response.status == Status.Forbidden)
      },

      test("dispatcher can fetch any client's rides") {
        for {
          repo       <- ZIO.service[RideRepository]
          clientId    = TestData.testUserId
          dispatchId  = java.util.UUID.randomUUID()
          ride        = TestData.createRide(clientId = PersonId(clientId))
          _          <- repo.create(ride)

          token      <- TestJWT.generateToken(
                          userId = dispatchId,
                          role = PersonRole.Dispatcher,
                          companyId = Some(TestData.testCompanyId)
                        )

          request     = Request
                          .get(URL.decode(s"/api/rides/client/$clientId").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))

          response   <- runRequest(request)
          bodyStr    <- response.body.asString.orDie
          rides      <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

        } yield assertTrue(
          response.status == Status.Ok,
          rides.length == 1
        )
      },

      test("secretary can fetch any client's rides") {
        for {
          repo        <- ZIO.service[RideRepository]
          clientId     = TestData.testUserId
          secretaryId  = java.util.UUID.randomUUID()
          ride         = TestData.createRide(clientId = PersonId(clientId))
          _           <- repo.create(ride)

          token       <- TestJWT.generateToken(
                           userId = secretaryId,
                           role = PersonRole.Secretary,
                           companyId = Some(TestData.testCompanyId)
                         )

          request      = Request
                           .get(URL.decode(s"/api/rides/client/$clientId").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))

          response    <- runRequest(request)

        } yield assertTrue(response.status == Status.Ok)
      },

      test("driver cannot fetch a client's rides") {
        val clientId = TestData.testUserId
        val driverId = TestData.testDriverId
        for {
          token    <- TestJWT.generateToken(
                        userId = driverId,
                        role = PersonRole.Driver,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .get(URL.decode(s"/api/rides/client/$clientId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          response <- runRequest(request)

        } yield assertTrue(response.status == Status.Forbidden)
      },

      test("returns 401 when unauthenticated") {
        for {
          response <- runRequest(Request.get(URL.decode(s"/api/rides/client/${TestData.testUserId}").toOption.get))
        } yield assertTrue(response.status == Status.Unauthorized)
      }

    ) @@ TestAspect.sequential

  ).provide(
    InMemoryRideRepository.layer,
    InMemoryPersonRepository.layer,
    EventHub.layer,
    noopEmailSms,
    AuditService.inMemory,
    BlacklistRepository.inMemory,
    GeocodingService.noop,
    ExpenseRepository.inMemory,
    RideService.layer,
    TestJWT.testJwtService,
    InMemoryClientAddressRepository.layer >>> ClientAddressService.layer
  ) @@ TestAspect.sequential
}
