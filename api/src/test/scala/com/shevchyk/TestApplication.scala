package com.shevchyk

import com.shevchyk.app.routes.WebSocketRoutes
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.domain.JwtError
import com.shevchyk.auth.service.{JwtPayload, JwtService, JwtServiceImpl}
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.domain.{
  CompanyBillingProfile,
  Invoice,
  InvoiceId,
  InvoiceItem,
  InvoiceStatus,
  UpdateCompanyBillingProfileRequest
}
import com.shevchyk.billing.repository.UnbilledRide
import com.shevchyk.billing.repository.{
  ClientCompanyRepository => BillingClientCompanyRepository,
  CompanyBillingProfileRepository,
  InvoiceRepository
}
import com.shevchyk.core.application.{
  AuditService,
  AvatarService,
  DriverAvailabilityChecker,
  EventHub,
  GeocodingService,
  GeofenceService,
  UnavailabilitySlot
}
import com.shevchyk.core.config.ServerConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.domain.{RidePool, RidePoolId, RidePoolMember, PoolStatus, PoolMemberStatus, Session, SessionId}
import com.shevchyk.core.repository.{
  BlacklistRepository,
  ClientCompanyRepository,
  CompanyRepository,
  CompanySettingsRepository,
  EmergencyReassignmentRepository,
  GdprRepository,
  GeofenceRepository,
  NotificationPreferenceRepository,
  PersonRepository,
  RidePoolRepository,
  SessionRepository
}
import com.shevchyk.notification.application.{FcmService, LoggingEmailSmsService}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, FcmToken}
import com.shevchyk.notification.repository.{FcmTokenRepository, NotificationRepository}
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  AirportConfigService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideEstimateService,
  RideService
}
import com.shevchyk.ride.domain.{
  AirportCheckpoint,
  ChatMessage,
  ChatMessageId,
  ClientAddress,
  ClientAddressId,
  ClientLocation,
  DriverEarnings,
  Expense,
  ExpenseCategory,
  ExpenseId,
  RecurrencePattern,
  Ride,
  RideSpecifics,
  RideStatus,
  RideTemplate,
  RideTemplateId
}
import com.shevchyk.ride.domain.{RideRating, RideRatingId}
import com.shevchyk.ride.repository.{
  AirportConfigRepository,
  ChatMessageRepository,
  ClientAddressRepository,
  ClientLocationRepository,
  ExpenseRepository,
  InMemoryTariffRepository,
  RideRatingRepository,
  RideRepository,
  RideTemplateRepository,
  TariffRepository,
  TimeBucket
}
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.domain.{DriverUnavailability, DriverScheduleVisibility, ScheduleDay, ScheduleError}
import com.shevchyk.schedule.repository.{
  DriverScheduleVisibilityRepository,
  DriverUnavailabilityRepository,
  ScheduleDayRepository
}
import org.mindrot.jbcrypt.BCrypt
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

import java.time.{Instant, LocalDate, ZoneOffset}
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object TestApplication extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  // ─── Test-only state reset registry ───────────────────────────────────────
  // Each mutable in-memory repository registers a thunk that restores its
  // initial seed (re-seed, not just clear). The `/test/reset` route runs them
  // all between Cucumber scenarios so every scenario starts from an identical
  // state. This lives ONLY in TestApplication — never in production.
  private val resetEffects = new java.util.concurrent.CopyOnWriteArrayList[zio.UIO[Unit]]()

  private def registerReset(effect: zio.UIO[Unit]): Unit = { resetEffects.add(effect); () }

  private val resetAll: zio.UIO[Unit] = ZIO.foreachDiscard(resetEffects.asScala.toList)(identity)

  private def hashPassword(password: String): String = BCrypt.hashpw(password, BCrypt.gensalt(12))

  private val testPersonId1       = PersonId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
  private val testPersonId50      = PersonId(UUID.fromString("50505050-5050-5050-5050-505050505050"))
  private val testPersonId10      = PersonId(UUID.fromString("10101010-1010-1010-1010-101010101010"))
  private val testPersonId99      = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
  private val testPersonId33      = PersonId(UUID.fromString("33333333-3333-3333-3333-333333333333"))
  private val testPersonId44      = PersonId(UUID.fromString("44444444-4444-4444-4444-444444444444"))
  // Dispatcher who also has the Driver role — used in 37_dispatcher_can_drive BDD
  private val testPersonIdDispDrv = PersonId(UUID.fromString("dddddddd-dddd-dddd-dddd-dddddddddddd"))
  private val testCompanyId1      = CompanyId(UUID.fromString("10101010-1010-1010-1010-101010101010"))
  // Second tenant ("company B") — used by 26_export tenant-isolation BDD to prove a
  // company-B token sees only its own (empty) DATEV/EXTF data, never company A's.
  private val testCompanyId2      = CompanyId(UUID.fromString("20202020-2020-2020-2020-202020202020"))
  private val testPersonIdDispB   = PersonId(UUID.fromString("2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b"))

  private val mockPersonRepository: PersonRepository =
    new PersonRepository {
      private val people = Map[PersonId, Person](
        testPersonId1       -> Person(
          testPersonId1,
          "Test User",
          "test@example.com",
          PersonRole.Client,
          passwordHash = hashPassword("Password123"),
          phone = Some("+1234567890"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId50      -> Person(
          testPersonId50,
          "Client User",
          "client@example.com",
          PersonRole.Client,
          passwordHash = hashPassword("Password123"),
          phone = Some("+1111111111"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId10      -> Person(
          testPersonId10,
          "Driver User",
          "driver@example.com",
          PersonRole.Driver,
          passwordHash = hashPassword("Password123"),
          phone = Some("+2222222222"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId99      -> Person(
          testPersonId99,
          "Admin User",
          "admin@example.com",
          PersonRole.Admin,
          passwordHash = hashPassword("Password123"),
          phone = Some("+3333333333"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId33      -> Person(
          testPersonId33,
          "Dispatcher User",
          "dispatcher@example.com",
          PersonRole.Dispatcher,
          passwordHash = hashPassword("Password123"),
          phone = Some("+4444444444"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId44      -> Person(
          testPersonId44,
          "Secretary User",
          "secretary@example.com",
          PersonRole.Secretary,
          passwordHash = hashPassword("Password123"),
          phone = Some("+5555555555"),
          companyId = Some(testCompanyId1)
        ),
        // Dispatcher who also holds the Driver role (used in 37_dispatcher_can_drive)
        testPersonIdDispDrv -> Person(
          testPersonIdDispDrv,
          "Disp Driver",
          "disp.driver@example.com",
          PersonRole.Dispatcher,
          passwordHash = hashPassword("Password123"),
          phone = Some("+6666666666"),
          companyId = Some(testCompanyId1),
          roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
        ),
        // Dispatcher of the second tenant (company B) — used in 26_export tenant isolation
        testPersonIdDispB   -> Person(
          testPersonIdDispB,
          "Dispatcher B",
          "dispatcher.b@example.com",
          PersonRole.Dispatcher,
          passwordHash = hashPassword("Password123"),
          phone = Some("+7777777777"),
          companyId = Some(testCompanyId2)
        )
      )

      def create(person: Person): Task[Person]                                                     = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                             = ZIO.succeed(people.get(id))
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]             = ZIO.succeed(
        people.get(id).filter(_.companyId.contains(companyId))
      )
      def findByEmail(email: String): Task[Option[Person]]                                         = ZIO.succeed(people.values.find(_.email == email))
      def findByRole(role: PersonRole): Task[List[Person]]                                         = ZIO.succeed(people.values.filter(_.role == role).toList)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]         = ZIO.succeed(
        people.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList
      )
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                = ZIO.succeed(
        people.values.filter(_.companyId.contains(companyId)).toList
      )
      def findAll(): Task[List[Person]]                                                            = ZIO.succeed(people.values.toList)
      def update(person: Person): Task[Person]                                                     = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                         = ZIO.unit
      def deleteInCompany(id: PersonId, companyId: com.shevchyk.core.domain.CompanyId): Task[Unit] = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                                     = ZIO.succeed(
        people.values.filter(_.status == status).toList
      )
      def searchByQuery(query: String): Task[List[Person]]                                         = ZIO.succeed(
        people.values
          .filter(p =>
            p.name.toLowerCase.contains(query.toLowerCase) || p.email.toLowerCase.contains(query.toLowerCase)
          )
          .toList
      )
      def updateLastLogin(id: PersonId): Task[Unit]                                                = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                          = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                             = ZIO.succeed(None)
      def setAvatar(id: PersonId, bytes: Array[Byte], contentType: String): Task[Unit]             = ZIO.unit
      def deleteAvatar(id: PersonId): Task[Unit]                                                   = ZIO.unit
    }

  private val mockTokenRepository: TokenRepository =
    new TokenRepository {
      private val tokens = Map[String, UUID](
        "valid-token-1"  -> testPersonId1.value,
        "valid-token-50" -> testPersonId50.value,
        "valid-token-10" -> testPersonId10.value,
        "valid-token-99" -> testPersonId99.value,
        "valid-token-33" -> testPersonId33.value,
        "valid-token-44" -> testPersonId44.value,
        "valid-token-dd" -> testPersonIdDispDrv.value,
        "valid-token-b"  -> testPersonIdDispB.value
      )

      def create(token: String, userId: UUID): Task[Unit]      = ZIO.unit
      def findUserIdByToken(token: String): Task[Option[UUID]] = ZIO.succeed(tokens.get(token))
      def deleteByToken(token: String): Task[Unit]             = ZIO.unit
      def deleteByUserId(userId: UUID): Task[Unit]             = ZIO.unit
    }

  private val testStaticTokenPayloads: Map[String, JwtPayload] = {
    val now  = java.time.Instant.now()
    val exp  = now.plusSeconds(86400L * 365).getEpochSecond
    val iat  = now.getEpochSecond
    Map(
      "valid-token-1"  -> JwtPayload(
        testPersonId1.value,
        "test@example.com",
        PersonRole.Client,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      "valid-token-50" -> JwtPayload(
        testPersonId50.value,
        "client@example.com",
        PersonRole.Client,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      "valid-token-10" -> JwtPayload(
        testPersonId10.value,
        "driver@example.com",
        PersonRole.Driver,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      "valid-token-99" -> JwtPayload(
        testPersonId99.value,
        "admin@example.com",
        PersonRole.Admin,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      "valid-token-33" -> JwtPayload(
        testPersonId33.value,
        "dispatcher@example.com",
        PersonRole.Dispatcher,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      "valid-token-44" -> JwtPayload(
        testPersonId44.value,
        "secretary@example.com",
        PersonRole.Secretary,
        Some(testCompanyId1.value),
        None,
        iat,
        exp
      ),
      // Dispatcher-driver token for 37_dispatcher_can_drive BDD scenarios
      "valid-token-dd" -> JwtPayload(
        testPersonIdDispDrv.value,
        "disp.driver@example.com",
        PersonRole.Dispatcher,
        Some(testCompanyId1.value),
        None,
        iat,
        exp,
        roles = Some(List(PersonRole.Dispatcher, PersonRole.Driver))
      ),
      // Dispatcher token for the second tenant (company B) — 26_export tenant isolation
      "valid-token-b"  -> JwtPayload(
        testPersonIdDispB.value,
        "dispatcher.b@example.com",
        PersonRole.Dispatcher,
        Some(testCompanyId2.value),
        None,
        iat,
        exp
      )
    )
  }

  private val testJwtServiceLayer: ZLayer[JwtConfig, Nothing, JwtService] = ZLayer.fromZIO {
    ZIO.serviceWith[JwtConfig] { config =>
      val real = new JwtServiceImpl(config)
      new JwtService {
        def generateToken(person: Person): ZIO[Any, JwtError, String]    = real.generateToken(person)
        def validateToken(token: String): ZIO[Any, JwtError, JwtPayload] =
          testStaticTokenPayloads.get(token) match
            case Some(payload) => ZIO.succeed(payload)
            case None          => real.validateToken(token)
        def refreshToken(token: String): ZIO[Any, JwtError, String]      = real.refreshToken(token)
      }
    }
  }

  private val resettableFcmTokenRepositoryLayer: ZLayer[Any, Nothing, FcmTokenRepository] = ZLayer.succeed {
    new FcmTokenRepository:
      private val store                                            = new ConcurrentHashMap[String, FcmToken]()
      registerReset(ZIO.succeed(store.clear()))
      def save(token: FcmToken): Task[Unit]                        = ZIO.succeed { store.put(token.token, token); () }
      def findByPersonId(personId: PersonId): Task[List[FcmToken]] = ZIO.succeed(
        store.values.asScala.filter(_.personId == personId).toList
      )
      def deleteByToken(token: String): Task[Unit]                 = ZIO.succeed { store.remove(token); () }
      def deleteByPersonId(personId: PersonId): Task[Unit]         = ZIO.succeed {
        store.values.asScala.filter(_.personId == personId).map(_.token).foreach(store.remove); ()
      }
  }

  private val resettableFcmServiceLayer: ZLayer[Any, Nothing, FcmService] =
    resettableFcmTokenRepositoryLayer >>> ZLayer {
      for tokenRepo <- ZIO.service[FcmTokenRepository]
      yield FcmService.FcmServiceImpl(tokenRepo, None)
    }

  // ─── Inline in-memory repositories (avoid cross-scope import issues) ──────

  private val testRideId = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  // scheduledTime must match pickupDateTime so checkScheduleConflict uses the right time
  private val testRideAssigned = Ride(
    id = testRideId,
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    driverId = Some(testPersonId10),
    status = RideStatus.Assigned,
    pickupLocation = Location("Hauptbahnhof München"),
    dropoffLocation = Location("Flughafen München"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    scheduledTime = Some(Instant.now().plusSeconds(3600))
  )

  private val testRideRequested = Ride(
    id = RideId(UUID.fromString("22222222-2222-2222-2222-222222222222")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Marienplatz München"),
    dropoffLocation = Location("Olympiapark München"),
    pickupDateTime = Instant.now().plusSeconds(86400),
    scheduledTime = Some(Instant.now().plusSeconds(86400))
  )

  private val testRideInProgress = Ride(
    id = RideId(UUID.fromString("33333333-3333-3333-3333-333333333333")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    driverId = Some(testPersonId10),
    status = RideStatus.InProgress,
    pickupLocation = Location("Sendlinger Tor München"),
    dropoffLocation = Location("BMW Welt München"),
    pickupDateTime = Instant.now().minusSeconds(600),
    scheduledTime = Some(Instant.now().minusSeconds(600)),
    startTime = Some(Instant.now().minusSeconds(600))
  )

  private val testRideCompleted = Ride(
    id = RideId(UUID.fromString("44444444-4444-4444-4444-444444444444")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    driverId = Some(testPersonId10),
    status = RideStatus.Completed,
    pickupLocation = Location("Englischer Garten München"),
    dropoffLocation = Location("Viktualienmarkt München"),
    pickupDateTime = Instant.now().minusSeconds(7200),
    scheduledTime = Some(Instant.now().minusSeconds(7200)),
    startTime = Some(Instant.now().minusSeconds(7200)),
    endTime = Some(Instant.now().minusSeconds(3600))
  )

  // Extra rides for extended tests — not touched by 02_ride_management
  private val testRideAssigned2 = Ride(
    id = RideId(UUID.fromString("55555555-5555-5555-5555-555555555555")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    driverId = Some(testPersonId10),
    status = RideStatus.Assigned,
    pickupLocation = Location("Rosenheimer Platz München"),
    dropoffLocation = Location("Ostbahnhof München"),
    pickupDateTime = Instant.now().plusSeconds(172800),
    scheduledTime = Some(Instant.now().plusSeconds(172800))
  )

  private val testRideRequested2 = Ride(
    id = RideId(UUID.fromString("66666666-6666-6666-6666-666666666666")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Karlsplatz München"),
    dropoffLocation = Location("Gasteig München"),
    pickupDateTime = Instant.now().plusSeconds(259200),
    scheduledTime = Some(Instant.now().plusSeconds(259200))
  )

  // Dedicated ride for 09_frontend assign test — not used by any other test
  private val testRideRequested3 = Ride(
    id = RideId(UUID.fromString("77777777-7777-7777-7777-777777777777")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Odeonsplatz München"),
    dropoffLocation = Location("Nymphenburg München"),
    pickupDateTime = Instant.now().plusSeconds(345600),
    scheduledTime = Some(Instant.now().plusSeconds(345600))
  )

  // Dedicated rides for 37_dispatcher_can_drive — each scenario uses its own ride
  // so that one assignment does not affect the other.
  private val testRideForDispDrvAssign = Ride(
    id = RideId(UUID.fromString("d5d5d5d5-d5d5-d5d5-d5d5-d5d5d5d5d5d5")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Stachus München"),
    dropoffLocation = Location("Maxvorstadt München"),
    pickupDateTime = Instant.now().plusSeconds(604800),
    scheduledTime = Some(Instant.now().plusSeconds(604800))
  )

  private val testRideForPureDispAssign = Ride(
    id = RideId(UUID.fromString("d6d6d6d6-d6d6-d6d6-d6d6-d6d6d6d6d6d6")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Schwabing München"),
    dropoffLocation = Location("Bogenhausen München"),
    pickupDateTime = Instant.now().plusSeconds(604800),
    scheduledTime = Some(Instant.now().plusSeconds(604800))
  )

  // Dedicated ride for 33_security — stays Requested throughout all tests
  private val testRideRequested4 = Ride(
    id = RideId(UUID.fromString("88888888-8888-8888-8888-888888888888")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    status = RideStatus.Requested,
    pickupLocation = Location("Theresienwiese München"),
    dropoffLocation = Location("Hackerbrücke München"),
    pickupDateTime = Instant.now().plusSeconds(432000),
    scheduledTime = Some(Instant.now().plusSeconds(432000))
  )

  // Dedicated ride for 34_airport_checkpoints — InProgress + ArrivalAirportTransfer
  // isArrival is encoded in AirportTransfer.isArrival, not the flightIsArrival column.
  private val testRideAirportCheckpoint = Ride(
    id = RideId(UUID.fromString("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")),
    clientId = testPersonId1,
    creatorId = testPersonId33,
    companyId = testCompanyId1,
    driverId = Some(testPersonId10),
    status = RideStatus.InProgress,
    pickupLocation = Location("MUC Terminal 1"),
    dropoffLocation = Location("München Hauptbahnhof"),
    pickupDateTime = Instant.now().minusSeconds(1200),
    scheduledTime = Some(Instant.now().minusSeconds(1200)),
    startTime = Some(Instant.now().minusSeconds(1200)),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH456", isArrival = true))
  )

  private def rideSeed: Map[RideId, Ride] = Map[RideId, Ride](
    testRideId                   -> testRideAssigned,
    testRideRequested.id         -> testRideRequested,
    testRideInProgress.id        -> testRideInProgress,
    testRideCompleted.id         -> testRideCompleted,
    testRideAssigned2.id         -> testRideAssigned2,
    testRideRequested2.id        -> testRideRequested2,
    testRideRequested3.id        -> testRideRequested3,
    testRideRequested4.id        -> testRideRequested4,
    testRideAirportCheckpoint.id -> testRideAirportCheckpoint,
    testRideForDispDrvAssign.id  -> testRideForDispDrvAssign,
    testRideForPureDispAssign.id -> testRideForPureDispAssign
  )

  private val inMemoryRideRepositoryLayer: ZLayer[Any, Nothing, RideRepository] = ZLayer.fromZIO(
    Ref.Synchronized
      .make(rideSeed)
      .map { ridesRef =>
        registerReset(ridesRef.set(rideSeed))
        new RideRepository:
          def create(ride: Ride): Task[Ride]                                                                    =
            val r = ride.copy(id = RideId.generate())
            ridesRef.update(_.updated(r.id, r)).as(r)
          def findById(id: RideId): Task[Option[Ride]]                                                          = ridesRef.get.map(_.get(id))
          def update(ride: Ride): Task[Ride]                                                                    = ridesRef.update(_.updated(ride.id, ride)).as(ride)
          def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                      = ridesRef.modify { m =>
            m.get(ride.id) match
              case Some(c) if expectedStatuses.contains(c.status) => (true, m.updated(ride.id, ride))
              case _                                              => (false, m)
          }
          def findByClientId(cid: PersonId): Task[List[Ride]]                                                   = ridesRef.get
            .map(_.values.filter(_.clientId == cid).toList)
          def findByDriverId(did: PersonId): Task[List[Ride]]                                                   = ridesRef.get
            .map(_.values.filter(_.driverId.contains(did)).toList)
          def findByDriverIdAndCompany(did: PersonId, cid: CompanyId): Task[List[Ride]]                         = ridesRef.get
            .map(_.values.filter(r => r.driverId.contains(did) && r.companyId == cid).toList)
          def findByClientIdAndCompany(clid: PersonId, cid: CompanyId): Task[List[Ride]]                        = ridesRef.get
            .map(_.values.filter(r => r.clientId == clid && r.companyId == cid).toList)
          def findByStatus(s: RideStatus): Task[List[Ride]]                                                     = ridesRef.get.map(_.values.filter(_.status == s).toList)
          def findByStatusAndCompany(s: RideStatus, cid: CompanyId): Task[List[Ride]]                           = ridesRef.get
            .map(_.values.filter(r => r.status == s && r.companyId == cid).toList)
          def findByCompanyId(cid: CompanyId): Task[List[Ride]]                                                 = ridesRef.get
            .map(_.values.filter(_.companyId == cid).toList)
          def findByCompanyIdPaginated(cid: CompanyId, offset: Int, limit: Int): Task[List[Ride]]               = ridesRef.get
            .map(_.values.filter(_.companyId == cid).toList.sortBy(_.requestTime).reverse.drop(offset).take(limit))
          def findByDriverIdPaginated(did: PersonId, offset: Int, limit: Int): Task[List[Ride]]                 = ridesRef.get
            .map(
              _.values.filter(_.driverId.contains(did)).toList.sortBy(_.requestTime).reverse.drop(offset).take(limit)
            )
          def findByDriverIdAndCompanyPaginated(
              did: PersonId,
              cid: CompanyId,
              offset: Int,
              limit: Int
          ): Task[List[Ride]] = ridesRef.get
            .map(
              _.values
                .filter(r => r.driverId.contains(did) && r.companyId == cid)
                .toList
                .sortBy(_.requestTime)
                .reverse
                .drop(offset)
                .take(limit)
            )
          def findAll(): Task[List[Ride]]                                                                       = ridesRef.get.map(_.values.toList)
          def delete(id: RideId, companyId: CompanyId): Task[Unit]                                              = ridesRef.update(_.removed(id)).unit
          def countByCompanyGroupedByStatus(cid: CompanyId): Task[Map[String, Int]]                             = ridesRef.get
            .map(_.values.filter(_.companyId == cid).groupBy(_.status.toString).map((k, v) => k -> v.size))
          def sumRevenueByCompany(cid: CompanyId): Task[BigDecimal]                                             = ridesRef.get.map(
            _.values
              .filter(r => r.companyId == cid && r.status == RideStatus.Completed)
              .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
              .sum
          )
          def sumTodayRevenueByCompany(cid: CompanyId): Task[BigDecimal]                                        =
            val start = java.time.LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant
            ridesRef.get.map(
              _.values
                .filter(r =>
                  r.companyId == cid && r.status == RideStatus.Completed && r.endTime.exists(!_.isBefore(start))
                )
                .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
                .sum
            )
          def avgAssignmentMinutesByCompany(cid: CompanyId): Task[Double]                                       = ridesRef.get.map { all =>
            val assigned = all.values.filter(r => r.companyId == cid && r.driverId.isDefined && r.startTime.isDefined)
            if assigned.isEmpty then 0.0
            else
              assigned
                .map(r => java.time.Duration.between(r.requestTime, r.startTime.get).toMinutes.toDouble)
                .sum / assigned.size
          }
          def countDailyStatsByCompany(cid: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]          =
            val cutoff = Instant.now().minusSeconds(days.toLong * 86400)
            ridesRef.get.map(
              _.values
                .filter(r => r.companyId == cid && r.requestTime.isAfter(cutoff))
                .groupBy(r => r.requestTime.atZone(ZoneOffset.UTC).toLocalDate.toString)
                .map { case (d, rs) =>
                  (d, rs.size, rs.count(_.status == RideStatus.Completed), rs.count(_.status == RideStatus.Cancelled))
                }
                .toList
                .sortBy(_._1)
            )
          def earningsByDriver(did: PersonId, cid: CompanyId, from: Instant, to: Instant): Task[DriverEarnings] =
            ridesRef.get.map { all =>
              val inScope = all.values.filter(r =>
                r.driverId.contains(did) && r.companyId == cid && !periodTime(r).isBefore(from) && periodTime(r)
                  .isBefore(to)
              )
              DriverEarnings(
                inScope
                  .filter(_.status == RideStatus.Completed)
                  .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
                  .sum,
                inScope.count(_.status == RideStatus.Completed),
                inScope.count(_.status == RideStatus.Cancelled)
              )
            }
          def earningsBucketsByDriver(did: PersonId, cid: CompanyId, from: Instant, to: Instant, bucket: TimeBucket)
              : Task[List[(Instant, BigDecimal)]] = ridesRef.get.map { all =>
            def trunc(t: Instant): Instant =
              val zdt = t.atZone(ZoneOffset.UTC)
              (bucket match
                case TimeBucket.Hour => zdt.truncatedTo(java.time.temporal.ChronoUnit.HOURS)
                case TimeBucket.Day  => zdt.toLocalDate.atStartOfDay(ZoneOffset.UTC)
              ).toInstant
            all.values
              .filter(r =>
                r.driverId.contains(did) && r.companyId == cid && r.status == RideStatus.Completed && !periodTime(r)
                  .isBefore(from) && periodTime(r).isBefore(to)
              )
              .groupBy(r => trunc(periodTime(r)))
              .view
              .mapValues(_.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).sum)
              .toList
              .sortBy(_._1)
          }
          def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                           = ridesRef.get.map(
            _.values
              .filter(r =>
                r.status == RideStatus.Assigned && r.scheduledTime.exists(t => !t.isBefore(from) && !t.isAfter(to))
              )
              .toList
          )
          def clearReminders(id: RideId): Task[Unit]                                                            = ZIO.unit
          // Platform-level analytics (SuperAdmin) — stub implementations
          def countAllRidesByStatus(): Task[Map[String, Int]]                                                   = ridesRef.get
            .map(_.values.groupBy(_.status.toString).map((k, v) => k -> v.size))
          def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                       = ridesRef.get.map(
            _.values
              .filter(r =>
                r.status == RideStatus.Completed && r.endTime.exists(t => !t.isBefore(from) && !t.isAfter(to))
              )
              .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
              .sum
          )
          def countRidesByCompany(from: Instant, to: Instant): Task[Map[java.util.UUID, Int]]                   = ridesRef.get.map(
            _.values
              .filter(r => !r.requestTime.isBefore(from) && !r.requestTime.isAfter(to))
              .groupBy(_.companyId.value)
              .map((k, v) => k -> v.size)
          )
          def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[java.util.UUID, BigDecimal]]    =
            ridesRef.get.map(
              _.values
                .filter(r =>
                  r.status == RideStatus.Completed && r.endTime.exists(t => !t.isBefore(from) && !t.isAfter(to))
                )
                .groupBy(_.companyId.value)
                .map((k, v) => k -> v.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).sum)
            )
          def updateCheckpoint(id: RideId, checkpoint: AirportCheckpoint): Task[Boolean]                        = ridesRef.modify { m =>
            m.get(id) match
              case None       => (false, m)
              case Some(ride) =>
                val currentOrdinal = ride.airportCheckpoint.map(_.ordinal).getOrElse(-1)
                if checkpoint.ordinal > currentOrdinal then
                  (true, m.updated(id, ride.copy(airportCheckpoint = Some(checkpoint))))
                else (false, m)
          }
          private def periodTime(r: Ride): Instant                                                              = r.endTime.getOrElse(r.pickupDateTime)
      }
  )

  private val testClientAddressId = ClientAddressId(UUID.fromString("22222222-2222-2222-2222-222222222222"))

  private val testClientAddress = ClientAddress(
    id = testClientAddressId,
    clientId = testPersonId1,
    label = "Home",
    address = "Leopoldstraße 1, Munich"
  )

  private def clientAddressSeed: Map[ClientAddressId, ClientAddress] = Map(testClientAddressId -> testClientAddress)

  private val inMemoryClientAddressRepositoryLayer: ZLayer[Any, Nothing, ClientAddressRepository] = ZLayer.succeed {
    new ClientAddressRepository:
      private val store                                                                       = new ConcurrentHashMap[ClientAddressId, ClientAddress](clientAddressSeed.asJava)
      registerReset(ZIO.succeed { store.clear(); store.putAll(clientAddressSeed.asJava) })
      def findByClient(clientId: PersonId): Task[List[ClientAddress]]                         = ZIO.succeed(
        store.values.asScala.filter(_.clientId == clientId).toList
      )
      def save(address: ClientAddress): Task[ClientAddress]                                   = ZIO.succeed { store.put(address.id, address); address }
      def incrementUseCount(id: ClientAddressId): Task[Unit]                                  = ZIO.succeed(
        Option(store.get(id)).foreach(a => store.put(id, a.copy(useCount = a.useCount + 1)))
      )
      def delete(id: ClientAddressId, clientId: PersonId): Task[Boolean]                      = ZIO.succeed(Option(store.get(id)) match {
        case Some(a) if a.clientId == clientId => store.remove(id); true; case _ => false
      })
      def findByAddressText(clientId: PersonId, address: String): Task[Option[ClientAddress]] = ZIO.succeed(
        store.values.asScala.find(a => a.clientId == clientId && a.address == address)
      )
      def updateLabelAndAliases(
          id: ClientAddressId,
          clientId: PersonId,
          label: Option[String],
          aliases: Option[List[String]]
      ): Task[Option[ClientAddress]] = ZIO.succeed(Option(store.get(id)).filter(_.clientId == clientId).map { a =>
        val u = a.copy(label = label.getOrElse(a.label), aliases = aliases.getOrElse(a.aliases)); store.put(id, u); u
      })
  }

  private val inMemoryScheduleDayRepositoryLayer: ZLayer[Any, Nothing, ScheduleDayRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(Map.empty[ScheduleDayId, ScheduleDay]).map { store =>
      registerReset(store.set(Map.empty[ScheduleDayId, ScheduleDay]))
      new ScheduleDayRepository:
        def create(scheduleDay: ScheduleDay): Task[ScheduleDay]                                                      = store.get.flatMap { current =>
          if current.values.exists(d => d.driverId == scheduleDay.driverId && d.date == scheduleDay.date)
          then ZIO.fail(ScheduleError.DuplicateScheduleDay(scheduleDay.driverId, scheduleDay.date))
          else store.update(_.updated(scheduleDay.id, scheduleDay)).as(scheduleDay)
        }
        def findById(id: ScheduleDayId): Task[Option[ScheduleDay]]                                                   = store.get.map(_.get(id))
        def findByDriverId(driverId: PersonId): Task[List[ScheduleDay]]                                              = store.get
          .map(_.values.filter(_.driverId == driverId).toList.sortBy(_.date))
        def findByDriverAndDate(driverId: PersonId, date: LocalDate): Task[Option[ScheduleDay]]                      = store.get
          .map(_.values.find(d => d.driverId == driverId && d.date == date))
        def findByCompanyAndDate(companyId: CompanyId, date: LocalDate): Task[List[ScheduleDay]]                     = store.get
          .map(_.values.filter(d => d.companyId == companyId && d.date == date).toList.sortBy(_.startTime))
        def findByCompanyAndDateRange(companyId: CompanyId, from: LocalDate, to: LocalDate): Task[List[ScheduleDay]] =
          store.get.map(
            _.values
              .filter(d => d.companyId == companyId && !d.date.isBefore(from) && !d.date.isAfter(to))
              .toList
              .sortBy(d => (d.date, d.startTime))
          )
        def update(scheduleDay: ScheduleDay): Task[ScheduleDay]                                                      = store
          .update(_.updated(scheduleDay.id, scheduleDay))
          .as(scheduleDay)
        def delete(id: ScheduleDayId, companyId: CompanyId): Task[Unit]                                              = store.update(_.removed(id)).unit
    }
  )

  private val testBillingClientCompanyId = ClientCompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testBillingClientCompany = ClientCompany(
    id = testBillingClientCompanyId,
    name = "Test BMW AG",
    taxiCompanyId = testCompanyId1,
    email = Some("billing@bmw.de"),
    phone = Some("+4989382-0"),
    address = Some("Petuelring 130, 80788 München")
  )

  private def billingSeed: Map[ClientCompanyId, ClientCompany] = Map(
    testBillingClientCompanyId -> testBillingClientCompany
  )

  private val inMemoryBillingClientCompanyRepositoryLayer: ZLayer[Any, Nothing, BillingClientCompanyRepository] = ZLayer
    .succeed {
      new BillingClientCompanyRepository:
        private val store                                                                          = new ConcurrentHashMap[ClientCompanyId, ClientCompany](billingSeed.asJava)
        registerReset(ZIO.succeed { store.clear(); store.putAll(billingSeed.asJava) })
        def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                             = ZIO.succeed(Option(store.get(id)))
        def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]                 = ZIO.succeed(
          store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).toList
        )
        def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany] =
          val cc = ClientCompany(
            ClientCompanyId(UUID.randomUUID()),
            req.name,
            taxiCompanyId,
            req.email,
            req.phone,
            req.address
          )
          ZIO.succeed { store.put(cc.id, cc); cc }
        def update(
            id: ClientCompanyId,
            taxiCompanyId: CompanyId,
            req: CreateClientCompanyRequest
        ): Task[Option[ClientCompany]] = ZIO.succeed(
          Option(store.get(id)).filter(_.taxiCompanyId == taxiCompanyId).map { old =>
            val updated = old.copy(name = req.name, email = req.email, phone = req.phone, address = req.address)
            store.put(id, updated); updated
          }
        )
        def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean]                   = ZIO.succeed(
          Option(store.get(id)).exists(_.taxiCompanyId == taxiCompanyId) && {
            store.remove(id); true
          }
        )
    }

  private val testInvoiceId = InvoiceId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testInvoice = Invoice(
    id = testInvoiceId,
    number = "INV-2026-001",
    clientCompanyId = testBillingClientCompanyId,
    taxiCompanyId = testCompanyId1,
    status = com.shevchyk.billing.domain.InvoiceStatus.Sent,
    periodFrom = java.time.LocalDate.of(2026, 6, 1),
    periodTo = java.time.LocalDate.of(2026, 6, 30),
    subtotalAmount = BigDecimal("100.00"),
    taxRate = BigDecimal("0.19"),
    taxAmount = BigDecimal("19.00"),
    totalAmount = BigDecimal("119.00")
  )

  private def invoiceSeed: Map[InvoiceId, Invoice] = Map(testInvoiceId -> testInvoice)

  private val inMemoryInvoiceRepositoryLayer: ZLayer[Any, Nothing, InvoiceRepository] = ZLayer.succeed {
    new InvoiceRepository:
      private val store                                                                                      = new ConcurrentHashMap[InvoiceId, Invoice](invoiceSeed.asJava)
      private val itemsStore                                                                                 = new ConcurrentHashMap[InvoiceId, List[InvoiceItem]]()
      registerReset(ZIO.succeed { store.clear(); store.putAll(invoiceSeed.asJava); itemsStore.clear() })
      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]                               = ZIO.succeed(
        s"INV-$year-${UUID.randomUUID().toString.take(8)}"
      )
      def create(invoice: Invoice): Task[Invoice]                                                            = ZIO.succeed { store.put(invoice.id, invoice); invoice }
      def findById(id: InvoiceId): Task[Option[Invoice]]                                                     = ZIO.succeed(Option(store.get(id)))
      def findByCompany(
          taxiCompanyId: CompanyId,
          status: Option[com.shevchyk.billing.domain.InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[Invoice]] = ZIO.succeed(
        store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).drop(offset).take(limit).toList
      )
      def update(invoice: Invoice): Task[Invoice]                                                            = ZIO.succeed { store.put(invoice.id, invoice); invoice }
      def delete(id: InvoiceId, taxiCompanyId: CompanyId): Task[Boolean]                                     = ZIO.succeed(
        Option(store.get(id)).exists(_.taxiCompanyId == taxiCompanyId) && {
          store.remove(id); true
        }
      )
      def addItems(items: List[InvoiceItem]): Task[Unit]                                                     = ZIO.succeed(
        items.groupBy(_.invoiceId).foreach((k, v) => itemsStore.put(k, v))
      )
      def deleteItems(invoiceId: InvoiceId): Task[Unit]                                                      = ZIO.succeed(itemsStore.remove(invoiceId))
      def replaceItems(invoiceId: InvoiceId, taxiCompanyId: CompanyId, items: List[InvoiceItem]): Task[Unit] = ZIO
        .succeed {
          if items.isEmpty then itemsStore.remove(invoiceId) else itemsStore.put(invoiceId, items)
          ()
        }
      def unlinkRides(invoiceId: InvoiceId, taxiCompanyId: CompanyId): Task[Unit]                            = ZIO.unit
      def findUnbilledRides(
          clientCompanyId: ClientCompanyId,
          from: java.time.LocalDate,
          to: java.time.LocalDate
      ): Task[List[UnbilledRide]] = ZIO.succeed(Nil)
      def findBillableRides(
          taxiCompanyId: CompanyId,
          clientCompanyId: ClientCompanyId,
          from: Option[java.time.LocalDate],
          to: Option[java.time.LocalDate]
      ): Task[List[UnbilledRide]] = ZIO.succeed(Nil)
      def findRidesByIds(taxiCompanyId: CompanyId, rideIds: List[UUID]): Task[List[UnbilledRide]]            = ZIO.succeed(Nil)
      def findOverdueUnpaid(now: java.time.Instant): Task[List[Invoice]]                                     = ZIO.succeed(Nil)
      def findRideForReceipt(taxiCompanyId: CompanyId, rideId: UUID): Task[Option[UnbilledRide]]             = ZIO.succeed(None)
      // Platform-level stubs (SuperAdmin only)
      def findAllPlatform(status: Option[InvoiceStatus], limit: Int, offset: Int): Task[List[Invoice]]       = ZIO.succeed(
        Nil
      )
      def sumRevenueByCompany(from: java.time.Instant, to: java.time.Instant): Task[Map[UUID, BigDecimal]]   = ZIO
        .succeed(Map.empty)
      def countOverdueByCompany(): Task[Map[UUID, Int]]                                                      = ZIO.succeed(Map.empty)
  }

  private val inMemoryCompanyBillingProfileRepositoryLayer: ZLayer[Any, Nothing, CompanyBillingProfileRepository] =
    ZLayer.succeed {
      new CompanyBillingProfileRepository:
        private val store                                                                                      = new ConcurrentHashMap[CompanyId, CompanyBillingProfile]()
        registerReset(ZIO.succeed(store.clear()))
        def findByCompany(companyId: CompanyId): Task[Option[CompanyBillingProfile]]                           = ZIO.succeed(
          Option(store.get(companyId))
        )
        def upsert(companyId: CompanyId, req: UpdateCompanyBillingProfileRequest): Task[CompanyBillingProfile] = ZIO
          .succeed {
            val p = CompanyBillingProfile(
              companyId = companyId,
              businessType = req.businessType,
              legalName = req.legalName,
              addressLine1 = req.addressLine1,
              addressLine2 = req.addressLine2,
              phone = req.phone,
              email = req.email,
              taxNumber = req.taxNumber,
              vatId = req.vatId,
              bankName = req.bankName,
              bankAccountNo = req.bankAccountNo,
              bankCode = req.bankCode,
              iban = req.iban,
              bic = req.bic,
              paymentTermsDays = req.paymentTermsDays.getOrElse(7),
              invoiceIntro = req.invoiceIntro
            )
            store.put(companyId, p)
            p
          }
    }

  private val inMemoryDriverLocationRepositoryLayer: ZLayer[Any, Nothing, DriverLocationRepository] = ZLayer.succeed {
    new DriverLocationRepository:
      private val locations                                                                   = new ConcurrentHashMap[PersonId, DriverLocation]()
      private val availability                                                                = new ConcurrentHashMap[PersonId, String]()
      registerReset(ZIO.succeed { locations.clear(); availability.clear() })
      def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] = ZIO.succeed(
        locations.put(driverId, DriverLocation(driverId, latitude, longitude))
      )
      def getLocation(driverId: PersonId): Task[Option[DriverLocation]]                       = ZIO.succeed(Option(locations.get(driverId)))
      def updateAvailability(driverId: PersonId, status: String): Task[Unit]                  = ZIO.succeed(
        availability.put(driverId, status)
      )
      def getAvailability(driverId: PersonId): Task[Option[String]]                           = ZIO.succeed(Option(availability.get(driverId)))
      def findAvailableByCompanyId(
          companyId: CompanyId
      ): Task[List[(PersonId, String, Option[Double], Option[Double])]] = ZIO.succeed(availability.asScala.map {
        case (id, s) => val l = Option(locations.get(id)); (id, s, l.map(_.latitude), l.map(_.longitude))
      }.toList)
  }

  private val noopHereRoutingServiceLayer: ZLayer[Any, Nothing, HereRoutingService] = ZLayer.succeed(
    new HereRoutingService:
      def getEtaMinutes(originLat: Double, originLng: Double, destLat: Double, destLng: Double): Task[Option[Int]] = ZIO
        .succeed(Some(10))
  )

  // Deterministic geocoder for BDD: resolves a few known Munich addresses to fixed coordinates
  // (so /api/rides/estimate can compute a fare from a free-text address with no coordinates) and
  // returns None for anything else (so the "address cannot be geocoded → 400" path stays covered).
  private val stubGeocodingServiceLayer: ZLayer[Any, Nothing, GeocodingService] = ZLayer.succeed(
    new GeocodingService:
      def geocode(address: String): Task[Option[(Double, Double)]] =
        val a      = address.toLowerCase
        val coords =
          if a.contains("marienplatz") then Some((48.1374, 11.5755))
          else if a.contains("airport") || a.contains("flughafen") then Some((48.3537, 11.7750))
          else None
        ZIO.succeed(coords)
  )

  private val inMemoryClientLocationRepositoryLayer: ZLayer[Any, Nothing, ClientLocationRepository] = ZLayer.succeed {
    new ClientLocationRepository:
      private val store                                                                                       = new ConcurrentHashMap[RideId, ClientLocation]()
      registerReset(ZIO.succeed(store.clear()))
      def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): Task[Unit] = ZIO
        .succeed(store.put(rideId, ClientLocation(rideId, clientId, latitude, longitude)))
      def getLocation(rideId: RideId): Task[Option[ClientLocation]]                                           = ZIO.succeed(Option(store.get(rideId)))
  }

  // ─── Seeded test RidePool ─────────────────────────────────────────────────

  private val testPoolId = RidePoolId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testPool = RidePool(
    id = testPoolId,
    companyId = testCompanyId1,
    name = Some("Test Pool"),
    status = PoolStatus.Open,
    createdBy = testPersonId33
  )

  private val inMemoryRidePoolRepositoryLayer: ZLayer[Any, Nothing, RidePoolRepository] = ZLayer.fromZIO(
    for {
      poolsRef   <- Ref.Synchronized.make(Map[RidePoolId, RidePool](testPoolId -> testPool))
      membersRef <- Ref.Synchronized.make(List.empty[RidePoolMember])
      _           = registerReset(
                      poolsRef.set(Map[RidePoolId, RidePool](testPoolId -> testPool)) *>
                        membersRef.set(List.empty[RidePoolMember])
                    )
    } yield new RidePoolRepository:
      def create(pool: RidePool): Task[RidePool]                                                          = poolsRef.update(_.updated(pool.id, pool)).as(pool)
      def findById(id: RidePoolId): Task[Option[RidePool]]                                                = poolsRef.get.map(_.get(id))
      def findByCompanyId(companyId: CompanyId): Task[List[RidePool]]                                     = poolsRef.get.map(
        _.values.filter(_.companyId == companyId).toList.sortBy(_.createdAt).reverse
      )
      def findOpenPools(companyId: CompanyId): Task[List[RidePool]]                                       = poolsRef.get.map(
        _.values.filter(p => p.companyId == companyId && p.status == PoolStatus.Open).toList
      )
      def update(pool: RidePool): Task[RidePool]                                                          = poolsRef.update(_.updated(pool.id, pool)).as(pool)
      def addMember(member: RidePoolMember): Task[RidePoolMember]                                         = membersRef.update(_ :+ member).as(member)
      def findMembersByPoolId(poolId: RidePoolId): Task[List[RidePoolMember]]                             = membersRef.get.map(
        _.filter(_.poolId == poolId).sortBy(_.pickupOrder)
      )
      def findPoolByRideId(rideId: RideId): Task[Option[RidePool]]                                        = membersRef.get.flatMap(ms =>
        poolsRef.get.map(ps => ms.find(_.rideId == rideId).flatMap(m => ps.get(m.poolId)))
      )
      def removeMember(poolId: RidePoolId, rideId: RideId): Task[Boolean]                                 = membersRef.modify { ms =>
        val before = ms.size; val after = ms.filterNot(m => m.poolId == poolId && m.rideId == rideId);
        (before > after.size, after)
      }
      def updateMemberStatus(poolId: RidePoolId, rideId: RideId, status: PoolMemberStatus): Task[Boolean] = membersRef
        .modify { ms =>
          var found   = false;
          val updated = ms.map { m =>
            if m.poolId == poolId && m.rideId == rideId then { found = true; m.copy(status = status) }
            else m
          }; (found, updated)
        }
  )

  // ─── Seeded test Session ──────────────────────────────────────────────────

  private val testSessionId = SessionId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testSession = Session(
    id = testSessionId,
    userId = testPersonId1,
    token = "valid-token-1",
    deviceInfo = Some("Test Browser"),
    ipAddress = Some("127.0.0.1"),
    createdAt = Instant.now(),
    lastActiveAt = Instant.now()
  )

  private val inMemorySessionRepositoryLayer: ZLayer[Any, Nothing, SessionRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(List[Session](testSession)).map { store =>
      registerReset(store.set(List[Session](testSession)))
      new SessionRepository:
        def create(s: Session): Task[Session]                                             = store.update(_ :+ s).as(s)
        def findByUserId(userId: PersonId): Task[List[Session]]                           = store.get
          .map(_.filter(s => s.userId == userId && s.isActive))
        def findByToken(token: String): Task[Option[Session]]                             = store.get
          .map(_.find(s => s.token == token && s.isActive))
        def updateLastActive(sessionId: SessionId): Task[Unit]                            =
          store.update(_.map(s => if s.id == sessionId then s.copy(lastActiveAt = Instant.now()) else s)).unit
        def deactivate(sessionId: SessionId): Task[Boolean]                               = store.modify { ss =>
          val updated = ss.map(s => if s.id == sessionId then s.copy(isActive = false) else s);
          (ss.exists(_.id == sessionId), updated)
        }
        def deactivateAllForUser(userId: PersonId): Task[Int]                             = store.modify { ss =>
          val updated = ss.map(s => if s.userId == userId then s.copy(isActive = false) else s);
          (ss.count(s => s.userId == userId && s.isActive), updated)
        }
        def deactivateAllExcept(userId: PersonId, currentSessionId: SessionId): Task[Int] = store.modify { ss =>
          val updated = ss.map(s =>
            if s.userId == userId && s.id != currentSessionId then s.copy(isActive = false) else s
          ); (ss.count(s => s.userId == userId && s.id != currentSessionId && s.isActive), updated)
        }
        def countActivePlatform(): Task[Int]                                              = store.get.map(_.count(_.isActive))
        def countActiveByCompany(companyId: CompanyId): Task[Int]                         = ZIO.succeed(0)
    }
  )

  // ─── Seeded test Expense ──────────────────────────────────────────────────

  private val testExpenseId = ExpenseId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testExpense = Expense(
    id = testExpenseId,
    rideId = Some(testRideId),
    driverId = testPersonId10,
    companyId = testCompanyId1,
    category = ExpenseCategory.Fuel,
    amount = BigDecimal("15.50"),
    description = Some("Refuel before ride")
  )

  private val inMemoryExpenseRepositoryLayer: ZLayer[Any, Nothing, ExpenseRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(Map[ExpenseId, Expense](testExpenseId -> testExpense)).map { store =>
      registerReset(store.set(Map[ExpenseId, Expense](testExpenseId -> testExpense)))
      new ExpenseRepository:
        def create(e: Expense): Task[Expense]                                                                   = store.update(_.updated(e.id, e)).as(e)
        def findById(id: ExpenseId): Task[Option[Expense]]                                                      = store.get.map(_.get(id))
        def findByRideId(rideId: RideId): Task[List[Expense]]                                                   = store.get
          .map(_.values.filter(_.rideId.contains(rideId)).toList)
        def findByDriverId(driverId: PersonId): Task[List[Expense]]                                             = store.get
          .map(_.values.filter(_.driverId == driverId).toList)
        def findByCompanyId(companyId: CompanyId): Task[List[Expense]]                                          = store.get
          .map(_.values.filter(_.companyId == companyId).toList)
        def delete(id: ExpenseId, companyId: CompanyId): Task[Boolean]                                          = store.modify { m =>
          m.get(id) match
            case Some(e) if e.companyId == companyId => (true, m.removed(id))
            case _                                   => (false, m)
        }
        def sumByDriver(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant): Task[BigDecimal] =
          store.get.map(
            _.values
              .filter(e =>
                e.driverId == driverId && e.companyId == companyId && !e.createdAt.isBefore(from) && e.createdAt
                  .isBefore(to)
              )
              .map(_.amount)
              .sum
          )
    }
  )

  // ─── Seeded test RideTemplate ─────────────────────────────────────────────

  private val testRideTemplateId = RideTemplateId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testRideTemplate = RideTemplate(
    id = testRideTemplateId,
    companyId = testCompanyId1,
    clientId = testPersonId1,
    creatorId = testPersonId33,
    name = "Test Template",
    fromAddress = "Hauptbahnhof München",
    toAddress = "Flughafen München",
    recurrencePattern = RecurrencePattern.WEEKDAYS,
    pickupTime = java.time.LocalTime.of(8, 0)
  )

  private val inMemoryRideTemplateRepositoryLayer: ZLayer[Any, Nothing, RideTemplateRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(Map[RideTemplateId, RideTemplate](testRideTemplateId -> testRideTemplate)).map { store =>
      registerReset(store.set(Map[RideTemplateId, RideTemplate](testRideTemplateId -> testRideTemplate)))
      new RideTemplateRepository:
        def create(t: RideTemplate): Task[RideTemplate]                           = store.update(_.updated(t.id, t)).as(t)
        def findById(id: RideTemplateId): Task[Option[RideTemplate]]              = store.get.map(_.get(id))
        def findByCompanyId(companyId: CompanyId): Task[List[RideTemplate]]       = store.get
          .map(_.values.filter(_.companyId == companyId).toList)
        def findActiveByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] = store.get
          .map(_.values.filter(t => t.companyId == companyId && t.isActive).toList)
        def update(t: RideTemplate): Task[RideTemplate]                           = store.update(_.updated(t.id, t)).as(t)
        def delete(id: RideTemplateId, companyId: CompanyId): Task[Boolean]       = store.modify { m =>
          m.get(id) match
            case Some(t) if t.companyId == companyId => (true, m.removed(id))
            case _                                   => (false, m)
        }
        def deactivate(id: RideTemplateId, companyId: CompanyId): Task[Boolean]   = store.modify { m =>
          m.get(id) match
            case Some(t) if t.companyId == companyId => (true, m.updatedWith(id)(_.map(_.copy(isActive = false))))
            case _                                   => (false, m)
        }
    }
  )

  // In-memory tariff repo seeded with the default tariff for the test company, so the
  // /estimate endpoint and ride pricing resolve a tariff without a DB.
  private val inMemoryTariffRepositoryLayer: ZLayer[Any, Nothing, TariffRepository] = ZLayer.succeed(
    InMemoryTariffRepository.withDefaults(testCompanyId1)
  )

  // ─── Seeded test Geofence ─────────────────────────────────────────────────

  private val testGeofenceId = GeofenceId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testGeofence = Geofence(
    id = testGeofenceId,
    companyId = testCompanyId1,
    name = "Airport Zone",
    geofenceType = GeofenceType.Airport,
    centerLatitude = 48.3537,
    centerLongitude = 11.7750,
    radiusMeters = 1000,
    isActive = true
  )

  private val inMemoryGeofenceRepositoryLayer: ZLayer[Any, Nothing, GeofenceRepository] = ZLayer.fromZIO(
    for {
      geofencesRef <- Ref.Synchronized.make(Map[GeofenceId, Geofence](testGeofenceId -> testGeofence))
      alertsRef    <- Ref.Synchronized.make(List.empty[GeofenceAlert])
      _             = registerReset(
                        geofencesRef.set(Map[GeofenceId, Geofence](testGeofenceId -> testGeofence)) *>
                          alertsRef.set(List.empty[GeofenceAlert])
                      )
    } yield new GeofenceRepository:
      def create(g: Geofence): Task[Geofence]                                              = geofencesRef.update(_.updated(g.id, g)).as(g)
      def findByCompanyId(companyId: CompanyId): Task[List[Geofence]]                      = geofencesRef.get.map(
        _.values.filter(_.companyId == companyId).toList
      )
      def findActiveByCompanyId(companyId: CompanyId): Task[List[Geofence]]                = geofencesRef.get.map(
        _.values.filter(g => g.companyId == companyId && g.isActive).toList
      )
      def findById(id: GeofenceId): Task[Option[Geofence]]                                 = geofencesRef.get.map(_.get(id))
      def update(g: Geofence): Task[Geofence]                                              = geofencesRef.update(_.updated(g.id, g)).as(g)
      def delete(id: GeofenceId, companyId: CompanyId): Task[Boolean]                      = geofencesRef.modify { m =>
        m.get(id) match
          case Some(g) if g.companyId == companyId => (true, m.removed(id))
          case _                                   => (false, m)
      }
      def saveAlert(alert: GeofenceAlert): Task[GeofenceAlert]                             = alertsRef.update(_ :+ alert).as(alert)
      def findAlertsByCompany(companyId: CompanyId, limit: Int): Task[List[GeofenceAlert]] = alertsRef.get.map(
        _.filter(_.companyId == companyId).sortBy(_.timestamp)(using Ordering[java.time.Instant].reverse).take(limit)
      )
      def findAlertsByDriver(driverId: PersonId, limit: Int): Task[List[GeofenceAlert]]    = alertsRef.get.map(
        _.filter(_.driverId == driverId).sortBy(_.timestamp)(using Ordering[java.time.Instant].reverse).take(limit)
      )
  )

  // ─── Seeded test Blacklist ────────────────────────────────────────────────

  private val testBlacklistEntryId = BlacklistEntryId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testBlacklistEntry = BlacklistEntry(
    id = testBlacklistEntryId,
    companyId = testCompanyId1,
    clientId = testPersonId50, // Client2 — not used in ride assign tests
    driverId = testPersonId10,
    reason = Some("Test entry"),
    createdBy = testPersonId99
  )

  private val inMemoryBlacklistRepositoryLayer: ZLayer[Any, Nothing, BlacklistRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(List[BlacklistEntry](testBlacklistEntry)).map { store =>
      registerReset(store.set(List[BlacklistEntry](testBlacklistEntry)))
      new BlacklistRepository:
        def create(entry: BlacklistEntry): Task[BlacklistEntry]                   = store
          .update(es => es.filterNot(e => e.clientId == entry.clientId && e.driverId == entry.driverId) :+ entry)
          .as(entry)
        def findByCompanyId(companyId: CompanyId): Task[List[BlacklistEntry]]     = store.get
          .map(_.filter(e => e.companyId == companyId && e.isActive))
        def findByClientId(clientId: PersonId): Task[List[BlacklistEntry]]        = store.get
          .map(_.filter(e => e.clientId == clientId && e.isActive))
        def findByDriverId(driverId: PersonId): Task[List[BlacklistEntry]]        = store.get
          .map(_.filter(e => e.driverId == driverId && e.isActive))
        def isBlacklisted(clientId: PersonId, driverId: PersonId): Task[Boolean]  = store.get
          .map(_.exists(e => e.clientId == clientId && e.driverId == driverId && e.isActive))
        def deactivate(id: BlacklistEntryId, companyId: CompanyId): Task[Boolean] = store.modify { es =>
          val idx = es.indexWhere(e => e.id == id && e.companyId == companyId);
          if idx >= 0 then (true, es.updated(idx, es(idx).copy(isActive = false))) else (false, es)
        }
        def delete(id: BlacklistEntryId): Task[Boolean]                           = store.modify { es =>
          val before = es.size; val after = es.filterNot(_.id == id); (before > after.size, after)
        }
    }
  )

  // ─── Seeded test Notification ────────────────────────────────────────────

  private val testNotificationId = AppNotificationId(UUID.fromString("11111111-1111-1111-1111-111111111111"))

  private val testNotification = AppNotification(
    id = testNotificationId,
    personId = testPersonId1,
    companyId = testCompanyId1,
    title = "Test Notification",
    body = "Your ride has been assigned",
    notificationType = "RIDE_ASSIGNED",
    isRead = false
  )

  private val inMemoryNotificationRepositoryLayer: ZLayer[Any, Nothing, NotificationRepository] = ZLayer.fromZIO(
    Ref.Synchronized.make(Map[AppNotificationId, AppNotification](testNotificationId -> testNotification)).map {
      store =>
        registerReset(store.set(Map[AppNotificationId, AppNotification](testNotificationId -> testNotification)))
        new NotificationRepository:
          def save(n: AppNotification): Task[AppNotification]                                          = store.update(_.updated(n.id, n)).as(n)
          def findByPersonId(personId: PersonId, limit: Int, offset: Int): Task[List[AppNotification]] = store.get.map(
            _.values
              .filter(_.personId == personId)
              .toList
              .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
              .drop(offset)
              .take(limit)
          )
          def markAsRead(id: AppNotificationId, personId: PersonId): Task[Boolean]                     = store.modify { m =>
            m.get(id).filter(_.personId == personId) match {
              case Some(n) => (true, m.updated(id, n.copy(isRead = true))); case None => (false, m)
            }
          }
          def markAllAsRead(personId: PersonId): Task[Unit]                                            =
            store
              .update(_.map { case (k, n) => if n.personId == personId then (k, n.copy(isRead = true)) else (k, n) })
              .unit
          def countUnread(personId: PersonId): Task[Int]                                               = store.get
            .map(_.values.count(n => n.personId == personId && !n.isRead))
          def delete(id: AppNotificationId, personId: PersonId): Task[Boolean]                         = store.modify { m =>
            val existed = m.get(id).exists(_.personId == personId)
            (existed, if existed then m.removed(id) else m)
          }
          def deleteAllForPerson(personId: PersonId): Task[Unit]                                       =
            store.update(_.filterNot((_, n) => n.personId == personId)).unit
    }
  )

  // ─── Resettable replacements for production *.inMemory layers ──────────────
  // These production layers start empty and only accumulate state; tests
  // mutate them across scenarios. We provide local, behaviour-identical
  // implementations that also register a reset (clear to the empty seed).

  private val resettableAuditServiceLayer: ZLayer[Any, Nothing, AuditService] = ZLayer.succeed {
    new AuditService:
      private val store                                                                           = new ConcurrentHashMap[AuditLogId, AuditLogEntry]()
      registerReset(ZIO.succeed(store.clear()))
      def log(entry: AuditLogEntry): Task[Unit]                                                   = ZIO.succeed { store.put(entry.id, entry); () }
      def findByEntity(entityType: String, entityId: UUID): Task[List[AuditLogEntry]]             = ZIO.succeed(
        store.values.asScala
          .filter(e => e.entityType == entityType && e.entityId == entityId)
          .toList
          .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
      )
      def findByCompany(companyId: CompanyId, limit: Int, offset: Int): Task[List[AuditLogEntry]] = ZIO.succeed(
        store.values.asScala
          .filter(_.companyId == companyId)
          .toList
          .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
          .drop(offset)
          .take(limit)
      )
  }

  private val resettableEmergencyRepositoryLayer: ZLayer[Any, Nothing, EmergencyReassignmentRepository] = ZLayer
    .fromZIO(
      Ref.Synchronized.make(List.empty[EmergencyReassignment]).map { store =>
        registerReset(store.set(List.empty[EmergencyReassignment]))
        new EmergencyReassignmentRepository:
          def create(reassignment: EmergencyReassignment): Task[EmergencyReassignment] = store
            .update(_ :+ reassignment)
            .as(reassignment)
          def findByCompanyId(companyId: CompanyId): Task[List[EmergencyReassignment]] = store.get.map(
            _.filter(_.companyId == companyId).sortBy(_.createdAt).reverse
          )
          def findByRideId(rideId: RideId): Task[List[EmergencyReassignment]]          = store.get
            .map(_.filter(_.rideId == rideId))
          def updateStatus(
              id: EmergencyReassignmentId,
              status: ReassignmentStatus,
              newDriverId: Option[PersonId]
          ): Task[Boolean] = store.modify { rs =>
            val idx = rs.indexWhere(_.id == id)
            if idx >= 0 then
              (
                true,
                rs.updated(idx, rs(idx).copy(status = status, newDriverId = newDriverId.orElse(rs(idx).newDriverId)))
              )
            else (false, rs)
          }
      }
    )

  private val resettableGdprRepositoryLayer: ZLayer[Any, Nothing, GdprRepository] = ZLayer.fromZIO(
    for {
      consentsRef <- Ref.Synchronized.make(List.empty[GdprConsent])
      requestsRef <- Ref.Synchronized.make(List.empty[GdprRequest])
      _            = registerReset(
                       consentsRef.set(List.empty[GdprConsent]) *> requestsRef.set(List.empty[GdprRequest])
                     )
    } yield new GdprRepository:
      def createConsent(consent: GdprConsent): Task[GdprConsent]                                  = consentsRef
        .update(cs => cs.filterNot(c => c.userId == consent.userId && c.consentType == consent.consentType) :+ consent)
        .as(consent)
      def findConsentsByUserId(userId: PersonId): Task[List[GdprConsent]]                         = consentsRef.get.map(
        _.filter(_.userId == userId)
      )
      def revokeConsent(userId: PersonId, consentType: ConsentType): Task[Boolean]                = consentsRef.modify { cs =>
        val idx = cs.indexWhere(c => c.userId == userId && c.consentType == consentType && c.revokedAt.isEmpty)
        if idx >= 0 then (true, cs.updated(idx, cs(idx).copy(revokedAt = Some(Instant.now())))) else (false, cs)
      }
      def createRequest(request: GdprRequest): Task[GdprRequest]                                  = requestsRef.update(_ :+ request).as(request)
      def findRequestsByUserId(userId: PersonId): Task[List[GdprRequest]]                         = requestsRef.get.map(
        _.filter(_.userId == userId)
      )
      def findAllRequests(companyId: CompanyId): Task[List[GdprRequest]]                          = requestsRef.get
      def updateRequestStatus(requestId: GdprRequestId, status: GdprRequestStatus): Task[Boolean] = requestsRef.modify {
        rs =>
          val idx = rs.indexWhere(_.id == requestId)
          if idx >= 0 then
            val completedAt = if status == GdprRequestStatus.COMPLETED then Some(Instant.now()) else None
            (true, rs.updated(idx, rs(idx).copy(status = status, completedAt = completedAt)))
          else (false, rs)
      }
  )

  private val resettableCompanySettingsRepositoryLayer: ZLayer[Any, Nothing, CompanySettingsRepository] = ZLayer
    .succeed {
      new CompanySettingsRepository:
        private val store                                                        = new ConcurrentHashMap[CompanyId, CompanySettings]()
        registerReset(ZIO.succeed(store.clear()))
        def findByCompanyId(companyId: CompanyId): Task[Option[CompanySettings]] = ZIO.succeed(
          Option(store.get(companyId))
        )
        def upsert(settings: CompanySettings): Task[CompanySettings]             = ZIO.succeed {
          store.put(settings.companyId, settings); settings
        }
    }

  private val resettableNotificationPreferenceRepositoryLayer: ZLayer[Any, Nothing, NotificationPreferenceRepository] =
    ZLayer.fromZIO(
      Ref.Synchronized.make(Map.empty[PersonId, NotificationPreference]).map { store =>
        registerReset(store.set(Map.empty[PersonId, NotificationPreference]))
        new NotificationPreferenceRepository:
          def findByPersonId(personId: PersonId): Task[Option[NotificationPreference]] = store.get.map(_.get(personId))
          def upsert(pref: NotificationPreference): Task[NotificationPreference]       = store
            .update(_.updated(pref.personId, pref))
            .as(pref)
      }
    )

  private val resettableChatMessageRepositoryLayer: ZLayer[Any, Nothing, ChatMessageRepository] = ZLayer.succeed {
    new ChatMessageRepository:
      private val store                                         = new ConcurrentHashMap[ChatMessageId, ChatMessage]()
      registerReset(ZIO.succeed(store.clear()))
      def save(message: ChatMessage): Task[ChatMessage]         = ZIO.succeed { store.put(message.id, message); message }
      def findByRideId(rideId: RideId): Task[List[ChatMessage]] = ZIO.succeed(
        store.values.asScala.filter(_.rideId == rideId).toList.sortBy(_.sentAt)
      )
  }

  // ─── Routes aggregation ───────────────────────────────────────────────────

  // Mount the same Tapir-described endpoints the production server uses
  // (com.shevchyk.app.openapi.OpenApiServer), so the test suite exercises the
  // real HTTP layer instead of the now-retired hand-written routes. Only the
  // health check and the WebSocket upgrade remain as plain zio-http routes.
  private val allRoutes =
    Routes(
      Method.GET / "health"          -> handler(Response.text("Dispax Modular API - OK")),
      // Test-only: reset all mutable in-memory state to the initial seed.
      // Called by the Cucumber @Before hook so every scenario starts clean.
      // This route exists ONLY in TestApplication, never in production.
      Method.POST / "test" / "reset" -> handler(resetAll.as(Response.status(Status.NoContent)))
    ) ++
      com.shevchyk.app.openapi.OpenApiServer.routes ++
      WebSocketRoutes.wsRoutes

  def run: ZIO[ZIOAppArgs, Any, Any] = ZIO
    .serviceWithZIO[ServerConfig] { _ =>
      ZIO.logInfo("Starting Dispax API Server (Test - In-Memory)...") *>
        Server.serve(
          allRoutes.handleError(err => Response(Status.InternalServerError, body = Body.fromString(err.toString)))
        )
    }
    .provide(
      ZLayer.service[ServerConfig] >>> ZLayer.fromFunction((config: ServerConfig) =>
        Server.Config.default.binding(config.host, config.port)
      ) >>> Server.live,
      ServerConfig.envPortLayer,
      ZLayer.succeed[PersonRepository](mockPersonRepository),
      ZLayer.succeed[TokenRepository](mockTokenRepository),
      JwtConfig.live,
      testJwtServiceLayer,
      AuthService.live,
      ZLayer.fromZIO(RateLimiter.make(maxRequests = 1000, windowSeconds = 60)),
      // Ride
      inMemoryRideRepositoryLayer,
      inMemoryExpenseRepositoryLayer,
      RideEstimateService.live,
      ZLayer.succeed[RideRatingRepository] {
        // Pre-seed a rating for the test ride
        val rating = RideRating(
          id = RideRatingId(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")),
          rideId = testRideId,
          clientId = testPersonId1,
          driverId = testPersonId10,
          companyId = testCompanyId1,
          rating = 5,
          comment = Some("Great ride!")
        )
        val seed   = Map(rating.id -> rating)
        val store  = new ConcurrentHashMap[RideRatingId, RideRating](seed.asJava)
        registerReset(ZIO.succeed { store.clear(); store.putAll(seed.asJava) })
        new RideRatingRepository:
          def create(r: RideRating): Task[RideRating]                                              = ZIO.succeed { store.put(r.id, r); r }
          def findByRideId(rideId: RideId): Task[Option[RideRating]]                               = ZIO
            .succeed(store.values.asScala.find(_.rideId == rideId))
          def findByDriverId(driverId: PersonId): Task[List[RideRating]]                           = ZIO
            .succeed(store.values.asScala.filter(_.driverId == driverId).toList)
          def getDriverAvgRating(driverId: PersonId): Task[Option[Double]]                         = ZIO.succeed {
            val rs = store.values.asScala.filter(_.driverId == driverId).map(_.rating).toList;
            if rs.isEmpty then None else Some(rs.sum.toDouble / rs.size)
          }
          def driverRatingStatsByCompany(companyId: CompanyId): Task[Map[PersonId, (Double, Int)]] = ZIO.succeed {
            store.values.asScala
              .filter(_.companyId == companyId)
              .groupBy(_.driverId)
              .map { case (d, rs) => val xs = rs.map(_.rating).toList; d -> (xs.sum.toDouble / xs.size, xs.size) }
              .toMap
          }
      },
      ClientAddressService.layer,
      inMemoryClientAddressRepositoryLayer,
      // DriverAvailabilityChecker: noop for tests (no unavailability windows set up by default)
      ZLayer.succeed[DriverAvailabilityChecker](
        new DriverAvailabilityChecker:
          def overlappingUnavailability(
              driverId: com.shevchyk.core.domain.PersonId,
              companyId: com.shevchyk.core.domain.CompanyId,
              from: java.time.Instant,
              to: java.time.Instant
          ): zio.Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
      ),
      RideService.layer,
      // Schedule
      inMemoryScheduleDayRepositoryLayer,
      ZLayer.fromZIO(
        Ref.Synchronized.make(Map.empty[PersonId, DriverScheduleVisibility]).map { store =>
          registerReset(store.set(Map.empty[PersonId, DriverScheduleVisibility]))
          new DriverScheduleVisibilityRepository:
            def findByDriver(driverId: PersonId): Task[Option[DriverScheduleVisibility]]     = store.get
              .map(_.get(driverId))
            def upsert(visibility: DriverScheduleVisibility): Task[DriverScheduleVisibility] = store
              .update(_.updated(visibility.driverId, visibility))
              .as(visibility)
            def findByCompany(companyId: CompanyId): Task[List[DriverScheduleVisibility]]    = store.get
              .map(_.values.filter(_.companyId == companyId).toList)
        }
      ),
      // DriverUnavailabilityRepository: in-memory for tests
      ZLayer.fromZIO(
        Ref.Synchronized.make(Map.empty[com.shevchyk.core.domain.DriverUnavailabilityId, DriverUnavailability]).map {
          store =>
            registerReset(store.set(Map.empty))
            new DriverUnavailabilityRepository:
              import com.shevchyk.core.domain.{DriverUnavailabilityId, PersonId, CompanyId}
              import java.time.Instant
              def create(u: DriverUnavailability): Task[DriverUnavailability]                              = store.update(_.updated(u.id, u)).as(u)
              def findById(id: DriverUnavailabilityId): Task[Option[DriverUnavailability]]                 = store.get.map(_.get(id))
              def findByDriver(driverId: PersonId, companyId: CompanyId): Task[List[DriverUnavailability]] = store.get
                .map(_.values.filter(u => u.driverId == driverId && u.companyId == companyId).toList.sortBy(_.fromTime))
              def findByCompanyAndRange(companyId: CompanyId, from: Instant, to: Instant)
                  : Task[List[DriverUnavailability]] = store.get.map(
                _.values
                  .filter(u => u.companyId == companyId && u.fromTime.isBefore(to) && from.isBefore(u.toTime))
                  .toList
                  .sortBy(_.fromTime)
              )
              def findOverlapping(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant)
                  : Task[List[DriverUnavailability]] = store.get.map(
                _.values
                  .filter(u =>
                    u.driverId == driverId && u.companyId == companyId && u.fromTime.isBefore(to) && from
                      .isBefore(u.toTime)
                  )
                  .toList
              )
              def delete(id: DriverUnavailabilityId, driverId: PersonId, companyId: CompanyId): Task[Unit] =
                store
                  .update(m =>
                    m.get(id)
                      .filter(u => u.driverId == driverId && u.companyId == companyId)
                      .fold(m)(_ => m.removed(id))
                  )
                  .unit
        }
      ),
      ScheduleSvc.layer,
      // Notification
      inMemoryNotificationRepositoryLayer,
      resettableNotificationPreferenceRepositoryLayer,
      resettableFcmServiceLayer,
      LoggingEmailSmsService.layer,
      // Core infra
      EventHub.layer,
      resettableAuditServiceLayer,
      inMemoryBlacklistRepositoryLayer,
      resettableEmergencyRepositoryLayer,
      inMemoryRidePoolRepositoryLayer,
      inMemorySessionRepositoryLayer,
      resettableGdprRepositoryLayer,
      resettableCompanySettingsRepositoryLayer,
      inMemoryGeofenceRepositoryLayer,
      GeofenceService.layer,
      stubGeocodingServiceLayer,
      // SuperAdmin CompanyRepository stub (platform-level; not exercised in BDD tests)
      ZLayer.succeed[CompanyRepository] {
        import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus, SubscriptionPlan}
        new CompanyRepository:
          def findAll(): Task[List[Company]]                   = ZIO.succeed(Nil)
          def findById(id: CompanyId): Task[Option[Company]]   = ZIO.succeed(None)
          def create(company: Company): Task[Company]          = ZIO.succeed(company)
          def update(company: Company): Task[Company]          = ZIO.succeed(company)
          def countByStatus(): Task[Map[CompanyStatus, Int]]   = ZIO.succeed(Map.empty)
          def softDelete(id: CompanyId): Task[Option[Company]] = ZIO.succeed(None)
      },
      // Core ClientCompanyRepository (used by ClientCompanyRoutes in api/) — seeded with test data
      ZLayer.succeed[ClientCompanyRepository] {
        val seeded = ClientCompany(
          testBillingClientCompanyId,
          "Test BMW AG",
          testCompanyId1,
          Some("billing@bmw.de"),
          Some("+4989382-0"),
          Some("Petuelring 130, 80788 München")
        )
        val ccSeed = Map(testBillingClientCompanyId -> seeded)
        new ClientCompanyRepository:
          private val store                                                          = new ConcurrentHashMap[ClientCompanyId, ClientCompany](ccSeed.asJava)
          registerReset(ZIO.succeed { store.clear(); store.putAll(ccSeed.asJava) })
          def findById(id: ClientCompanyId): Task[Option[ClientCompany]]             = ZIO.succeed(Option(store.get(id)))
          def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]] = ZIO
            .succeed(store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).toList)
          def create(company: ClientCompany): Task[ClientCompany]                    = ZIO.succeed {
            store.put(company.id, company); company
          }
          def update(company: ClientCompany): Task[ClientCompany]                    = ZIO.succeed {
            store.put(company.id, company); company
          }
          def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean]   = ZIO.succeed(
            Option(store.get(id)).exists(_.taxiCompanyId == taxiCompanyId) && {
              store.remove(id); true
            }
          )
      },
      // Billing
      inMemoryBillingClientCompanyRepositoryLayer,
      inMemoryInvoiceRepositoryLayer,
      inMemoryCompanyBillingProfileRepositoryLayer,
      InvoiceService.layer,
      // Airport configuration (global; no company_id) — minimal in-memory stub.
      // Pre-seeded with MUC so that AirportCheckpointService geofence checks work in BDD tests.
      ZLayer.fromZIO {
        val mucAirport = com.shevchyk.ride.domain.Airport(
          code = "MUC",
          name = "München Franz Josef Strauß",
          country = "DE",
          landingLat = 48.3537,
          landingLon = 11.7860,
          landingRadius = 2000,
          isActive = true,
          zones = Nil,
          createdAt = java.time.Instant.EPOCH,
          updatedAt = java.time.Instant.EPOCH
        )
        Ref.Synchronized.make(Map("MUC" -> mucAirport)).map { stateRef =>
          new AirportConfigRepository:
            import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
            def findAll(): Task[List[Airport]]                                                         = stateRef.get.map(_.values.toList)
            def findByCode(code: String): Task[Option[Airport]]                                        = stateRef.get.map(_.get(code))
            def create(airport: Airport): Task[Airport]                                                = stateRef.update(_.updated(airport.code, airport)).as(airport)
            def update(code: String, airport: Airport): Task[Option[Airport]]                          = stateRef.get.flatMap { m =>
              if m.contains(code) then
                stateRef.update(_.updated(code, airport.copy(code = code))).as(Some(airport.copy(code = code)))
              else ZIO.succeed(None)
            }
            def delete(code: String): Task[Boolean]                                                    = stateRef.get.flatMap { m =>
              m.get(code).filter(_.isActive) match
                case None    => ZIO.succeed(false)
                case Some(a) => stateRef.update(_.updated(code, a.copy(isActive = false))).as(true)
            }
            def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone]                   = stateRef.get.flatMap { m =>
              m.get(zone.airportCode) match
                case None    => ZIO.fail(new RuntimeException(s"Airport not found: ${zone.airportCode}"))
                case Some(a) =>
                  val z = zone.copy(id = UUID.randomUUID())
                  stateRef.update(_.updated(a.code, a.copy(zones = a.zones :+ z))).as(z)
            }
            def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] = stateRef.get
              .flatMap { m =>
                m.values.find(_.zones.exists(_.id == id)) match
                  case None    => ZIO.succeed(None)
                  case Some(a) =>
                    val updated = zone.copy(id = id, airportCode = a.code)
                    stateRef
                      .update(_.updated(a.code, a.copy(zones = a.zones.map(z => if z.id == id then updated else z))))
                      .as(Some(updated))
              }
            def deleteZone(id: UUID): Task[Boolean]                                                    = stateRef.get.flatMap { m =>
              m.values.find(_.zones.exists(_.id == id)) match
                case None    => ZIO.succeed(false)
                case Some(a) =>
                  stateRef.update(_.updated(a.code, a.copy(zones = a.zones.filterNot(_.id == id)))).as(true)
            }
        }
      } >>> AirportConfigService.layer,
      // Driver + location
      inMemoryDriverLocationRepositoryLayer,
      noopHereRoutingServiceLayer,
      DriverLocationService.layer,
      DriverLocationService.providerLayer,
      inMemoryClientLocationRepositoryLayer,
      AirportCheckpointService.layer,
      ClientLocationService.layer,
      // Chat + templates
      resettableChatMessageRepositoryLayer,
      ChatService.layer,
      inMemoryRideTemplateRepositoryLayer,
      inMemoryTariffRepositoryLayer,
      // Avatar
      AvatarService.layer
    )
