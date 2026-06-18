package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{CompanySettingsRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.ExportApi
import com.shevchyk.ride.repository.ExpenseRepository
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * CRITICAL — Negative tenant-isolation HTTP tests for GET /api/export/datev/extf.
 *
 * Exercises the Tapir server endpoint via ZioHttpInterpreter (no network I/O, no Testcontainers). Verifies:
 *   - a company-B dispatcher JWT can retrieve company-B data (happy path)
 *   - company-A data is NOT present in a company-B response (isolation)
 *   - unauthenticated requests are rejected with 401
 *   - driver-role JWTs are rejected with 403 (only DISPATCHER/ADMIN may export)
 *
 * Invariant: every touched endpoint must have an explicit negative test on CompanyId-scoped data access.
 */
object ExportApiIsolationSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // IDs
  // ---------------------------------------------------------------------------

  private val companyAId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId: CompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val clientAId: PersonId   = PersonId(UUID.fromString("000000AA-0000-0000-0000-000000000001"))

  // ---------------------------------------------------------------------------
  // JWT helpers (mirror SuperAdminApiSpec pattern)
  // ---------------------------------------------------------------------------

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private def generateToken(role: PersonRole, companyId: CompanyId): ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = s"${role.toString.toLowerCase}@test.de",
          name = s"${role.toString} User",
          role = role,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )

  // ---------------------------------------------------------------------------
  // Test ride factory
  // ---------------------------------------------------------------------------

  private def makeCompletedRide(companyId: CompanyId, amount: BigDecimal, clientId: PersonId): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    status = RideStatus.Completed,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.parse("2025-05-10T10:00:00Z"),
    requestTime = Instant.parse("2025-05-10T09:00:00Z"),
    endTime = Some(Instant.parse("2025-05-10T12:00:00Z")),
    estimatedPrice = Some(amount),
    finalPrice = None,
    paymentMethod = Some(PaymentMethod.Cash)
  )

  // ---------------------------------------------------------------------------
  // Stub RideService — only getRidesByCompany is wired (uses CompanyId isolation)
  // ---------------------------------------------------------------------------

  private def makeStubRideService(rides: List[Ride]): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImplemented = ZIO.die(new NotImplementedError("ExportApiIsolationSpec stub"))

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                     = notImplemented
      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                              = notImplemented
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                         = notImplemented
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                   = notImplemented
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                    = notImplemented
      def cancelRide(rideId: RideId, userId: PersonId, role: PersonRole): IO[RideError, Ride]                  = notImplemented
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          role: PersonRole,
          req: CancelRideRequest
      ): IO[RideError, Ride] = notImplemented
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                          = notImplemented
      def updateRideStatus(
          rideId: RideId,
          req: UpdateRideStatusRequest,
          userId: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImplemented
      def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                = notImplemented
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                      = notImplemented
      def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]]                                        = notImplemented
      def getClientRides(clientId: PersonId): IO[RideError, List[Ride]]                                        = notImplemented
      def getAllRides: IO[RideError, List[Ride]]                                                               = notImplemented
      // Core isolation: only rides for the requested companyId are returned
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                   = ZIO.succeed(
        rides.filter(_.companyId == companyId)
      )
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] =
        notImplemented
      def getDriverRidesPaginated(driverId: PersonId, offset: Int, limit: Int): IO[RideError, List[Ride]]      =
        notImplemented
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImplemented
      def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride]                           = notImplemented
      def markPayment(
          rideId: RideId,
          ps: PaymentStatus,
          pm: Option[PaymentMethod]
      ): IO[RideError, Ride] = notImplemented
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                             = notImplemented
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                         = notImplemented
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                     = notImplemented
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                     = notImplemented
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                 = notImplemented
      def getDailyStats(
          companyId: CompanyId,
          days: Int
      ): IO[RideError, List[(String, Int, Int, Int)]] = notImplemented
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImplemented
  )

  // ---------------------------------------------------------------------------
  // Stub ExpenseRepository — returns no expenses (not under test here)
  // ---------------------------------------------------------------------------

  private val stubExpenseRepo: ZLayer[Any, Nothing, ExpenseRepository] = ZLayer.succeed(
    new ExpenseRepository:
      def create(expense: Expense): Task[Expense]                                                             = ZIO.succeed(expense)
      def findById(id: ExpenseId): Task[Option[Expense]]                                                      = ZIO.succeed(None)
      def findByDriverId(driverId: PersonId): Task[List[Expense]]                                             = ZIO.succeed(Nil)
      def findByRideId(rideId: RideId): Task[List[Expense]]                                                   = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Expense]]                                          = ZIO.succeed(Nil)
      def delete(id: ExpenseId, companyId: CompanyId): Task[Boolean]                                          = ZIO.succeed(false)
      def sumByDriver(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant): Task[BigDecimal] = ZIO
        .succeed(BigDecimal(0))
  )

  // ---------------------------------------------------------------------------
  // Stub PersonRepository — returns no persons (client names resolve to "Unbekannt")
  // ---------------------------------------------------------------------------

  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                             = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                     = ZIO.succeed(None)
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]     = ZIO.succeed(None)
      def findByEmail(email: String): Task[Option[Person]]                                 = ZIO.succeed(None)
      def findByRole(role: PersonRole): Task[List[Person]]                                 = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]]                                                    = ZIO.succeed(Nil)
      def update(person: Person): Task[Person]                                             = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                 = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                             = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]]                                 = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                        = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]        = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                  = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                     = ZIO.succeed(None)
      def setAvatar(id: PersonId, bytes: Array[Byte], contentType: String): Task[Unit]     = ZIO.unit
      def deleteAvatar(id: PersonId): Task[Unit]                                           = ZIO.unit
  )

  // ---------------------------------------------------------------------------
  // Route runner
  // ---------------------------------------------------------------------------

  private def run(req: Request): ZIO[ExportApi.ExportEnv, Nothing, Response] = ZioHttpInterpreter()
    .toHttp(ExportApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // ---------------------------------------------------------------------------
  // Build test layers (company A + company B rides pre-seeded)
  // ---------------------------------------------------------------------------

  private def buildLayers(rides: List[Ride]): ZLayer[Any, Throwable, ExportApi.ExportEnv] =
    testJwtService ++
      makeStubRideService(rides) ++
      stubExpenseRepo ++
      stubPersonRepo ++
      CompanySettingsRepository.inMemory

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("ExportApi — endpoint-level tenant-isolation tests [CRITICAL]")(
      test("company-B dispatcher JWT: response contains company-B rides only, not company-A rides") {
        // company A has a completed ride worth 100.00 EUR (May 2025)
        // company B has a completed ride worth 999.99 EUR (May 2025)
        // A dispatcher authenticated for company B must see 999,99 but NOT 100,00
        val rideA  = makeCompletedRide(companyAId, BigDecimal("100.00"), clientAId)
        val rideB  = makeCompletedRide(companyBId, BigDecimal("999.99"), clientAId)
        val layers = buildLayers(List(rideA, rideB))

        for {
          token   <- generateToken(PersonRole.Dispatcher, companyBId).provideLayer(testJwtService)
          req      = Request
                       .get(URL.decode("/api/export/datev/extf?month=2025-05").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- run(req).provideLayer(layers)
          bodyStr <- resp.body.asString
        } yield assertTrue(
          // Endpoint must respond successfully
          resp.status == zio.http.Status.Ok,
          // Company B's ride amount appears — dispatcher can see their own data
          bodyStr.contains("999,99"),
          // Company A's ride amount must be absent — tenant isolation enforced
          !bodyStr.contains("100,00")
        )
      },
      test("unauthenticated request → 401") {
        val layers = buildLayers(Nil)
        val req    = Request.get(URL.decode("/api/export/datev/extf").toOption.get)
        run(req).map(resp => assertTrue(resp.status == zio.http.Status.Unauthorized)).provideLayer(layers)
      },
      test("driver-role JWT → 403 (only DISPATCHER/ADMIN may export)") {
        val layers = buildLayers(Nil)
        for {
          token <- generateToken(PersonRole.Driver, companyBId).provideLayer(testJwtService)
          req    = Request
                     .get(URL.decode("/api/export/datev/extf").toOption.get)
                     .addHeader(Header.Authorization.Bearer(token))
          resp  <- run(req).provideLayer(layers)
        } yield assertTrue(resp.status == zio.http.Status.Forbidden)
      }
    ) @@ TestAspect.sequential
