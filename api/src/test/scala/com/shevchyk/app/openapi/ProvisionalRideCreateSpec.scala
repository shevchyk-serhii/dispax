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
 * Regression test for the core of the "from-chat" feature: a DRIVER books a ride WITHOUT a real client by setting
 * `provisionalClient: true`. The backend must create a provisional client (carrying the typed name + the creator's
 * companyId) and book the ride onto THAT client — NOT onto the driver, as the old `clientId == own userId` hack did.
 *
 * The discriminating assertion is on the `CreateRideRequest.clientId` captured from the RideService: it must equal the
 * freshly created provisional person's id and must NOT equal the driver's userId. Mutation: revert `createRideServer`
 * to `req.copy(clientId = PersonId(user.userId))` → the captured ride clientId becomes the driver's id → this spec goes
 * red. (Asserting on the response body alone would be false-green, because the response client fields are taken from
 * the provisional Person we hold, regardless of what the ride was actually booked onto.)
 */
object ProvisionalRideCreateSpec extends ZIOSpecDefault:

  private val companyId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000099"))
  private val driverId: PersonId   = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000099"))

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
  // Recording stubs: capture what the create flow created/booked.
  // ---------------------------------------------------------------------------

  // Captures every Person passed to create() — the provisional client lands here.
  private def recordingPersonRepo(created: Ref[List[Person]]): PersonRepository =
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = created.update(_ :+ person).as(person)
      // The flow does NOT call findById in provisional mode (it reuses the created Person), so fail loudly if it does.
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.die(
        new NotImplementedError("findById should not be called in provisional mode")
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

  // Captures the CreateRideRequest and returns a Ride built from it (so the booked clientId is observable).
  private def recordingRideService(captured: Ref[Option[CreateRideRequest]]): RideService =
    new RideService:
      private def notImpl = ZIO.die(new NotImplementedError("ProvisionalRideCreateSpec stub"))

      def createRide(req: CreateRideRequest): IO[RideError, Ride] = captured
        .set(Some(req))
        .as(
          Ride(
            id = RideId.generate(),
            clientId = req.clientId,
            creatorId = req.clientId,
            companyId = req.companyId,
            status = RideStatus.Requested,
            pickupLocation = req.pickupLocation,
            dropoffLocation = req.dropoffLocation,
            pickupDateTime = req.pickupDateTime.getOrElse(Instant.parse("2090-01-01T10:00:00Z")),
            requestTime = Instant.parse("2090-01-01T09:00:00Z"),
            specifics = req.specifics
          )
        )

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                       = notImpl
      def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]]                                = notImpl
      def assignDriver(rideId: RideId, dId: PersonId, o: Boolean): IO[RideError, Ride]                           = notImpl
      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          o: Boolean,
          allowPastRide: Boolean = false
      ): IO[RideError, Ride] = notImpl
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
      def getDriverRides(d: PersonId, c: CompanyId): IO[RideError, List[Ride]]                                   = notImpl
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

  // RideRepository is only touched for flight enrichment on list endpoints — not on create. Fail loudly if used.
  private val noopRideRepo: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed(
    new RideRepository:
      private def notImpl(m: String): Nothing                                                                          = throw new NotImplementedError(s"ProvisionalRideCreateSpec.$m")
      def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]]                               = ZIO.succeed(Map.empty)
      def create(ride: Ride): Task[Ride]                                                                               = notImpl("create")
      def findById(id: RideId): Task[Option[Ride]]                                                                     = notImpl("findById")
      def findByStatus(status: RideStatus): Task[List[Ride]]                                                           = notImpl("findByStatus")
      def findAll(): Task[List[Ride]]                                                                                  = notImpl("findAll")
      def findByClientId(clientId: PersonId): Task[List[Ride]]                                                         = notImpl("findByClientId")
      def findByDriverId(driverId: PersonId): Task[List[Ride]]                                                         = notImpl("findByDriverId")
      def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]                         = notImpl("a")
      def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]                         = notImpl("b")
      def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]                           = notImpl("c")
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                                      = notImpl("d")
      def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]]                    = notImpl("e")
      def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]                       = notImpl("f")
      def findByDriverIdAndCompanyPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): Task[List[Ride]] = notImpl("g")
      def update(ride: Ride): Task[Ride]                                                                               = notImpl("update")
      def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                                 = notImpl("h")
      def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]                     = notImpl("i")
      def delete(id: RideId, companyId: CompanyId): Task[Unit]                                                         = notImpl("delete")
      def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]                                  = notImpl("j")
      def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                                  = notImpl("k")
      def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                             = notImpl("l")
      def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]                                            = notImpl("m")
      def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]               = notImpl("n")
      def earningsByDriver(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant): Task[DriverEarnings] =
        notImpl("o")
      def earningsBucketsByDriver(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant,
          bucket: TimeBucket
      ): Task[List[(Instant, BigDecimal)]] = notImpl("p")
      def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                                      = notImpl("q")
      def findActiveRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                                        = notImpl("r")
      def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]]                                   = notImpl("s")
      def findByDriverIdInWindow(driverId: PersonId, from: Instant, to: Instant): Task[List[Ride]]                     = notImpl("s2")
      def clearReminders(rideId: RideId): Task[Unit]                                                                   = notImpl("t")
      def countAllRidesByStatus(): Task[Map[String, Int]]                                                              = notImpl("u")
      def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                                  = notImpl("v")
      def countRidesByCompany(from: Instant, to: Instant): Task[Map[UUID, Int]]                                        = notImpl("w")
      def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[UUID, BigDecimal]]                         = notImpl("x")
      def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean]                               = notImpl("y")
      def updateFlightStatus(
          rideId: RideId,
          gate: Option[String],
          terminal: Option[String],
          flightStatus: Option[String],
          flightTime: Option[Instant],
          scheduledTime: Option[Instant],
          departureTime: Option[Instant]
      ): Task[Boolean] = notImpl("z")
      def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]]                                              = notImpl("findFlightStatus")
  )

  private val stubClientAddressService: ZLayer[Any, Nothing, ClientAddressService] = ZLayer.succeed(
    new ClientAddressService:
      def getAddresses(clientId: PersonId)                                                                     = ZIO.succeed(Nil)
      def saveAddress(clientId: PersonId, req: SaveClientAddressRequest)                                       = ZIO.die(new NotImplementedError("stub"))
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

  private def layers(
      createdPersons: Ref[List[Person]],
      capturedRide: Ref[Option[CreateRideRequest]]
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    testJwtService ++
      ZLayer.succeed(recordingRideService(capturedRide)) ++
      stubClientAddressService ++
      stubClientLocationService ++
      stubAirportCheckpointService ++
      stubChatService ++
      RideRatingRepository.inMemory ++
      ZLayer.succeed(recordingPersonRepo(createdPersons)) ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
      AirportArrivalTimingConfig.liveLayer ++
      EventHub.layer ++
      StubFlightStatusProvider.layer ++
      noopRideRepo

  private def run(req: Request, ls: ZLayer[Any, Throwable, RideApi.RideEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(RideApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(ls)

  private val provisionalBody: String =
    """{"clientId":"","creatorId":"%s","from":{"address":"Marienplatz 1, Munich"},
      |"to":{"address":"Leopoldstr 5, Munich"},"clientName":"Chat Pax",
      |"pickupDateTime":"2090-01-01T10:00:00Z","provisionalClient":true}""".stripMargin
      .replace("\n", "")
      .format(driverId.value.toString)

  override def spec: Spec[TestEnvironment & Scope, Any] =
    suite("provisional (from-chat) ride creation")(
      test(
        "driver booking with provisionalClient creates a provisional client and books the ride onto it (not the driver)"
      ) {
        for {
          createdPersons <- Ref.make(List.empty[Person])
          capturedRide   <- Ref.make(Option.empty[CreateRideRequest])
          ls              = layers(createdPersons, capturedRide)
          token          <- driverToken.provideLayer(testJwtService)
          req             = Request
                              .post(
                                URL.decode("/api/rides").toOption.get,
                                Body.fromString(provisionalBody)
                              )
                              .addHeader(Header.Authorization.Bearer(token))
                              .addHeader(Header.ContentType(MediaType.application.json))
          resp           <- run(req, ls)
          persons        <- createdPersons.get
          booked         <- capturedRide.get
        } yield {
          val provisional = persons.headOption
          assertTrue(
            resp.status == Status.Created,
            // a provisional client was created, with the typed name and the creator's company
            persons.size == 1,
            provisional.exists(_.provisional),
            provisional.exists(_.name == "Chat Pax"),
            provisional.exists(_.companyId.contains(companyId)),
            // the ride was booked onto that provisional client — NOT onto the driver (the old hack)
            booked.exists(r => provisional.exists(_.id == r.clientId)),
            booked.exists(_.clientId.value != driverId.value)
          )
        }
      }
    )
