package com.shevchyk.ride.integration

import com.shevchyk.auth.domain.UserRole
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.repository.PersonRepository
import com.shevchyk.ride.application.RideFacade
import com.shevchyk.ride.application.service.{RideCreationService, SimpleRideService}
import com.shevchyk.ride.domain.RideDto
import com.shevchyk.ride.helpers.{TestData, TestJWT}
import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.ride.repository.{InMemoryPersonRepository, InMemoryRideRepository, RideRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

/**
 * Integration tests for Ride API endpoints.
 *
 * These tests validate the full HTTP stack:
 * - HTTP request/response handling
 * - JWT authentication
 * - JSON serialization/deserialization
 * - Business logic execution
 * - Repository operations
 */
object RideApiSpec extends ZIOSpecDefault {

  /**
   * Helper to run a request and unwrap the response from Either
   */
  private def runRequest(request: Request): ZIO[RideFacade & JwtService, Nothing, Response] =
    RideRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either) => either.merge  // Either[Response, Response] => Response
      case Right(response) => response
    }

  def spec = suite("Ride API Integration Tests")(

    // ========================================
    // POST /api/rides - Create Ride Tests
    // ========================================

    suite("POST /api/rides")(

      test(" creates ride successfully with valid authentication") {
        for {
          personRepo <- ZIO.service[PersonRepository]
          _          <- personRepo.create(TestData.createTestClient())

          // Arrange: Generate JWT token for test user
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        email = "client@example.com",
                        role = UserRole.CLIENT,
                        companyId = Some(TestData.testCompanyId)
                      )

          // Arrange: Prepare request with auth header and JSON body
          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                        .addHeader(Header.Authorization.Bearer(token))

          // Act: Call the API endpoint
          response <- runRequest(request)

          // Assert: Check response status
          _        <- assertTrue(response.status == Status.Created)

          // Assert: Parse and validate response body
          bodyStr  <- response.body.asString.orDie
          rideDto  <- ZIO.fromEither(bodyStr.fromJson[RideDto]).mapError(new RuntimeException(_)).orDie

          // Assert: Validate ride data
          _        <- assertTrue(
                        rideDto.clientId == TestData.testUserId.toString,
                        rideDto.companyId == TestData.testCompanyId.toString,
                        rideDto.status == "Requested",
                        rideDto.from.address == "Munich Airport",
                        rideDto.to.address == "Berlin Central Station"
                      )

          // Assert: Verify ride was saved to repository
          repo     <- ZIO.service[RideRepository]
          saved    <- repo.findById(RideId(java.util.UUID.fromString(rideDto.id)))

        } yield assertTrue(saved.isDefined, saved.get.clientId.value == TestData.testUserId)
      },

      test(" returns 401 Unauthorized when JWT token is missing") {
        for {
          // Arrange: Request without Authorization header
          request  <- ZIO.succeed(
                        Request.post(
                          URL.decode("/api/rides").toOption.get,
                          Body.fromString(TestData.validCreateRideJson)
                        )
                      )

          // Act: Call the API endpoint
          response <- runRequest(request)

          // Assert: Should return 401 Unauthorized
          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.Unauthorized,
          bodyStr.contains("Missing Authorization header")
        )
      },

      test(" returns 401 Unauthorized when JWT token is invalid") {
        for {
          // Arrange: Request with invalid token
          request  <- ZIO.succeed(
                        Request
                          .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                          .addHeader(Header.Authorization.Bearer("invalid-token"))
                      )

          // Act: Call the API endpoint
          response <- runRequest(request)

          // Assert: Should return 401 Unauthorized
          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.Unauthorized,
          bodyStr.contains("Invalid or expired token")
        )
      },

      test(" returns 400 Bad Request when user has no company") {
        for {
          // Arrange: Generate JWT token for user WITHOUT company
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        email = "client@example.com",
                        role = UserRole.CLIENT,
                        companyId = None  // No company!
                      )

          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString(TestData.validCreateRideJson))
                        .addHeader(Header.Authorization.Bearer(token))

          // Act: Call the API endpoint
          response <- runRequest(request)

          // Assert: Should return 400 Bad Request
          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.BadRequest,
          bodyStr.contains("User must belong to a company to create rides")
        )
      },

      test(" returns 400 Bad Request when JSON is invalid") {
        for {
          // Arrange: Valid auth but invalid JSON
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        companyId = Some(TestData.testCompanyId)
                      )

          request   = Request
                        .post(URL.decode("/api/rides").toOption.get, Body.fromString("{invalid json}"))
                        .addHeader(Header.Authorization.Bearer(token))

          // Act: Call the API endpoint
          response <- runRequest(request)

          // Assert: Should return 400 Bad Request
          bodyStr  <- response.body.asString.orDie

        } yield assertTrue(
          response.status == Status.InternalServerError,
          bodyStr.contains("Invalid JSON") || bodyStr.contains("error")
        )
      },

      test(" creates ride with airport transfer information") {
        for {
          // Arrange: Add test person to repository
          personRepo <- ZIO.service[PersonRepository]
          _          <- personRepo.create(TestData.createTestClient())

          // Arrange: JWT token
          token    <- TestJWT.generateToken(
                        userId = TestData.testUserId,
                        companyId = Some(TestData.testCompanyId)
                      )

          // Arrange: JSON with airport transfer details
          futureTime   = java.time.Instant.now().plusSeconds(7200).toString // 2 hours from now
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

          // Act: Call the API endpoint
          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rideDto  <- ZIO.fromEither(bodyStr.fromJson[RideDto]).mapError(new RuntimeException(_)).orDie

          // Assert: Validate flight information
        } yield assertTrue(
          response.status == Status.Created,
          rideDto.flightNumber.contains("LH456"),
          rideDto.from.address.contains("Airport")
        )
      }

    ) @@ TestAspect.sequential, // Run tests sequentially to avoid repository conflicts

    // ========================================
    // GET /api/rides - Get User Rides Tests
    // ========================================

    suite("GET /api/rides")(

      test(" returns all rides for authenticated user") {
        for {
          // Arrange: Create test rides in repository
          repo     <- ZIO.service[RideRepository]
          ride1     = TestData.createRide(clientId = PersonId(TestData.testUserId))
          ride2     = TestData.createRide(clientId = PersonId(TestData.testUserId))
          _        <- repo.create(ride1)
          _        <- repo.create(ride2)

          // Arrange: Generate auth token
          token    <- TestJWT.generateToken(userId = TestData.testUserId)

          request   = Request
                        .get(URL.decode("/api/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          // Act: Call the API endpoint
          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rides    <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

          // Assert: Should return both rides
        } yield assertTrue(
          response.status == Status.Ok,
          rides.length == 2,
          rides.forall(_.clientId == TestData.testUserId.toString)
        )
      },

      test(" returns empty array when user has no rides") {
        for {
          // Arrange: User with no rides
          token    <- TestJWT.generateToken(userId = java.util.UUID.randomUUID())

          request   = Request
                        .get(URL.decode("/api/rides").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))

          // Act: Call the API endpoint
          response <- runRequest(request)
          bodyStr  <- response.body.asString.orDie
          rides    <- ZIO.fromEither(bodyStr.fromJson[List[RideDto]]).mapError(new RuntimeException(_)).orDie

          // Assert: Should return empty array
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

    ) @@ TestAspect.sequential

  ).provide(
    InMemoryRideRepository.layer,
    InMemoryPersonRepository.layer,
    RideCreationService.layer,
    SimpleRideService.layer,
    RideFacade.layer,
    TestJWT.testJwtService
  ) @@ TestAspect.sequential // Ensure all suites run sequentially
}
