package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{RidePoolRepository, InMemoryRidePoolRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.time.Instant
import java.util.UUID

class StubRideService extends RideService:
  def getRideById(rideId: RideId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))

  def createRide(request: CreateRideRequest): IO[RideError, Ride]        = ZIO.fail(
    RideError.RideNotFound(RideId(UUID.randomUUID()))
  )
  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]       = ZIO.succeed(Nil)
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
  def completeRide(rideId: RideId): IO[RideError, Ride]                  = ZIO.fail(RideError.RideNotFound(rideId))

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] = ZIO.fail(
    RideError.RideNotFound(rideId)
  )

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest
  ): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
  def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]             = ZIO.succeed(Map.empty)

  def updateRideStatus(
      rideId: RideId,
      request: UpdateRideStatusRequest,
      userId: PersonId,
      userRole: PersonRole
  ): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
  def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]       = ZIO.succeed(Nil)
  def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]]         = ZIO.succeed(Nil)
  def getClientRides(clientId: PersonId): IO[RideError, List[Ride]]         = ZIO.succeed(Nil)
  def getAllRides: IO[RideError, List[Ride]]                                = ZIO.succeed(Nil)
  def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]    = ZIO.succeed(Nil)

  def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] = ZIO
    .succeed(Nil)
  def getDriverRidesPaginated(driverId: PersonId, offset: Int, limit: Int): IO[RideError, List[Ride]]      = ZIO.succeed(Nil)

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole,
      companyId: Option[CompanyId]
  ): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))

  def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride]                   = ZIO.fail(
    RideError.RideNotFound(rideId)
  )

  def markPayment(
      rideId: RideId,
      paymentStatus: PaymentStatus,
      paymentMethod: Option[PaymentMethod]
  ): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
  def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                     = ZIO.succeed(Nil)
  def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                 = ZIO.succeed(Map.empty)
  def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                             = ZIO.succeed(BigDecimal(0))
  def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                             = ZIO.succeed(BigDecimal(0))
  def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                         = ZIO.succeed(0.0)
  def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]] = ZIO.succeed(Nil)

  def getDriverEarnings(
      driverId: PersonId,
      companyId: CompanyId,
      period: EarningsPeriod,
      anchorDate: java.time.LocalDate
  ): IO[RideError, DriverEarningsReport] = ZIO.succeed(
    DriverEarningsReport(period, Instant.EPOCH, Instant.EPOCH, BigDecimal(0), BigDecimal(0), 0, 0, Nil)
  )

object RidePoolRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId  = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val otherCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000099")
  private val dispatcherId   = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val driverUserId   = UUID.fromString("00000000-0000-0000-0000-000000000002")
  private val clientUserId   = UUID.fromString("00000000-0000-0000-0000-000000000003")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
        issuer = "test-issuer",
        audience = "test-audience",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def generateToken(
      userId: UUID,
      role: PersonRole = PersonRole.Dispatcher,
      companyId: Option[UUID] = Some(taxiCompanyId)
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(userId),
        email = s"$userId@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = companyId.map(CompanyId.apply),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(
      req: Request
  ): ZIO[RidePoolRepository & RideService & AuditService & EventHub & JwtService, Nothing, Response] =
    RidePoolRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makePool(companyId: UUID = taxiCompanyId, status: PoolStatus = PoolStatus.Open): RidePool = RidePool(
    id = RidePoolId.generate(),
    companyId = CompanyId(companyId),
    name = Some("Test Pool"),
    maxPassengers = 4,
    currentPassengers = 0,
    status = status,
    createdBy = PersonId(dispatcherId)
  )

  private val layers =
    RidePoolRepository.inMemory ++
      ZLayer.succeed(new StubRideService) ++
      AuditService.inMemory ++
      EventHub.layer ++
      testJwtLayer

  def spec =
    suite("RidePoolRoutes")(
      suite("POST /api/pools")(
        test("dispatcher creates pool without rides") {
          for {
            token   <- generateToken(dispatcherId)
            body     = """{"name":"Morning Pool","maxPassengers":3,"rideIds":[]}"""
            request  = Request
                         .post(URL.decode("/api/pools").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            pool    <- ZIO.fromEither(bodyStr.fromJson[RidePool]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Created,
            pool.name.contains("Morning Pool"),
            pool.maxPassengers == 3,
            pool.companyId == CompanyId(taxiCompanyId)
          )
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(
                      Request.post(URL.decode("/api/pools").toOption.get, Body.fromString("""{"rideIds":[]}"""))
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 403 for client role") {
          for {
            token  <- generateToken(clientUserId, role = PersonRole.Client)
            request = Request
                        .post(URL.decode("/api/pools").toOption.get, Body.fromString("""{"rideIds":[]}"""))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/pools")(
        test("dispatcher lists pools for own company") {
          for {
            repo    <- ZIO.service[RidePoolRepository]
            _       <- repo.create(makePool())
            _       <- repo.create(makePool(companyId = otherCompanyId))
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/pools").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            list    <- ZIO.fromEither(bodyStr.fromJson[List[RidePool]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, list.length == 1)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/pools").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 403 for client role") {
          for {
            token <- generateToken(clientUserId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/pools").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/pools/open")(
        test("returns only open pools") {
          for {
            repo    <- ZIO.service[RidePoolRepository]
            _       <- repo.create(makePool(status = PoolStatus.Open))
            _       <- repo.create(makePool(status = PoolStatus.Full))
            _       <- repo.create(makePool(status = PoolStatus.Completed))
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/pools/open").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            list    <- ZIO.fromEither(bodyStr.fromJson[List[RidePool]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, list.length == 1, list.head.status == PoolStatus.Open)
        }
      ),
      suite("GET /api/pools/:id")(
        test("dispatcher gets pool details") {
          for {
            repo    <- ZIO.service[RidePoolRepository]
            pool    <- repo.create(makePool())
            token   <- generateToken(dispatcherId)
            resp    <- runRequest(
                         Request
                           .get(URL.decode(s"/api/pools/${pool.id.value}").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Ok, bodyStr.contains("pool"), bodyStr.contains("members"))
        },
        test("driver gets pool details") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool())
            token <- generateToken(driverUserId, role = PersonRole.Driver)
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/${pool.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns error for unknown pool") {
          for {
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/${UUID.randomUUID()}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status != Status.Ok)
        },
        test("returns 403 for client role") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool())
            token <- generateToken(clientUserId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/${pool.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(companyId = otherCompanyId))
            token <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/${pool.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NotFound)
        }
      ),
      suite("POST /api/pools/:id/rides")(
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(companyId = otherCompanyId))
            token <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            body   = s"""{"rideId":"${UUID.randomUUID()}"}"""
            resp  <- runRequest(
                       Request
                         .post(
                           URL.decode(s"/api/pools/${pool.id.value}/rides").toOption.get,
                           Body.fromString(body)
                         )
                         .addHeader(Header.Authorization.Bearer(token))
                     )
            // Pool must be untouched by the cross-tenant caller.
            after <- repo.findById(pool.id)
          } yield assertTrue(
            resp.status == Status.NotFound,
            after.exists(_.currentPassengers == 0)
          )
        }
      ),
      suite("PUT /api/pools/:id/assign")(
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(companyId = otherCompanyId))
            token <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            body   = s"""{"driverId":"$driverUserId"}"""
            resp  <- runRequest(
                       Request
                         .put(
                           URL.decode(s"/api/pools/${pool.id.value}/assign").toOption.get,
                           Body.fromString(body)
                         )
                         .addHeader(Header.Authorization.Bearer(token))
                     )
            // Pool must not get a driver assigned by the cross-tenant caller.
            after <- repo.findById(pool.id)
          } yield assertTrue(
            resp.status == Status.NotFound,
            after.exists(_.driverId.isEmpty)
          )
        }
      ),
      suite("PUT /api/pools/:id/status")(
        test("dispatcher updates pool status") {
          for {
            repo    <- ZIO.service[RidePoolRepository]
            pool    <- repo.create(makePool())
            token   <- generateToken(dispatcherId)
            body     = """{"status":"InProgress"}"""
            request  = Request
                         .put(URL.decode(s"/api/pools/${pool.id.value}/status").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            updated <- ZIO.fromEither(bodyStr.fromJson[RidePool]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, updated.status == PoolStatus.InProgress)
        },
        test("driver can update pool status") {
          for {
            repo   <- ZIO.service[RidePoolRepository]
            pool   <- repo.create(makePool(status = PoolStatus.InProgress))
            token  <- generateToken(driverUserId, role = PersonRole.Driver)
            body    = """{"status":"Completed"}"""
            request = Request
                        .put(URL.decode(s"/api/pools/${pool.id.value}/status").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns 403 for client role") {
          for {
            repo   <- ZIO.service[RidePoolRepository]
            pool   <- repo.create(makePool())
            token  <- generateToken(clientUserId, role = PersonRole.Client)
            body    = """{"status":"InProgress"}"""
            request = Request
                        .put(URL.decode(s"/api/pools/${pool.id.value}/status").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("returns 500 for invalid status value") {
          for {
            repo   <- ZIO.service[RidePoolRepository]
            pool   <- repo.create(makePool())
            token  <- generateToken(dispatcherId)
            body    = """{"status":"InvalidStatus"}"""
            request = Request
                        .put(URL.decode(s"/api/pools/${pool.id.value}/status").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.InternalServerError)
        },
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo   <- ZIO.service[RidePoolRepository]
            pool   <- repo.create(makePool(companyId = otherCompanyId, status = PoolStatus.Open))
            token  <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            body    = """{"status":"InProgress"}"""
            request = Request
                        .put(URL.decode(s"/api/pools/${pool.id.value}/status").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
            // Pool status must be untouched by the cross-tenant caller.
            after  <- repo.findById(pool.id)
          } yield assertTrue(
            resp.status == Status.NotFound,
            after.exists(_.status == PoolStatus.Open)
          )
        }
      ),
      suite("GET /api/pools/ride/:rideId")(
        test("returns pool when ride is in a pool") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool())
            rideId = RideId(UUID.randomUUID())
            member = RidePoolMember(
                       id = RidePoolMemberId.generate(),
                       poolId = pool.id,
                       rideId = rideId,
                       clientId = PersonId(clientUserId),
                       pickupOrder = 0
                     )
            _     <- repo.addMember(member)
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/ride/${rideId.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("returns 404 when ride is not in any pool") {
          for {
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/ride/${UUID.randomUUID()}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(companyId = otherCompanyId))
            rideId = RideId(UUID.randomUUID())
            member = RidePoolMember(
                       id = RidePoolMemberId.generate(),
                       poolId = pool.id,
                       rideId = rideId,
                       clientId = PersonId(clientUserId),
                       pickupOrder = 0
                     )
            _     <- repo.addMember(member)
            token <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            resp  <- runRequest(
                       Request
                         .get(URL.decode(s"/api/pools/ride/${rideId.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NotFound)
        }
      ),
      suite("DELETE /api/pools/:id/rides/:rideId")(
        test("dispatcher removes ride from pool") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(status = PoolStatus.Open))
            rideId = RideId(UUID.randomUUID())
            member = RidePoolMember(
                       id = RidePoolMemberId.generate(),
                       poolId = pool.id,
                       rideId = rideId,
                       clientId = PersonId(clientUserId),
                       pickupOrder = 0
                     )
            _     <- repo.addMember(member)
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .delete(URL.decode(s"/api/pools/${pool.id.value}/rides/${rideId.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.NoContent)
        },
        test("returns error when ride not in pool") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool())
            token <- generateToken(dispatcherId)
            resp  <- runRequest(
                       Request
                         .delete(
                           URL.decode(s"/api/pools/${pool.id.value}/rides/${UUID.randomUUID()}").toOption.get
                         )
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status != Status.NoContent)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(
                      Request.delete(
                        URL.decode(s"/api/pools/${UUID.randomUUID()}/rides/${UUID.randomUUID()}").toOption.get
                      )
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 404 when pool belongs to another company (tenant isolation)") {
          for {
            repo  <- ZIO.service[RidePoolRepository]
            pool  <- repo.create(makePool(companyId = otherCompanyId, status = PoolStatus.Open))
            rideId = RideId(UUID.randomUUID())
            member = RidePoolMember(
                       id = RidePoolMemberId.generate(),
                       poolId = pool.id,
                       rideId = rideId,
                       clientId = PersonId(clientUserId),
                       pickupOrder = 0
                     )
            _     <- repo.addMember(member)
            token <- generateToken(dispatcherId, companyId = Some(taxiCompanyId))
            resp  <- runRequest(
                       Request
                         .delete(URL.decode(s"/api/pools/${pool.id.value}/rides/${rideId.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
            // Member must still be present: cross-tenant caller cannot remove it.
            members <- repo.findMembersByPoolId(pool.id)
          } yield assertTrue(
            resp.status == Status.NotFound,
            members.exists(_.rideId == rideId)
          )
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
