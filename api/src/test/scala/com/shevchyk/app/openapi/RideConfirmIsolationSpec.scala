package com.shevchyk.app.openapi

import com.shevchyk.core.application.EventHub

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.config.AirportArrivalTimingConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  AirportTimingService,
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
 * CRITICAL — Endpoint-level tenant-isolation tests for the new `PUT /api/rides/{id}/confirm` and `PUT
 * /api/rides/{id}/reject` endpoints.
 *
 * These endpoints are DRIVER-only (role gate). The suite verifies:
 *   1. Happy path: driver of company A confirms their own company-A ride → 200 2. [CRITICAL] Cross-tenant confirm:
 *      driver of company B targets a company-A ride → 404 3. [CRITICAL] service.confirmRide is NOT called when company
 *      isolation fails 4. Happy path: driver of company A rejects their own company-A ride → 200 5. [CRITICAL]
 *      Cross-tenant reject: driver of company B targets a company-A ride → 404 6. [CRITICAL] service.rejectRide is NOT
 *      called when company isolation fails 7. Non-DRIVER role (Dispatcher) targeting confirm endpoint → 403 8.
 *      Unauthenticated confirm request → 401
 */
object RideConfirmIsolationSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // Fixture IDs
  // ---------------------------------------------------------------------------

  private val companyAId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId: CompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))

  private val clientAId: PersonId = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverAId: PersonId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideAId: RideId     = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  // ---------------------------------------------------------------------------
  // JWT helpers  (identical pattern to RideAssignIsolationSpec)
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
  // Ride factories
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
  // ---------------------------------------------------------------------------

  private def makeStubRideService(
      rides: Map[RideId, Ride],
      confirmCalledRef: Ref[Boolean],
      rejectCalledRef: Ref[Boolean]
  ): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImplemented = ZIO.die(new NotImplementedError("RideConfirmIsolationSpec stub"))

      def getRideById(rideId: RideId): IO[RideError, Ride] =
        rides.get(rideId) match
          case Some(r) => ZIO.succeed(r)
          case None    => ZIO.fail(RideError.RideNotFound(rideId))

      def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]] = notImplemented

      def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
        confirmCalledRef.set(true) *> {
          rides.get(rideId) match
            case Some(r) => ZIO.succeed(r.copy(status = RideStatus.Confirmed))
            case None    => ZIO.fail(RideError.RideNotFound(rideId))
        }

      def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride] =
        rejectCalledRef.set(true) *> {
          rides.get(rideId) match
            case Some(r) =>
              ZIO.succeed(r.copy(status = RideStatus.Requested, driverId = None, rejectionReason = Some(reason)))
            case None    => ZIO.fail(RideError.RideNotFound(rideId))
        }

      def assignDriver(rideId: RideId, driverId: PersonId, overrideScheduleConflict: Boolean): IO[RideError, Ride]    =
        notImplemented
      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean
      ): IO[RideError, Ride] = notImplemented
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
      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                                     = notImplemented
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                                = notImplemented
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                          = notImplemented
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                           = notImplemented
      def cancelRide(rideId: RideId, userId: PersonId, role: PersonRole): IO[RideError, Ride]                         = notImplemented
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          role: PersonRole,
          req: CancelRideRequest,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImplemented
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                                 = notImplemented
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
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = ZIO.succeed(Nil)
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
      def markPayment(rideId: RideId, ps: PaymentStatus, pm: Option[PaymentMethod]): IO[RideError, Ride]              =
        notImplemented
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                    = notImplemented
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                = ZIO.succeed(Map.empty)
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                        = ZIO.succeed(0.0)
      def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]                = ZIO.succeed(
        Nil
      )
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImplemented
  )

  // ---------------------------------------------------------------------------
  // No-op stubs for the rest of RideEnv
  // ---------------------------------------------------------------------------

  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(p: Person): Task[Person]                                                 = ZIO.succeed(p)
      def findById(id: PersonId): Task[Option[Person]]                                    = ZIO.none
      def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]          = ZIO.none
      def findByEmail(email: String): Task[Option[Person]]                                = ZIO.none
      def findByRole(role: PersonRole): Task[List[Person]]                                = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]]      = ZIO.succeed(Nil)
      def findByCompanyId(cid: CompanyId): Task[List[Person]]                             = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def update(p: Person): Task[Person]                                                 = ZIO.succeed(p)
      def delete(id: PersonId): Task[Unit]                                                = ZIO.unit
      def deleteInCompany(id: PersonId, cid: CompanyId): Task[Unit]                       = ZIO.unit
      def findByStatus(s: UserStatus): Task[List[Person]]                                 = ZIO.succeed(Nil)
      def searchByQuery(q: String): Task[List[Person]]                                    = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                       = ZIO.unit
      def findByClientCompany(ccid: ClientCompanyId): Task[List[Person]]                  = ZIO.succeed(Nil)
      def upsertDriverRow(id: PersonId): Task[Unit]                                       = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                    = ZIO.none
      def setAvatar(id: PersonId, cid: CompanyId, b: Array[Byte], ct: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, cid: CompanyId): Task[Unit]                          = ZIO.unit
  )

  private def nopeDie(m: String) = ZIO.die(new NotImplementedError(s"stub: $m"))

  private val stubClientAddressService: ZLayer[Any, Nothing, ClientAddressService] = ZLayer.succeed(
    new ClientAddressService:
      def getAddresses(clientId: PersonId)                                                                          = ZIO.succeed(Nil)
      def saveAddress(clientId: PersonId, req: com.shevchyk.ride.domain.SaveClientAddressRequest)                   = nopeDie(
        "saveAddress"
      )
      def updateAddress(
          id: com.shevchyk.ride.domain.ClientAddressId,
          clientId: PersonId,
          req: com.shevchyk.ride.domain.UpdateClientAddressRequest
      ) = ZIO.none
      def recordUsage(clientId: PersonId, address: String, label: String, lat: Option[Double], lng: Option[Double]) =
        ZIO.unit
      def deleteAddress(id: com.shevchyk.ride.domain.ClientAddressId, clientId: PersonId)                           = ZIO.succeed(false)
  )

  private val stubClientLocationService: ZLayer[Any, Nothing, ClientLocationService] = ZLayer.succeed(
    new ClientLocationService:
      def updateClientLocation(rideId: RideId, clientId: PersonId, lat: Double, lng: Double): IO[RideError, Unit]      =
        nopeDie("updateClientLocation")
      def getRideLocations(rideId: RideId): IO[RideError, com.shevchyk.ride.application.service.RideLocationsResponse] =
        nopeDie("getRideLocations")
  )

  private val stubAirportCheckpointService: ZLayer[Any, Nothing, AirportCheckpointService] = ZLayer.succeed(
    new AirportCheckpointService:
      def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]]       = ZIO.succeed(
        None
      )
      def markCheckpoint(ride: Ride, checkpoint: AirportCheckpoint, markedBy: PersonId): IO[RideError, Unit] = nopeDie(
        "markCheckpoint"
      )
  )

  private val stubChatService: ZLayer[Any, Nothing, ChatService] = ZLayer.succeed(
    new ChatService:
      def sendMessage(rideId: RideId, senderId: PersonId, message: String): Task[ChatMessage] = nopeDie("sendMessage")
      def getMessages(rideId: RideId): Task[List[ChatMessage]]                                = ZIO.succeed(Nil)
  )

  private val stubRideRatingRepo: ZLayer[Any, Nothing, RideRatingRepository] = RideRatingRepository.inMemory
  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository]         = ZLayer.succeed(new InMemoryTariffRepository())

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  // ---------------------------------------------------------------------------
  // Layer builder
  // ---------------------------------------------------------------------------

  private def buildLayers(
      rides: Map[RideId, Ride],
      confirmCalledRef: Ref[Boolean],
      rejectCalledRef: Ref[Boolean]
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      makeStubRideService(rides, confirmCalledRef, rejectCalledRef) ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      stubRideRatingRepo ++
      stubPersonRepo ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
      AirportArrivalTimingConfig.liveLayer ++
      EventHub.layer ++
      StubFlightStatusProvider.layer ++
      StubRideRepository.layer

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
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("RideApi — confirm/reject endpoint-level tenant-isolation [CRITICAL]")(
      // ── Happy path: driver of company A confirms company-A ride ──────────────
      test("happy path: driver of company A confirms own ride → 200") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token <- generateToken(PersonRole.Driver, companyAId).provideLayer(testJwtService)
          req    = Request
                     .put(URL.decode(s"/api/rides/${rideAId.value}/confirm").toOption.get, Body.empty)
                     .addHeader(Header.Authorization.Bearer(token))
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.Ok)
      },

      // ── CRITICAL: cross-tenant confirm must be blocked ───────────────────────
      test("[CRITICAL] driver of company B targeting company-A ride confirm → 404") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token <- generateToken(PersonRole.Driver, companyBId).provideLayer(testJwtService)
          req    = Request
                     .put(URL.decode(s"/api/rides/${rideAId.value}/confirm").toOption.get, Body.empty)
                     .addHeader(Header.Authorization.Bearer(token))
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },

      // ── CRITICAL: service.confirmRide must NOT be called on isolation failure ─
      test("[CRITICAL] service.confirmRide is NOT called when company isolation fails") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef      <- Ref.make(false)
          rRef      <- Ref.make(false)
          layers     = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token     <- generateToken(PersonRole.Driver, companyBId).provideLayer(testJwtService)
          req        = Request
                         .put(URL.decode(s"/api/rides/${rideAId.value}/confirm").toOption.get, Body.empty)
                         .addHeader(Header.Authorization.Bearer(token))
          _         <- run(req, layers)
          wasCalled <- cRef.get
        } yield assertTrue(!wasCalled)
      },

      // ── Happy path: driver of company A rejects company-A ride ──────────────
      test("happy path: driver of company A rejects own ride → 200") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token <- generateToken(PersonRole.Driver, companyAId).provideLayer(testJwtService)
          body   = Body.fromString("""{"reason":"car breakdown"}""")
          req    = Request
                     .put(URL.decode(s"/api/rides/${rideAId.value}/reject").toOption.get, body)
                     .addHeader(Header.Authorization.Bearer(token))
                     .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.Ok)
      },

      // ── CRITICAL: cross-tenant reject must be blocked ────────────────────────
      test("[CRITICAL] driver of company B targeting company-A ride reject → 404") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token <- generateToken(PersonRole.Driver, companyBId).provideLayer(testJwtService)
          body   = Body.fromString("""{"reason":"car breakdown"}""")
          req    = Request
                     .put(URL.decode(s"/api/rides/${rideAId.value}/reject").toOption.get, body)
                     .addHeader(Header.Authorization.Bearer(token))
                     .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },

      // ── CRITICAL: service.rejectRide must NOT be called on isolation failure ─
      test("[CRITICAL] service.rejectRide is NOT called when company isolation fails") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef      <- Ref.make(false)
          rRef      <- Ref.make(false)
          layers     = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token     <- generateToken(PersonRole.Driver, companyBId).provideLayer(testJwtService)
          body       = Body.fromString("""{"reason":"car breakdown"}""")
          req        = Request
                         .put(URL.decode(s"/api/rides/${rideAId.value}/reject").toOption.get, body)
                         .addHeader(Header.Authorization.Bearer(token))
                         .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          _         <- run(req, layers)
          wasCalled <- rRef.get
        } yield assertTrue(!wasCalled)
      },

      // ── Non-DRIVER role → 403 ────────────────────────────────────────────────
      test("Dispatcher JWT targeting confirm endpoint → 403 (DRIVER role required)") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          token <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req    = Request
                     .put(URL.decode(s"/api/rides/${rideAId.value}/confirm").toOption.get, Body.empty)
                     .addHeader(Header.Authorization.Bearer(token))
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.Forbidden)
      },

      // ── Unauthenticated → 401 ────────────────────────────────────────────────
      test("unauthenticated confirm request → 401") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          cRef  <- Ref.make(false)
          rRef  <- Ref.make(false)
          layers = buildLayers(Map(rideAId -> rideA), cRef, rRef)
          req    = Request.put(URL.decode(s"/api/rides/${rideAId.value}/confirm").toOption.get, Body.empty)
          resp  <- run(req, layers)
        } yield assertTrue(resp.status == Status.Unauthorized)
      }
    ) @@ TestAspect.sequential
