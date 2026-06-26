package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
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

      def assignDriver(
          rideId: RideId,
          driverId: PersonId,
          overrideScheduleConflict: Boolean = false
      ): IO[RideError, Ride] =
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

      // createRide echoes a fresh Requested ride for the request's client/company, so the
      // create endpoint reaches RideDto.fromDomain and the clientName-enrichment path is exercised.
      // It also echoes paymentMethod so the end-to-end wire→domain→DTO path can be asserted.
      def createRide(req: CreateRideRequest): IO[RideError, Ride] = ZIO.succeed(
        Ride(
          id = rideAId,
          clientId = req.clientId,
          creatorId = req.clientId,
          companyId = req.companyId,
          status = RideStatus.Requested,
          pickupLocation = req.pickupLocation,
          dropoffLocation = req.dropoffLocation,
          pickupDateTime = req.pickupDateTime.getOrElse(Instant.now().plusSeconds(3600)),
          requestTime = Instant.now(),
          paymentMethod = req.paymentMethod
        )
      )

      // updateRideDetails returns the known ride unchanged so the update endpoint reaches
      // RideDto.fromDomain and the clientName-enrichment path is exercised.
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] =
        rides.get(rideId) match
          case Some(r) => ZIO.succeed(r)
          case None    => ZIO.fail(RideError.RideNotFound(rideId))

      // All other methods die (they must not be reached in these tests)
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
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = ZIO.succeed(Nil)
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]        =
        notImplemented
      def getDriverRidesPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): IO[RideError, List[Ride]] = notImplemented
      def markPayment(
          rideId: RideId,
          ps: PaymentStatus,
          pm: Option[PaymentMethod]
      ): IO[RideError, Ride] = notImplemented
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                    = notImplemented
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                = ZIO.succeed(Map.empty)
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                        = ZIO.succeed(0.0)
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
  // No-op stubs for the remaining RideEnv dependencies
  // ---------------------------------------------------------------------------

  /**
   * The client whose name must surface in ride DTOs. Used by `clientPersonRepo` so the clientName-enrichment regression
   * tests can assert the real name is returned (not the "Unknown Client" fallback baked into RideDto.fromDomain).
   */
  private val clientPerson: Person = Person(
    id = clientAId,
    email = "anna@test.de",
    name = "Anna Schmidt",
    role = PersonRole.Client,
    passwordHash = "hash",
    companyId = Some(companyAId),
    status = UserStatus.ACTIVE,
    // Has a profile photo so the clientHasAvatar enrichment can be asserted.
    avatarPresent = true
  )

  private def makePersonRepo(known: Map[PersonId, Person]): ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(known.get(id))
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

  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository]   = makePersonRepo(Map.empty)
  private val clientPersonRepo: ZLayer[Any, Nothing, PersonRepository] = makePersonRepo(Map(clientAId -> clientPerson))

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
      ) = ZIO.none
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
      reassignedRef: Ref[Boolean],
      personRepo: ZLayer[Any, Nothing, PersonRepository] = stubPersonRepo
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      makeStubRideService(rides, assignedRef, reassignedRef) ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      stubRideRatingRepo ++
      personRepo ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
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
  // JSON body helpers
  // ---------------------------------------------------------------------------

  private def assignBody(driverId: PersonId): Body = Body.fromString(s"""{"driverId":"${driverId.value}"}""")

  private def reassignBody(driverId: PersonId): Body = Body.fromString(
    s"""{"driverId":"${driverId.value}","overrideScheduleConflict":false}"""
  )

  // A minimal-valid create-ride body for `clientId` (far-future pickup so it never trips the
  // "pickup time cannot be in the past" rule).
  private def createBody(clientId: PersonId): Body = Body.fromString(
    s"""{"clientId":"${clientId.value}","creatorId":"${clientId.value}",""" +
      """"pickupDateTime":"2090-01-01T10:00:00Z",""" +
      """"from":{"address":"Munich Airport"},"to":{"address":"City Center"},""" +
      """"clientName":"ignored-by-server"}"""
  )

  // Create-ride body carrying a payment method wire value (e.g. "Payment").
  private def createBodyWithPayment(clientId: PersonId, paymentMethod: String): Body = Body.fromString(
    s"""{"clientId":"${clientId.value}","creatorId":"${clientId.value}",""" +
      s""""paymentMethod":"$paymentMethod",""" +
      """"pickupDateTime":"2090-01-01T10:00:00Z",""" +
      """"from":{"address":"Munich Airport"},"to":{"address":"City Center"},""" +
      """"clientName":"ignored-by-server"}"""
  )

  // Create-ride body that also requests an optional self-assign to `driverId`.
  private def createBodyWithDriver(clientId: PersonId, driverId: PersonId): Body = Body.fromString(
    s"""{"clientId":"${clientId.value}","creatorId":"${clientId.value}",""" +
      s""""driverId":"${driverId.value}",""" +
      """"pickupDateTime":"2090-01-01T10:00:00Z",""" +
      """"from":{"address":"Munich Airport"},"to":{"address":"City Center"},""" +
      """"clientName":"ignored-by-server"}"""
  )

  // RideService whose assignDriver always fails with company_isolation — models a
  // self-assign to a driver of another company. createRide still returns the pooled
  // (unassigned) ride. The create endpoint must SWALLOW that isolation error and
  // return the pooled ride (201, driverId null), never leak the cross-tenant driver.
  private def crossTenantAssignRideService(
      assignedRef: Ref[Boolean]
  ): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImplemented = ZIO.die(new NotImplementedError("crossTenantAssignRideService stub"))

      def createRide(req: CreateRideRequest): IO[RideError, Ride] = ZIO.succeed(
        Ride(
          id = rideAId,
          clientId = req.clientId,
          creatorId = req.clientId,
          companyId = req.companyId,
          status = RideStatus.Requested,
          pickupLocation = req.pickupLocation,
          dropoffLocation = req.dropoffLocation,
          pickupDateTime = req.pickupDateTime.getOrElse(Instant.now().plusSeconds(3600)),
          requestTime = Instant.now()
        )
      )

      def assignDriver(
          rideId: RideId,
          driverId: PersonId,
          overrideScheduleConflict: Boolean = false
      ): IO[RideError, Ride] =
        assignedRef.set(true) *>
          ZIO.fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                            = notImplemented
      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean
      ): IO[RideError, Ride] = notImplemented
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImplemented
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
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = ZIO.succeed(Nil)
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]        =
        notImplemented
      def getDriverRidesPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): IO[RideError, List[Ride]] = notImplemented
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

  private def buildCrossTenantLayers(
      assignedRef: Ref[Boolean]
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      crossTenantAssignRideService(assignedRef) ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      stubRideRatingRepo ++
      clientPersonRepo ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
      StubRideRepository.layer

  private val updateBody: Body = Body.fromString("""{"notes":"updated"}""")

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

      // ── clientName enrichment: GET /rides/{id} must surface the real client name ──
      // Regression for the "Unknown Client" bug: the driver's "New ride assigned" dialog
      // fetches the ride via GET /rides/{id}; that endpoint must enrich clientName from
      // PersonRepository instead of falling back to "Unknown Client".
      test("[REGRESSION] GET /rides/{id} returns the real clientName, not 'Unknown Client'") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .get(URL.decode(s"/api/rides/${rideAId.value}").toOption.get)
                             .addHeader(Header.Authorization.Bearer(token))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientName\":\"Anna Schmidt\""),
          !body.contains("Unknown Client")
        )
      },

      // ── clientName enrichment: assign-driver response must surface the real client name ──
      test("[REGRESSION] assign-driver response returns the real clientName, not 'Unknown Client'") {
        val rideA = makeRequestedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideAId.value}/assign-driver").toOption.get,
                               assignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientName\":\"Anna Schmidt\""),
          !body.contains("Unknown Client")
        )
      },

      // ── clientName enrichment: reassign-driver response must surface the real client name ──
      test("[REGRESSION] reassign-driver response returns the real clientName, not 'Unknown Client'") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(
                               URL.decode(s"/api/rides/${rideAId.value}/reassign-driver").toOption.get,
                               reassignBody(driverAId)
                             )
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientName\":\"Anna Schmidt\""),
          !body.contains("Unknown Client")
        )
      },

      // ── clientName enrichment: update-ride response must surface the real client name ──
      test("[REGRESSION] update-ride response returns the real clientName, not 'Unknown Client'") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .put(URL.decode(s"/api/rides/${rideAId.value}").toOption.get, updateBody)
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientName\":\"Anna Schmidt\""),
          !body.contains("Unknown Client")
        )
      },

      // ── clientName enrichment: create-ride response must surface the real client name ──
      // The server must derive clientName from PersonRepository (Anna), never from the request
      // body — createBody deliberately sends clientName="ignored-by-server".
      test("[REGRESSION] create-ride response returns the real clientName from the repo, not the request") {
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map.empty, assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .post(URL.decode("/api/rides").toOption.get, createBody(clientAId))
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Created,
          body.contains("\"clientName\":\"Anna Schmidt\""),
          !body.contains("Unknown Client"),
          !body.contains("ignored-by-server")
        )
      },

      // ── clientHasAvatar enrichment: GET /rides/{id} surfaces the client's avatar flag ──
      // The driver/dispatcher card renders the client's photo; the ride DTO must report
      // whether the client has one, derived from the same Person already loaded for clientName.
      test("[REGRESSION] GET /rides/{id} reports clientHasAvatar=true when the client has a photo") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .get(URL.decode(s"/api/rides/${rideAId.value}").toOption.get)
                             .addHeader(Header.Authorization.Bearer(token))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientHasAvatar\":true")
        )
      },

      // ── clientHasAvatar enrichment: absent client → false (never true by accident) ──
      test("[REGRESSION] GET /rides/{id} reports clientHasAvatar=false when the client is unknown") {
        val rideA = makeAssignedRide(rideAId, companyAId)
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          // stubPersonRepo knows no persons, so the client lookup returns None.
          layers         = buildLayers(Map(rideAId -> rideA), assignedRef, reassignedRef)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .get(URL.decode(s"/api/rides/${rideAId.value}").toOption.get)
                             .addHeader(Header.Authorization.Bearer(token))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"clientHasAvatar\":false")
        )
      },

      // ── End-to-end: create-ride carries the payment method wire→domain→DTO ──
      // POST /api/rides with paymentMethod="Payment" must parse the wire value in
      // CreateRideApiRequest.toDomain, thread it through createRide, and surface it
      // back in the RideDto response. Proves the full HTTP create path for the new
      // Payment value (not just the per-layer unit tests).
      test("[E2E] create-ride with paymentMethod='Payment' returns it in the response") {
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map.empty, assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .post(URL.decode("/api/rides").toOption.get, createBodyWithPayment(clientAId, "Payment"))
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Created,
          body.contains("\"paymentMethod\":\"Payment\"")
        )
      },

      // ── End-to-end: omitting paymentMethod leaves it absent in the response ──
      test("[E2E] create-ride without a paymentMethod does not surface one") {
        for {
          assignedRef   <- Ref.make(false)
          reassignedRef <- Ref.make(false)
          layers         = buildLayers(Map.empty, assignedRef, reassignedRef, clientPersonRepo)
          token         <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req            = Request
                             .post(URL.decode("/api/rides").toOption.get, createBody(clientAId))
                             .addHeader(Header.Authorization.Bearer(token))
                             .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp          <- run(req, layers)
          body          <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Created,
          !body.contains("\"paymentMethod\":\"Payment\"")
        )
      },

      // ── CRITICAL: create-ride self-assign to a cross-tenant driver must not leak ──
      // A self-assign to a driver of another company makes assignDriver fail with
      // company_isolation. The create endpoint must SWALLOW that (like a schedule
      // conflict) and return the pooled, unassigned ride — 201 with driverId null —
      // so the response never reveals that the cross-tenant driver exists.
      test("[CRITICAL] create-ride self-assign to a cross-tenant driver → 201 unassigned, no leak") {
        for {
          assignedRef <- Ref.make(false)
          layers       = buildCrossTenantLayers(assignedRef)
          token       <- generateToken(PersonRole.Dispatcher, companyAId).provideLayer(testJwtService)
          req          = Request
                           .post(URL.decode("/api/rides").toOption.get, createBodyWithDriver(clientAId, driverAId))
                           .addHeader(Header.Authorization.Bearer(token))
                           .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp        <- run(req, layers)
          body        <- resp.body.asString
          wasCalled   <- assignedRef.get
        } yield assertTrue(
          // assignDriver WAS attempted (the self-assign path ran)...
          wasCalled,
          // ...but the isolation failure was swallowed: the ride is created and pooled.
          resp.status == Status.Created,
          // The ride came back without a driver (pool), and no isolation error leaked.
          body.contains("\"driverId\":null") || !body.contains(s"\"driverId\":\"${driverAId.value}\""),
          !body.contains("company_isolation"),
          !body.contains("different company")
        )
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
