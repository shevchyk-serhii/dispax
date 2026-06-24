package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{BlacklistRepository, EmergencyReassignmentRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * CRITICAL — Regression tests for tenant-isolation on the emergency-reassignment HTTP endpoint.
 *
 * Bug context: before the fix, `EmergencyApi.reassignServer` called `getRideById` + `reassignDriver` without verifying
 * that the target ride belonged to the dispatcher's company. A dispatcher of company A could initiate an emergency
 * reassignment on a ride owned by company B.
 *
 * The fix adds, right after `getRideById`:
 *   - companyId <- requireCompanyId(user.companyId)
 *   - ZIO.fail(NotFound).when(ride.companyId != companyId)
 *
 * These tests exercise the full Tapir server endpoint via ZioHttpInterpreter (no network I/O, no Testcontainers):
 *   1. [CRITICAL] Cross-tenant: dispatcher of company A targets a ride of company B → 404 (not 201) 2. Happy path:
 *      dispatcher of company A initiates reassignment on a ride of company A → 201 3. [CRITICAL] service.reassignDriver
 *      is NOT called on isolation failure (captured via Ref)
 */
object EmergencyReassignIsolationSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // Fixture IDs
  // ---------------------------------------------------------------------------

  private val companyAId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId: CompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))

  private val clientAId: PersonId = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverAId: PersonId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideAId: RideId     = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))
  private val rideBId: RideId     = RideId(UUID.fromString("000000BB-BBBB-0000-0000-000000000001"))

  // ---------------------------------------------------------------------------
  // JWT helpers
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
  // Ride factory — an Assigned ride (required by the emergency-reassign rule)
  // ---------------------------------------------------------------------------

  private def makeAssignedRide(id: RideId, companyId: CompanyId): Ride = Ride(
    id = id,
    clientId = clientAId,
    creatorId = clientAId,
    companyId = companyId,
    driverId = Some(driverAId),
    status = RideStatus.Assigned,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  // ---------------------------------------------------------------------------
  // Controllable stub RideService
  //   - reassignedRef: set to true whenever reassignDriver is invoked
  // ---------------------------------------------------------------------------

  private def makeStubRideService(
      rides: Map[RideId, Ride],
      reassignedRef: Ref[Boolean]
  ): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImplemented = ZIO.die(new NotImplementedError("EmergencyReassignIsolationSpec stub"))

      def getRideById(rideId: RideId): IO[RideError, Ride] =
        rides.get(rideId) match
          case Some(r) => ZIO.succeed(r)
          case None    => ZIO.fail(RideError.RideNotFound(rideId))

      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean = false
      ): IO[RideError, Ride] =
        reassignedRef.set(true) *> {
          rides.get(rideId) match
            case Some(r) => ZIO.succeed(r.copy(driverId = Some(newDriverId)))
            case None    => ZIO.fail(RideError.RideNotFound(rideId))
        }

      def assignDriver(
          rideId: RideId,
          driverId: PersonId,
          overrideScheduleConflict: Boolean = false
      ): IO[RideError, Ride] = notImplemented

      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                                     = notImplemented
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                                = notImplemented
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                          = notImplemented
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                           = notImplemented
      def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                        = notImplemented
      def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride]                         = notImplemented
      def cancelRide(rideId: RideId, userId: PersonId, role: PersonRole): IO[RideError, Ride]                         = notImplemented
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          role: PersonRole,
          req: CancelRideRequest,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImplemented
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                                 = notImplemented
      def handOffToExternal(
          rideId: RideId,
          callerCompanyId: CompanyId,
          callerId: PersonId,
          req: HandOffRequest
      ): IO[RideError, Ride] = notImplemented
      def createPartnerCompany(companyId: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany] =
        notImplemented
      def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]]                             = notImplemented
      def createExternalDriver(companyId: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver] =
        notImplemented
      def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]]                              = notImplemented
      def updateRideStatus(
          rideId: RideId,
          req: UpdateRideStatusRequest,
          userId: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImplemented
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                             = notImplemented
      def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]             =
        notImplemented
      def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImplemented
      def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImplemented
      def getAllRides: IO[RideError, List[Ride]]                                                                      = notImplemented
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = notImplemented
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]        =
        notImplemented
      def getDriverRidesPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): IO[RideError, List[Ride]] = notImplemented
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImplemented
      def markPayment(
          rideId: RideId,
          ps: PaymentStatus,
          pm: Option[PaymentMethod]
      ): IO[RideError, Ride] = notImplemented
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                    = notImplemented
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                = notImplemented
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImplemented
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImplemented
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                        = notImplemented
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
      def setRidePrice(
          rideId: RideId,
          price: Double,
          userId: PersonId,
          userRole: PersonRole,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImplemented
      def getRidesByDrivers(
          driverIds: List[PersonId],
          from: Option[String],
          to: Option[String],
          companyId: CompanyId
      ): IO[RideError, List[Ride]] = notImplemented
  )

  // ---------------------------------------------------------------------------
  // No-op stub PersonRepository
  // ---------------------------------------------------------------------------

  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.none
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.none
      def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.none
      def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]                   = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                          = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]]                                                                      = ZIO.succeed(Nil)
      def update(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                                   = ZIO.unit
      def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                                    = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  )

  // ---------------------------------------------------------------------------
  // Layer builder
  // ---------------------------------------------------------------------------

  private def buildLayers(
      rides: Map[RideId, Ride],
      reassignedRef: Ref[Boolean]
  ): ZLayer[Any, Throwable, EmergencyApi.EmergencyEnv] =
    testJwtService ++
      EmergencyReassignmentRepository.inMemory ++
      BlacklistRepository.inMemory ++
      makeStubRideService(rides, reassignedRef) ++
      stubPersonRepo ++
      AuditService.inMemory ++
      EventHub.layer

  // ---------------------------------------------------------------------------
  // HTTP runner
  // ---------------------------------------------------------------------------

  private def run(
      req: Request,
      layers: ZLayer[Any, Throwable, EmergencyApi.EmergencyEnv]
  ): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(EmergencyApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(layers)

  // ---------------------------------------------------------------------------
  // JSON body helper (no newDriverId → reassignment recorded as PENDING)
  // ---------------------------------------------------------------------------

  private def reassignBody(rideId: RideId): Body = Body.fromString(
    s"""{"rideId":"${rideId.value}","reason":"DriverIllness"}"""
  )

  private def post(token: String, body: Body): Request = Request
    .post(URL.decode("/api/emergency/reassign").toOption.get, body)
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("EmergencyApi — reassign endpoint-level tenant-isolation [CRITICAL regression]")(
      // ── CRITICAL: cross-tenant emergency reassign must be blocked ──────────
      test("[CRITICAL] dispatcher of company A targets emergency-reassign on ride owned by company B → 404") {
        val rideB = makeAssignedRide(rideBId, companyBId)
        for {
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          resp          <- run(post(token, reassignBody(rideBId)), layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },

      // ── CRITICAL: service.reassignDriver must NOT be invoked on isolation failure
      test("[CRITICAL] cross-tenant target does not even reach the ride service") {
        val rideB = makeAssignedRide(rideBId, companyBId)
        for {
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          _             <- run(post(token, reassignBody(rideBId)), layers)
          wasCalled     <- reassignedRef.get
        } yield assertTrue(!wasCalled)
      },

      // ── Happy path: dispatcher A on own-company ride → 201 ─────────────────
      test("dispatcher of company A initiates emergency-reassign on a ride of company A → 201") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          resp          <- run(post(token, reassignBody(rideAId)), layers)
        } yield assertTrue(resp.status == Status.Created)
      }
    ) @@ TestAspect.sequential
