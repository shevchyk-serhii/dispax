package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideEstimateService,
  RideService
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.RideApi
import com.shevchyk.ride.repository.{InMemoryTariffRepository, RideRatingRepository, TariffRepository}
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * CRITICAL — Regression tests for tenant-isolation on the assign-driver / reassign-driver HTTP endpoints.
 *
 * Bug context: before the fix, `assignDriverServer` and `reassignDriverServer` did not verify that the target ride
 * belonged to the dispatcher's company. A dispatcher of company A could mutate a ride owned by company B.
 *
 * The fix adds: companyId <- requireCompanyId(user.companyId) existing <- service.getRideById(parsedRideId) _ <-
 * ZIO.fail(RideError.RideNotFound(parsedRideId)).when(existing.companyId != companyId)
 *
 * These tests exercise the full Tapir server endpoint via ZioHttpInterpreter (no network I/O, no Testcontainers):
 *   1. Happy path: dispatcher of company A assigns a driver to a ride of company A → 200 2. [CRITICAL] Cross-tenant
 *      assign: dispatcher of company A targets a ride of company B → 404 3. [CRITICAL] Cross-tenant reassign:
 *      dispatcher of company A targets a ride of company B → 404 4. service.assignDriver is NOT called on isolation
 *      failure (captured via Ref) 5. service.reassignDriver is NOT called on isolation failure (captured via Ref) 6.
 *      Non-dispatcher role (driver) → 403
 */
object RideAssignIsolationSpec extends ZIOSpecDefault:

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
  // Ride factory
  // ---------------------------------------------------------------------------

  /**
   * A Requested ride belonging to `companyId`.
   */
  private def makeRequestedRide(id: RideId, companyId: CompanyId): Ride = Ride(
    id = id,
    clientId = clientAId,
    creatorId = clientAId,
    companyId = companyId,
    status = RideStatus.Requested,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  /**
   * A Assigned ride (needed for reassign happy path) belonging to `companyId`.
   */
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
  //
  // - rides: rides the stub "knows about" (keyed by id)
  // - assignedRef: set to true when assignDriver is called (used to detect forbidden calls)
  // - reassignedRef: set to true when reassignDriver is called
  // ---------------------------------------------------------------------------

  private def makeStubRideService(
      rides: Map[RideId, Ride],
      assignedRef: Ref[Boolean],
      reassignedRef: Ref[Boolean]
  ): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImplemented = ZIO.die(new NotImplementedError("RideAssignIsolationSpec stub"))

      def getRideById(rideId: RideId): IO[RideError, Ride] =
        rides.get(rideId) match
          case Some(r) => ZIO.succeed(r)
          case None    => ZIO.fail(RideError.RideNotFound(rideId))

      def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
        assignedRef.set(true) *> {
          rides.get(rideId) match
            case Some(r) => ZIO.succeed(r.copy(driverId = Some(driverId), status = RideStatus.Assigned))
            case None    => ZIO.fail(RideError.RideNotFound(rideId))
        }

      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean
      ): IO[RideError, Ride] =
        reassignedRef.set(true) *> {
          rides.get(rideId) match
            case Some(r) => ZIO.succeed(r.copy(driverId = Some(newDriverId)))
            case None    => ZIO.fail(RideError.RideNotFound(rideId))
        }

      // All other methods die (they must not be reached in these tests)
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
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                      = notImplemented
      def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]      =
        notImplemented
      def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                  = notImplemented
      def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                  = notImplemented
      def getAllRides: IO[RideError, List[Ride]]                                                               = notImplemented
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                   = ZIO.succeed(Nil)
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] =
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
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                             = notImplemented
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                         = ZIO.succeed(Map.empty)
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                     = ZIO.succeed(BigDecimal(0))
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                     = ZIO.succeed(BigDecimal(0))
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                 = ZIO.succeed(0.0)
      def getDailyStats(
          companyId: CompanyId,
          days: Int
      ): IO[RideError, List[(String, Int, Int, Int)]] = ZIO.succeed(Nil)
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImplemented
  )

  // ---------------------------------------------------------------------------
  // No-op stubs for the remaining RideEnv dependencies
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
      def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                  = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                             = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]]                                 = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                        = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]        = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                  = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                     = ZIO.succeed(None)
      def setAvatar(id: PersonId, bytes: Array[Byte], contentType: String): Task[Unit]     = ZIO.unit
      def deleteAvatar(id: PersonId): Task[Unit]                                           = ZIO.unit
  )

  private val stubClientAddressService: ZLayer[Any, Nothing, ClientAddressService] = ZLayer.succeed(
    new ClientAddressService:
      def getAddresses(clientId: PersonId)                                                                          = ZIO.succeed(Nil)
      def saveAddress(clientId: PersonId, req: com.shevchyk.ride.domain.SaveClientAddressRequest)                   = ZIO.die(
        new NotImplementedError("stub")
      )
      def updateAddress(
          id: com.shevchyk.ride.domain.ClientAddressId,
          clientId: PersonId,
          req: com.shevchyk.ride.domain.UpdateClientAddressRequest
      ) = ZIO.succeed(None)
      def recordUsage(clientId: PersonId, address: String, label: String, lat: Option[Double], lng: Option[Double]) =
        ZIO.unit
      def deleteAddress(id: com.shevchyk.ride.domain.ClientAddressId, clientId: PersonId)                           = ZIO.succeed(false)
  )

  private val stubClientLocationService: ZLayer[Any, Nothing, ClientLocationService] = ZLayer.succeed(
    new ClientLocationService:
      def updateClientLocation(
          rideId: RideId,
          clientId: PersonId,
          latitude: Double,
          longitude: Double
      ): IO[RideError, Unit] = ZIO.die(new NotImplementedError("stub"))
      def getRideLocations(rideId: RideId): IO[RideError, com.shevchyk.ride.application.service.RideLocationsResponse] =
        ZIO.die(new NotImplementedError("stub"))
  )

  private val stubAirportCheckpointService: ZLayer[Any, Nothing, AirportCheckpointService] = ZLayer.succeed(
    new AirportCheckpointService:
      def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]]                = ZIO.succeed(
        None
      )
      def markCheckpoint(ride: Ride, requestedCheckpoint: AirportCheckpoint, markedBy: PersonId): IO[RideError, Unit] =
        ZIO.die(new NotImplementedError("stub"))
  )

  private val stubChatService: ZLayer[Any, Nothing, ChatService] = ZLayer.succeed(
    new ChatService:
      def sendMessage(rideId: RideId, senderId: PersonId, message: String): Task[ChatMessage] = ZIO.die(
        new NotImplementedError("stub")
      )
      def getMessages(rideId: RideId): Task[List[ChatMessage]]                                = ZIO.succeed(Nil)
  )

  private val stubRideRatingRepo: ZLayer[Any, Nothing, RideRatingRepository] = RideRatingRepository.inMemory

  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository] = ZLayer.succeed(
    new InMemoryTariffRepository()
  )

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  // ---------------------------------------------------------------------------
  // Layer builder: builds a full RideEnv with the given ride-map and tracking Refs
  // ---------------------------------------------------------------------------

  private def buildLayers(
      rides: Map[RideId, Ride],
      assignedRef: Ref[Boolean],
      reassignedRef: Ref[Boolean]
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      makeStubRideService(rides, assignedRef, reassignedRef) ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      stubRideRatingRepo ++
      stubPersonRepo ++
      stubTariffRepo ++
      stubRideEstimateService

  // ---------------------------------------------------------------------------
  // HTTP runner
  // ---------------------------------------------------------------------------

  private def run(req: Request, layers: ZLayer[Any, Throwable, RideApi.RideEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(RideApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(layers)

  // ---------------------------------------------------------------------------
  // JSON body helpers
  // ---------------------------------------------------------------------------

  private def assignBody(driverId: PersonId): Body = Body.fromString(s"""{"driverId":"${driverId.value}"}""")

  private def reassignBody(driverId: PersonId): Body = Body.fromString(
    s"""{"driverId":"${driverId.value}","overrideScheduleConflict":false}"""
  )

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("RideApi — assign/reassign-driver endpoint-level tenant-isolation [CRITICAL regression]")(
      // ── Happy path: dispatcher A assigns driver to ride A ──────────────────
      test("happy path: dispatcher of company A assigns driver to ride A → 200") {
        val rideA = makeRequestedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideAId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
        } yield assertTrue(resp.status == Status.Ok)
      },

      // ── CRITICAL: cross-tenant assign must be blocked ──────────────────────
      test("[CRITICAL] dispatcher of company A targets ride owned by company B → 404 (not 200)") {
        // Ride B belongs to company B; dispatcher JWT is for company A
        val rideB = makeRequestedRide(rideBId, companyBId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideBId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },

      // ── CRITICAL: service.assignDriver must NOT be invoked on isolation failure
      test("[CRITICAL] service.assignDriver is NOT called when cross-tenant isolation check fails") {
        val rideB = makeRequestedRide(rideBId, companyBId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideBId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          _             <- run(req, layers)
          wasCalled     <- assignedRef.get
        } yield assertTrue(!wasCalled)
      },

      // ── CRITICAL: cross-tenant reassign must be blocked ────────────────────
      test("[CRITICAL] dispatcher of company A targets REASSIGN on ride owned by company B → 404") {
        val rideB = makeAssignedRide(rideBId, companyBId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideBId.value}/reassign-driver").toOption.get,
                               reassignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },

      // ── CRITICAL: service.reassignDriver must NOT be invoked on isolation failure
      test("[CRITICAL] service.reassignDriver is NOT called when cross-tenant isolation check fails") {
        val rideB = makeAssignedRide(rideBId, companyBId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideBId -> rideB), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideBId.value}/reassign-driver").toOption.get,
                               reassignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          _             <- run(req, layers)
          wasCalled     <- reassignedRef.get
        } yield assertTrue(!wasCalled)
      },

      // ── Role gate: non-dispatcher role → 403 ───────────────────────────────
      test("driver-role JWT targeting own-company ride → 403 (only DISPATCHER may assign)") {
        val rideA = makeRequestedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Driver, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideAId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
        } yield assertTrue(resp.status == Status.Forbidden)
      },

      // ── Unauthenticated request → 401 ──────────────────────────────────────
      test("unauthenticated request to assign-driver → 401") {
        val rideA = makeRequestedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideAId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
        } yield assertTrue(resp.status == Status.Unauthorized)
      }
    ) @@ TestAspect.sequential
