package com.shevchyk.app.openapi

import com.shevchyk.core.application.EventHub

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.config.AirportArrivalTimingConfig
import com.shevchyk.core.database.PostgresTestContainer
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
import com.shevchyk.ride.repository.{
  InMemoryTariffRepository,
  PostgresRideRepository,
  RideRatingRepository,
  TariffRepository
}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * END-TO-END integration test for the driver rides endpoint flight enrichment, against a REAL PostgreSQL
 * (Testcontainers). Complements [[DriverRidesFlightSpec]] (same endpoint, but a stubbed repository): here both halves
 * of the endpoint — `service.getDriverRides` (→ `findByDriverIdAndCompany`) AND `rideRepo.findFlightStatusFor` — hit
 * the real `PostgresRideRepository`, so the SQL bulk flight-lookup is exercised through the live HTTP path.
 *
 * Flow: seed company/persons → create an airport ride for the driver → write gate/terminal/status via the real
 * `updateFlightStatus` → `GET /api/rides/driver/{driverId}` through the Tapir endpoint → assert the JSON carries
 * gate/terminal/flightStatus.
 *
 * Mutation check: drop `flight = flightMap.get(r.id)` from `getDriverRidesServer` → gate/terminal/flightStatus go null
 * in the response → this test goes red. The "ride is present at all" assertions guard against a false-green where
 * company-isolation returns an empty list.
 *
 * Note: the BDD/Cucumber suite cannot cover this — it runs against `TestApplication`'s in-memory repository whose
 * `findFlightStatusFor` is a `Map.empty` stub, so only a Testcontainers spec reaches the real SQL.
 */
object DriverRidesFlightPostgresSpec extends ZIOSpecDefault:

  private val companyId: CompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val clientId: PersonId   = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  private val driverId: PersonId   = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  private val flightTime: Instant = Instant.parse("2090-01-01T10:00:00Z")

  private def seedPeople(xa: Transactor[Task]): Task[Unit] =
    (for
      _ <-
        sql"""INSERT INTO companies (id, name, email)
              VALUES (${companyId.value}, 'Test GmbH', 'test@example.com')
              ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
              VALUES (${clientId.value}, 'Frau Meier', 'client@test.com',
                      'client'::person_role, ${companyId.value}, 'x')
              ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
              VALUES (${driverId.value}, 'Test Driver', 'driver@test.com',
                      'driver'::person_role, ${companyId.value}, 'x')
              ON CONFLICT DO NOTHING""".update.run
    yield ()).transact(xa)

  private def cleanRides(xa: Transactor[Task]): Task[Unit] = sql"DELETE FROM rides".update.run.transact(xa).unit

  private def airportRide(id: RideId): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = RideStatus.Assigned,
    pickupLocation = Location("Munich Airport Terminal 2", Some(48.3537), Some(11.7860)),
    dropoffLocation = Location("City Center", Some(48.1374), Some(11.5755)),
    pickupDateTime = Instant.parse("2090-01-01T11:32:00Z"),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH1751"), isArrival = true))
  )

  // ---------------------------------------------------------------------------
  // JWT — a driver fetching their own rides.
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

  private def driverToken: Task[String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = driverId,
          email = "driver@test.com",
          name = "Test Driver",
          role = PersonRole.Driver,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )
    .provideLayer(testJwtService)

  // ---------------------------------------------------------------------------
  // RideService whose getDriverRides delegates to the REAL repository, so the
  // endpoint's ride list comes from Postgres just like its flight lookup does.
  // ---------------------------------------------------------------------------

  private def realBackedRideService(repo: PostgresRideRepository): RideService =
    new RideService:
      private def notImpl = ZIO.die(new NotImplementedError("DriverRidesFlightPostgresSpec stub"))

      def getDriverRides(d: PersonId, c: CompanyId): IO[RideError, List[Ride]] = repo
        .findByDriverIdAndCompany(d, c)
        .mapError(RideError.DatabaseError(_))

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                       = notImpl
      def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]]                                = notImpl
      def assignDriver(rideId: RideId, dId: PersonId, o: Boolean): IO[RideError, Ride]                           = notImpl
      def reassignDriver(rideId: RideId, newDriverId: PersonId, o: Boolean): IO[RideError, Ride]                 = notImpl
      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                                = notImpl
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImpl
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                           = notImpl
      def startRide(rideId: RideId, dId: PersonId): IO[RideError, Ride]                                          = notImpl
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                      = notImpl
      def confirmRide(rideId: RideId, dId: PersonId): IO[RideError, Ride]                                        = notImpl
      def rejectRide(rideId: RideId, dId: PersonId, reason: String): IO[RideError, Ride]                         = notImpl
      def cancelRide(rideId: RideId, userId: PersonId, role: PersonRole): IO[RideError, Ride]                    = notImpl
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          role: PersonRole,
          req: CancelRideRequest,
          c: CompanyId
      ): IO[RideError, Ride] = notImpl
      def getCancellationStats(c: CompanyId): IO[RideError, Map[String, Int]]                                    = notImpl
      def handOffToExternal(
          rideId: RideId,
          callerCompanyId: CompanyId,
          callerId: PersonId,
          req: HandOffRequest
      ): IO[RideError, Ride] = notImpl
      def createPartnerCompany(c: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany]    = notImpl
      def listPartnerCompanies(c: CompanyId): IO[RideError, List[PartnerCompany]]                                = notImpl
      def createExternalDriver(c: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver]    = notImpl
      def listExternalDrivers(c: CompanyId): IO[RideError, List[ExternalDriver]]                                 = notImpl
      def updateRideStatus(
          rideId: RideId,
          req: UpdateRideStatusRequest,
          userId: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImpl
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                        = notImpl
      def getRidesByStatusAndCompany(status: RideStatus, c: CompanyId): IO[RideError, List[Ride]]                = notImpl
      def getClientRides(cId: PersonId, c: CompanyId): IO[RideError, List[Ride]]                                 = notImpl
      def getAllRides: IO[RideError, List[Ride]]                                                                 = notImpl
      def getRidesByCompany(c: CompanyId): IO[RideError, List[Ride]]                                             = notImpl
      def getRidesByCompanyPaginated(c: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]           = notImpl
      def getDriverRidesPaginated(d: PersonId, c: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] =
        notImpl
      def markPayment(rideId: RideId, ps: PaymentStatus, pm: Option[PaymentMethod]): IO[RideError, Ride]         = notImpl
      def getUnpaidCompletedRides(c: CompanyId): IO[RideError, List[Ride]]                                       = notImpl
      def getRideCountsByStatus(c: CompanyId): IO[RideError, Map[String, Int]]                                   = notImpl
      def getTotalRevenue(c: CompanyId): IO[RideError, BigDecimal]                                               = notImpl
      def getTodayRevenue(c: CompanyId): IO[RideError, BigDecimal]                                               = notImpl
      def getAvgAssignmentMinutes(c: CompanyId): IO[RideError, Double]                                           = notImpl
      def getDailyStats(c: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]                   = notImpl
      def getDriverEarnings(
          d: PersonId,
          c: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImpl
      def setRidePrice(
          rideId: RideId,
          price: Double,
          userId: PersonId,
          userRole: PersonRole,
          c: CompanyId
      ): IO[RideError, Ride] = notImpl
      def getRidesByDrivers(
          driverIds: List[PersonId],
          from: Option[String],
          to: Option[String],
          c: CompanyId
      ): IO[RideError, List[Ride]] = notImpl

  // ---------------------------------------------------------------------------
  // No-op RideEnv dependencies the driver-list endpoint does not exercise.
  // ---------------------------------------------------------------------------

  private val personRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      private val client: Person                                                                             = Person(
        id = clientId,
        email = "client@test.com",
        name = "Frau Meier",
        role = PersonRole.Client,
        passwordHash = "hash",
        companyId = Some(companyId),
        status = UserStatus.ACTIVE
      )
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(
        if id == clientId then Some(client) else None
      )
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

  private val stubClientAddressService: ZLayer[Any, Nothing, ClientAddressService] = ZLayer.succeed(
    new ClientAddressService:
      def getAddresses(clientId: PersonId)                                                                     = ZIO.succeed(Nil)
      def saveAddress(clientId: PersonId, req: SaveClientAddressRequest)                                       = ZIO.die(
        new NotImplementedError("stub")
      )
      def updateAddress(id: ClientAddressId, clientId: PersonId, req: UpdateClientAddressRequest)              = ZIO.none
      def recordUsage(cId: PersonId, address: String, label: String, lat: Option[Double], lng: Option[Double]) =
        ZIO.unit
      def deleteAddress(id: ClientAddressId, clientId: PersonId)                                               = ZIO.succeed(false)
  )

  private val stubClientLocationService: ZLayer[Any, Nothing, ClientLocationService] = ZLayer.succeed(
    new ClientLocationService:
      def updateClientLocation(rideId: RideId, cId: PersonId, lat: Double, lng: Double): IO[RideError, Unit] = ZIO.die(
        new NotImplementedError("stub")
      )
      def getRideLocations(rideId: RideId)                                                                   = ZIO.die(new NotImplementedError("stub"))
  )

  private val stubAirportCheckpointService: ZLayer[Any, Nothing, AirportCheckpointService] = ZLayer.succeed(
    new AirportCheckpointService:
      def checkGeofenceForLanded(ride: Ride, lat: Double, lon: Double): UIO[Option[AirportCheckpoint]]                = ZIO.none
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

  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository] = ZLayer.succeed(new InMemoryTariffRepository())

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  // Build the full RideEnv around a real PostgresRideRepository.
  private def envLayer(xa: Transactor[Task]): ZLayer[Any, Throwable, RideApi.RideEnv] =
    val repo                                                                             = PostgresRideRepository(xa)
    val rideRepoLayer: ZLayer[Any, Nothing, com.shevchyk.ride.repository.RideRepository] = ZLayer.succeed(repo)
    val rideServiceLayer: ZLayer[Any, Nothing, RideService]                              = ZLayer.succeed(
      realBackedRideService(repo)
    )
    testJwtService ++
      rideServiceLayer ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      RideRatingRepository.inMemory ++
      personRepo ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
      AirportArrivalTimingConfig.liveLayer ++
      EventHub.layer ++
      StubFlightStatusProvider.layer ++
      rideRepoLayer

  private def run(req: Request, xa: Transactor[Task]): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(RideApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(envLayer(xa))

  def spec: Spec[TestEnvironment & Scope, Any] =
    suite("GET /api/rides/driver/{driverId} flight enrichment (real Postgres)")(
      test("driver rides response carries gate/terminal/flightStatus written to the DB") {
        val rideId = RideId(UUID.randomUUID())
        for
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedPeople(xa)
          _     <- cleanRides(xa)
          repo   = PostgresRideRepository(xa)
          _     <- repo.create(airportRide(rideId))
          ok    <- repo.updateFlightStatus(rideId, Some("G12"), Some("2"), Some("Landed"), Some(flightTime), None, None)
          token <- driverToken
          req    = Request
                     .get(URL.decode(s"/api/rides/driver/${driverId.value}").toOption.get)
                     .addHeader(Header.Authorization.Bearer(token))
          resp  <- run(req, xa)
          body  <- resp.body.asString
        yield assertTrue(
          ok,
          resp.status == Status.Ok,
          // The ride is actually returned (guards against a false-green where
          // company-isolation hands back an empty list).
          body.contains("LH1751"),
          // ...and the live flight columns from the real DB surface in the DTO.
          body.contains("\"gate\":\"G12\""),
          body.contains("\"terminal\":\"2\""),
          body.contains("\"flightStatus\":\"Landed\"")
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.tag("integration")
