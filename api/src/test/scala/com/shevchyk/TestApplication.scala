package com.shevchyk

import com.shevchyk.app.routes.WebSocketRoutes
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
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
import com.shevchyk.core.application.{AuditService, EventHub, GeocodingService, GeofenceService}
import com.shevchyk.core.config.ServerConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.domain.{
  RidePool,
  RidePoolId,
  RidePoolMember,
  RidePoolMemberId,
  PoolStatus,
  PoolMemberStatus,
  Session,
  SessionId
}
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
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId}
import com.shevchyk.notification.repository.{
  CheckpointNotificationRepository,
  InMemoryCheckpointNotificationRepository,
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository
}
import com.shevchyk.driver.application.{DriverLocationService, EtaService, HereRoutingService}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideService
}
import com.shevchyk.ride.domain.{
  AirportCheckpoint,
  ClientAddress,
  ClientAddressId,
  ClientLocation,
  DriverEarnings,
  Expense,
  ExpenseCategory,
  ExpenseId,
  MucCheckpoints,
  RecurrencePattern,
  Ride,
  RideError,
  RideSpecifics,
  RideStatus,
  RideTemplate,
  RideTemplateId
}
import com.shevchyk.ride.domain.{RideRating, RideRatingId}
import com.shevchyk.ride.repository.{
  ChatMessageRepository,
  ClientAddressRepository,
  ClientLocationRepository,
  ExpenseRepository,
  InMemoryChatMessageRepository,
  RideRatingRepository,
  RideRepository,
  RideTemplateRepository,
  TimeBucket
}
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.domain.{ScheduleDay, ScheduleError}
import com.shevchyk.schedule.repository.ScheduleDayRepository
import org.mindrot.jbcrypt.BCrypt
import zio.*
import zio.http.*
import zio.json.*
import zio.logging.backend.SLF4J

import java.time.{Instant, LocalDate, ZoneOffset}
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object TestApplication extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private def hashPassword(password: String): String = BCrypt.hashpw(password, BCrypt.gensalt(12))

  private val testPersonId1  = PersonId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
  private val testPersonId50 = PersonId(UUID.fromString("50505050-5050-5050-5050-505050505050"))
  private val testPersonId10 = PersonId(UUID.fromString("10101010-1010-1010-1010-101010101010"))
  private val testPersonId99 = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
  private val testPersonId33 = PersonId(UUID.fromString("33333333-3333-3333-3333-333333333333"))
  private val testPersonId44 = PersonId(UUID.fromString("44444444-4444-4444-4444-444444444444"))
  private val testCompanyId1 = CompanyId(UUID.fromString("10101010-1010-1010-1010-101010101010"))

  private val mockPersonRepository: PersonRepository =
    new PersonRepository {
      private val people = Map[PersonId, Person](
        testPersonId1  -> Person(
          testPersonId1,
          "Test User",
          "test@example.com",
          PersonRole.Client,
          passwordHash = hashPassword("Password123"),
          phone = Some("+1234567890"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId50 -> Person(
          testPersonId50,
          "Client User",
          "client@example.com",
          PersonRole.Client,
          passwordHash = hashPassword("Password123"),
          phone = Some("+1111111111"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId10 -> Person(
          testPersonId10,
          "Driver User",
          "driver@example.com",
          PersonRole.Driver,
          passwordHash = hashPassword("Password123"),
          phone = Some("+2222222222"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId99 -> Person(
          testPersonId99,
          "Admin User",
          "admin@example.com",
          PersonRole.Admin,
          passwordHash = hashPassword("Password123"),
          phone = Some("+3333333333"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId33 -> Person(
          testPersonId33,
          "Dispatcher User",
          "dispatcher@example.com",
          PersonRole.Dispatcher,
          passwordHash = hashPassword("Password123"),
          phone = Some("+4444444444"),
          companyId = Some(testCompanyId1)
        ),
        testPersonId44 -> Person(
          testPersonId44,
          "Secretary User",
          "secretary@example.com",
          PersonRole.Secretary,
          passwordHash = hashPassword("Password123"),
          phone = Some("+5555555555"),
          companyId = Some(testCompanyId1)
        )
      )

      def create(person: Person): Task[Person]                                             = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                     = ZIO.succeed(people.get(id))
      def findByEmail(email: String): Task[Option[Person]]                                 = ZIO.succeed(people.values.find(_.email == email))
      def findByRole(role: PersonRole): Task[List[Person]]                                 = ZIO.succeed(people.values.filter(_.role == role).toList)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
        people.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList
      )
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                        = ZIO.succeed(
        people.values.filter(_.companyId.contains(companyId)).toList
      )
      def findAll(): Task[List[Person]]                                                    = ZIO.succeed(people.values.toList)
      def update(person: Person): Task[Person]                                             = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                 = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                             = ZIO.succeed(
        people.values.filter(_.status == status).toList
      )
      def searchByQuery(query: String): Task[List[Person]]                                 = ZIO.succeed(
        people.values
          .filter(p =>
            p.name.toLowerCase.contains(query.toLowerCase) || p.email.toLowerCase.contains(query.toLowerCase)
          )
          .toList
      )
      def updateLastLogin(id: PersonId): Task[Unit]                                        = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]        = ZIO.succeed(Nil)
    }

  private val mockTokenRepository: TokenRepository =
    new TokenRepository {
      private val tokens = Map[String, UUID](
        "valid-token-1"  -> testPersonId1.value,
        "valid-token-50" -> testPersonId50.value,
        "valid-token-10" -> testPersonId10.value,
        "valid-token-99" -> testPersonId99.value,
        "valid-token-33" -> testPersonId33.value,
        "valid-token-44" -> testPersonId44.value
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

  private val noopFcmServiceLayer: ZLayer[Any, Nothing, FcmService] =
    InMemoryFcmTokenRepository.layer >>> ZLayer {
      for tokenRepo <- ZIO.service[com.shevchyk.notification.repository.FcmTokenRepository]
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

  private val inMemoryRideRepositoryLayer: ZLayer[Any, Nothing, RideRepository] = ZLayer.fromZIO(
    Ref.Synchronized
      .make(
        Map[RideId, Ride](
          testRideId                   -> testRideAssigned,
          testRideRequested.id         -> testRideRequested,
          testRideInProgress.id        -> testRideInProgress,
          testRideCompleted.id         -> testRideCompleted,
          testRideAssigned2.id         -> testRideAssigned2,
          testRideRequested2.id        -> testRideRequested2,
          testRideRequested3.id        -> testRideRequested3,
          testRideRequested4.id        -> testRideRequested4,
          testRideAirportCheckpoint.id -> testRideAirportCheckpoint
        )
      )
      .map { ridesRef =>
        new RideRepository:
          def create(ride: Ride): Task[Ride]                                                                    =
            val r = ride.copy(id = RideId.generate())
            ridesRef.update(_.updated(r.id, r)).as(r)
          def findById(id: RideId): Task[Option[Ride]]                                                          = ridesRef.get.map(_.get(id))
          def update(ride: Ride): Task[Ride]                                                                    = ridesRef.update(_.updated(ride.id, ride)).as(ride)
          def findByClientId(cid: PersonId): Task[List[Ride]]                                                   = ridesRef.get
            .map(_.values.filter(_.clientId == cid).toList)
          def findByDriverId(did: PersonId): Task[List[Ride]]                                                   = ridesRef.get
            .map(_.values.filter(_.driverId.contains(did)).toList)
          def findByStatus(s: RideStatus): Task[List[Ride]]                                                     = ridesRef.get.map(_.values.filter(_.status == s).toList)
          def findByCompanyId(cid: CompanyId): Task[List[Ride]]                                                 = ridesRef.get
            .map(_.values.filter(_.companyId == cid).toList)
          def findAll(): Task[List[Ride]]                                                                       = ridesRef.get.map(_.values.toList)
          def delete(id: RideId): Task[Unit]                                                                    = ridesRef.update(_.removed(id)).unit
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

  private val inMemoryClientAddressRepositoryLayer: ZLayer[Any, Nothing, ClientAddressRepository] = ZLayer.succeed {
    new ClientAddressRepository:
      private val store                                                                       =
        new ConcurrentHashMap[ClientAddressId, ClientAddress](Map(testClientAddressId -> testClientAddress).asJava)
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
        def delete(id: ScheduleDayId): Task[Unit]                                                                    = store.update(_.removed(id)).unit
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

  private val inMemoryBillingClientCompanyRepositoryLayer: ZLayer[Any, Nothing, BillingClientCompanyRepository] = ZLayer
    .succeed {
      new BillingClientCompanyRepository:
        private val store                                                                             =
          new ConcurrentHashMap[ClientCompanyId, ClientCompany](
            Map(testBillingClientCompanyId -> testBillingClientCompany).asJava
          )
        def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                                = ZIO.succeed(Option(store.get(id)))
        def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]                    = ZIO.succeed(
          store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).toList
        )
        def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany]    =
          val cc = ClientCompany(
            ClientCompanyId(UUID.randomUUID()),
            req.name,
            taxiCompanyId,
            req.email,
            req.phone,
            req.address
          )
          ZIO.succeed { store.put(cc.id, cc); cc }
        def update(id: ClientCompanyId, req: CreateClientCompanyRequest): Task[Option[ClientCompany]] = ZIO.succeed(
          Option(store.get(id)).map { old =>
            val updated = old.copy(name = req.name, email = req.email, phone = req.phone, address = req.address)
            store.put(id, updated); updated
          }
        )
        def delete(id: ClientCompanyId): Task[Boolean]                                                = ZIO.succeed(Option(store.get(id)).isDefined && {
          store.remove(id); true
        })
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

  private val inMemoryInvoiceRepositoryLayer: ZLayer[Any, Nothing, InvoiceRepository] = ZLayer.succeed {
    new InvoiceRepository:
      private val store                                                                                      = new ConcurrentHashMap[InvoiceId, Invoice](Map(testInvoiceId -> testInvoice).asJava)
      private val itemsStore                                                                                 = new ConcurrentHashMap[InvoiceId, List[InvoiceItem]]()
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
      def delete(id: InvoiceId): Task[Boolean]                                                               = ZIO.succeed(Option(store.get(id)).isDefined && {
        store.remove(id); true
      })
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

  private val inMemoryClientLocationRepositoryLayer: ZLayer[Any, Nothing, ClientLocationRepository] = ZLayer.succeed {
    new ClientLocationRepository:
      private val store                                                                                       = new ConcurrentHashMap[RideId, ClientLocation]()
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
      new ExpenseRepository:
        def create(e: Expense): Task[Expense]                                                                   = store.update(_.updated(e.id, e)).as(e)
        def findById(id: ExpenseId): Task[Option[Expense]]                                                      = store.get.map(_.get(id))
        def findByRideId(rideId: RideId): Task[List[Expense]]                                                   = store.get
          .map(_.values.filter(_.rideId.contains(rideId)).toList)
        def findByDriverId(driverId: PersonId): Task[List[Expense]]                                             = store.get
          .map(_.values.filter(_.driverId == driverId).toList)
        def findByCompanyId(companyId: CompanyId): Task[List[Expense]]                                          = store.get
          .map(_.values.filter(_.companyId == companyId).toList)
        def update(e: Expense): Task[Expense]                                                                   = store.update(_.updated(e.id, e)).as(e)
        def delete(id: ExpenseId): Task[Boolean]                                                                = store.modify { m =>
          val existed = m.contains(id); (existed, m.removed(id))
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
      new RideTemplateRepository:
        def create(t: RideTemplate): Task[RideTemplate]                           = store.update(_.updated(t.id, t)).as(t)
        def findById(id: RideTemplateId): Task[Option[RideTemplate]]              = store.get.map(_.get(id))
        def findByCompanyId(companyId: CompanyId): Task[List[RideTemplate]]       = store.get
          .map(_.values.filter(_.companyId == companyId).toList)
        def findActiveByCompanyId(companyId: CompanyId): Task[List[RideTemplate]] = store.get
          .map(_.values.filter(t => t.companyId == companyId && t.isActive).toList)
        def update(t: RideTemplate): Task[RideTemplate]                           = store.update(_.updated(t.id, t)).as(t)
        def delete(id: RideTemplateId): Task[Boolean]                             = store.modify { m =>
          val existed = m.contains(id); (existed, m.removed(id))
        }
        def deactivate(id: RideTemplateId): Task[Boolean]                         = store.modify { m =>
          (m.contains(id), m.updatedWith(id)(_.map(_.copy(isActive = false))))
        }
    }
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
      def delete(id: GeofenceId): Task[Boolean]                                            = geofencesRef.modify { m =>
        val existed = m.contains(id); (existed, m.removed(id))
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
      new BlacklistRepository:
        def create(entry: BlacklistEntry): Task[BlacklistEntry]                  = store
          .update(es => es.filterNot(e => e.clientId == entry.clientId && e.driverId == entry.driverId) :+ entry)
          .as(entry)
        def findByCompanyId(companyId: CompanyId): Task[List[BlacklistEntry]]    = store.get
          .map(_.filter(e => e.companyId == companyId && e.isActive))
        def findByClientId(clientId: PersonId): Task[List[BlacklistEntry]]       = store.get
          .map(_.filter(e => e.clientId == clientId && e.isActive))
        def findByDriverId(driverId: PersonId): Task[List[BlacklistEntry]]       = store.get
          .map(_.filter(e => e.driverId == driverId && e.isActive))
        def isBlacklisted(clientId: PersonId, driverId: PersonId): Task[Boolean] = store.get
          .map(_.exists(e => e.clientId == clientId && e.driverId == driverId && e.isActive))
        def deactivate(id: BlacklistEntryId): Task[Boolean]                      = store.modify { es =>
          val idx = es.indexWhere(_.id == id);
          if idx >= 0 then (true, es.updated(idx, es(idx).copy(isActive = false))) else (false, es)
        }
        def delete(id: BlacklistEntryId): Task[Boolean]                          = store.modify { es =>
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

  // ─── Routes aggregation ───────────────────────────────────────────────────

  // Mount the same Tapir-described endpoints the production server uses
  // (com.shevchyk.app.openapi.OpenApiServer), so the test suite exercises the
  // real HTTP layer instead of the now-retired hand-written routes. Only the
  // health check and the WebSocket upgrade remain as plain zio-http routes.
  private val allRoutes =
    Routes(
      Method.GET / "health" -> handler(Response.text("Dispax Modular API - OK"))
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
        val store  = new ConcurrentHashMap[RideRatingId, RideRating](Map(rating.id -> rating).asJava)
        new RideRatingRepository:
          def create(r: RideRating): Task[RideRating]                      = ZIO.succeed { store.put(r.id, r); r }
          def findByRideId(rideId: RideId): Task[Option[RideRating]]       = ZIO
            .succeed(store.values.asScala.find(_.rideId == rideId))
          def findByDriverId(driverId: PersonId): Task[List[RideRating]]   = ZIO
            .succeed(store.values.asScala.filter(_.driverId == driverId).toList)
          def getDriverAvgRating(driverId: PersonId): Task[Option[Double]] = ZIO.succeed {
            val rs = store.values.asScala.filter(_.driverId == driverId).map(_.rating).toList;
            if rs.isEmpty then None else Some(rs.sum.toDouble / rs.size)
          }
      },
      ClientAddressService.layer,
      inMemoryClientAddressRepositoryLayer,
      RideService.layer,
      // Schedule
      inMemoryScheduleDayRepositoryLayer,
      ScheduleSvc.layer,
      // Notification
      inMemoryNotificationRepositoryLayer,
      NotificationPreferenceRepository.inMemory,
      noopFcmServiceLayer,
      LoggingEmailSmsService.layer,
      InMemoryCheckpointNotificationRepository.layer,
      // Core infra
      EventHub.layer,
      AuditService.inMemory,
      inMemoryBlacklistRepositoryLayer,
      EmergencyReassignmentRepository.inMemory,
      inMemoryRidePoolRepositoryLayer,
      inMemorySessionRepositoryLayer,
      GdprRepository.inMemory,
      CompanySettingsRepository.inMemory,
      inMemoryGeofenceRepositoryLayer,
      GeofenceService.layer,
      GeocodingService.noop,
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
        new ClientCompanyRepository:
          private val store                                                          =
            new ConcurrentHashMap[ClientCompanyId, ClientCompany](Map(testBillingClientCompanyId -> seeded).asJava)
          def findById(id: ClientCompanyId): Task[Option[ClientCompany]]             = ZIO.succeed(Option(store.get(id)))
          def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]] = ZIO
            .succeed(store.values.asScala.filter(_.taxiCompanyId == taxiCompanyId).toList)
          def create(company: ClientCompany): Task[ClientCompany]                    = ZIO.succeed {
            store.put(company.id, company); company
          }
          def update(company: ClientCompany): Task[ClientCompany]                    = ZIO.succeed {
            store.put(company.id, company); company
          }
          def delete(id: ClientCompanyId): Task[Boolean]                             = ZIO.succeed(Option(store.get(id)).isDefined && {
            store.remove(id); true
          })
      },
      // Billing
      inMemoryBillingClientCompanyRepositoryLayer,
      inMemoryInvoiceRepositoryLayer,
      inMemoryCompanyBillingProfileRepositoryLayer,
      InvoiceService.layer,
      // Driver + location
      inMemoryDriverLocationRepositoryLayer,
      noopHereRoutingServiceLayer,
      DriverLocationService.layer,
      DriverLocationService.providerLayer,
      inMemoryClientLocationRepositoryLayer,
      AirportCheckpointService.layer,
      ClientLocationService.layer,
      EtaService.layer,
      // Chat + templates
      InMemoryChatMessageRepository.layer,
      ChatService.layer,
      inMemoryRideTemplateRepositoryLayer
    )
