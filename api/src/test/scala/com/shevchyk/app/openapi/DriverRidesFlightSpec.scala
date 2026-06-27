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
import com.shevchyk.ride.repository.{
  InMemoryTariffRepository,
  RideRatingRepository,
  RideRepository,
  TariffRepository,
  TimeBucket
}
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Regression test for the missing flight gate/terminal/status on the DRIVER "Today" ride card.
 *
 * Bug: `getDriverRidesServer` (`GET /api/rides/driver/{driverId}`) built its `RideDto`s with `RideDto.fromDomain(r,
 * ...)` and NEVER passed the `flight` parameter, so gate/terminal/status serialized as null even though
 * `FlightStatusMonitor` keeps them fresh in the DB. The driver card therefore only ever showed the flight number (e.g.
 * "↓ LH1751"). The dispatcher endpoint (`getRidesByDriversServer`) already enriched flight data; this brings the driver
 * endpoint in line.
 *
 * The fix loads `rideRepo.findFlightStatusFor(airportIds)` in one bulk query and passes `flight = flightMap.get(r.id)`
 * into `fromDomain`.
 *
 * Mutation check: drop `flight = flightMap.get(r.id)` (or the `findFlightStatusFor` load) from `getDriverRidesServer` →
 * the response gate/terminal/flightStatus go null → this test goes red.
 */
object DriverRidesFlightSpec extends ZIOSpecDefault:

  private val companyId: CompanyId  = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val driverId: PersonId    = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val clientId: PersonId    = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val airportRideId: RideId = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  // The live flight row the repository will surface for the airport ride.
  private val flightRow: FlightStatusRow = FlightStatusRow(
    gate = Some("G12"),
    terminal = Some("2"),
    flightStatus = Some("Landed"),
    flightTime = Some(Instant.parse("2090-01-01T10:00:00Z"))
  )

  private def airportRide: Ride = Ride(
    id = airportRideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = RideStatus.Assigned,
    pickupLocation = Location("Munich Airport Terminal 2"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.parse("2090-01-01T11:32:00Z"),
    requestTime = Instant.now(),
    specifics = Some(RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH1751", isArrival = true))
  )

  // ---------------------------------------------------------------------------
  // JWT
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

  private def driverToken: ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = driverId,
          email = "driver@test.de",
          name = "Driver User",
          role = PersonRole.Driver,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )

  // ---------------------------------------------------------------------------
  // Stubs: only the methods the driver-list endpoint touches return real data.
  // ---------------------------------------------------------------------------

  private val stubRideService: ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImpl = ZIO.die(new NotImplementedError("DriverRidesFlightSpec stub"))

      def getDriverRides(d: PersonId, c: CompanyId): IO[RideError, List[Ride]] = ZIO.succeed(List(airportRide))

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                       = notImpl
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
  )

  // A RideRepository that surfaces the live flight row ONLY via the bulk lookup the
  // endpoint uses, so the test fails if the endpoint stops calling it.
  private val flightRideRepo: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed(
    new RideRepository:
      private def notImpl(m: String): Nothing = throw new NotImplementedError(s"DriverRidesFlightSpec.$m")

      def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]] = ZIO.succeed(
        rideIds.filter(_ == airportRideId).map(_ -> flightRow).toMap
      )

      def create(ride: Ride): Task[Ride]                                                            = notImpl("create")
      def findById(id: RideId): Task[Option[Ride]]                                                  = notImpl("findById")
      def findByStatus(status: RideStatus): Task[List[Ride]]                                        = notImpl("findByStatus")
      def findAll(): Task[List[Ride]]                                                               = notImpl("findAll")
      def findByClientId(clientId: PersonId): Task[List[Ride]]                                      = notImpl("findByClientId")
      def findByDriverId(driverId: PersonId): Task[List[Ride]]                                      = notImpl("findByDriverId")
      def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]      = notImpl(
        "findByDriverIdAndCompany"
      )
      def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]      = notImpl(
        "findByClientIdAndCompany"
      )
      def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]        = notImpl(
        "findByStatusAndCompany"
      )
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                   = notImpl("findByCompanyId")
      def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]] = notImpl(
        "findByCompanyIdPaginated"
      )
      def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]    = notImpl(
        "findByDriverIdPaginated"
      )
      def findByDriverIdAndCompanyPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): Task[List[Ride]] = notImpl("findByDriverIdAndCompanyPaginated")
      def update(ride: Ride): Task[Ride]                                                            = notImpl("update")
      def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]              = notImpl("updateIfStatus")
      def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]  = notImpl(
        "markPaidIfCompleted"
      )
      def delete(id: RideId, companyId: CompanyId): Task[Unit]                                      = notImpl("delete")
      def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]               = notImpl(
        "countByCompanyGroupedByStatus"
      )
      def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                               = notImpl("sumRevenueByCompany")
      def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                          = notImpl(
        "sumTodayRevenueByCompany"
      )
      def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]                         = notImpl(
        "avgAssignmentMinutesByCompany"
      )
      def countDailyStatsByCompany(
          companyId: CompanyId,
          days: Int
      ): Task[List[(String, Int, Int, Int)]] = notImpl("countDailyStatsByCompany")
      def earningsByDriver(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant
      ): Task[DriverEarnings] = notImpl("earningsByDriver")
      def earningsBucketsByDriver(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant,
          bucket: TimeBucket
      ): Task[List[(Instant, BigDecimal)]] = notImpl("earningsBucketsByDriver")
      def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                   = notImpl(
        "findAssignedRidesInWindow"
      )
      def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]]                = notImpl(
        "findRidesNeedingConfirmation"
      )
      def clearReminders(rideId: RideId): Task[Unit]                                                = notImpl("clearReminders")
      def countAllRidesByStatus(): Task[Map[String, Int]]                                           = notImpl("countAllRidesByStatus")
      def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                               = notImpl("sumAllRevenue")
      def countRidesByCompany(from: Instant, to: Instant): Task[Map[UUID, Int]]                     = notImpl("countRidesByCompany")
      def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[UUID, BigDecimal]]      = notImpl(
        "sumRevenueByCompanyPlatform"
      )
      def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean]            = notImpl("updateCheckpoint")
      def updateFlightStatus(
          rideId: RideId,
          gate: Option[String],
          terminal: Option[String],
          flightStatus: Option[String],
          flightTime: Option[Instant]
      ): Task[Boolean] = notImpl("updateFlightStatus")
      def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]]                           = notImpl("findFlightStatus")
  )

  private val clientPerson: Person = Person(
    id = clientId,
    email = "client@test.de",
    name = "Frau Meier",
    role = PersonRole.Client,
    passwordHash = "hash",
    companyId = Some(companyId),
    status = UserStatus.ACTIVE
  )

  private val personRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(
        if id == clientId then Some(clientPerson) else None
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

  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository]             = ZLayer.succeed(new InMemoryTariffRepository())

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  private val layers: ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      stubRideService ++
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
      flightRideRepo

  private def run(req: Request): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(RideApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(layers)

  override def spec: Spec[TestEnvironment & Scope, Any] = suite("GET /api/rides/driver/{driverId} flight enrichment")(
    test("driver ride card response carries gate, terminal and flightStatus for an airport ride") {
      for {
        token <- driverToken
        req    = Request
                   .get(URL.decode(s"/api/rides/driver/${driverId.value}").toOption.get)
                   .addHeader(Header.Authorization.Bearer(token))
        resp  <- run(req)
        body  <- resp.body.asString
      } yield assertTrue(
        resp.status == Status.Ok,
        body.contains("LH1751"), // flight number still present
        body.contains("\"gate\":\"G12\""),
        body.contains("\"terminal\":\"2\""),
        body.contains("\"flightStatus\":\"Landed\"")
      )
    }
  ).provideLayer(testJwtService)
