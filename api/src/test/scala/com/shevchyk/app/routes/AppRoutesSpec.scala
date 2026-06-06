package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EmailSmsService, EventHub, GeofenceService, RideConfirmationData}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.*
import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.ride.repository.{ExpenseRepository, RideRepository}
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

object AppRoutesSpec extends ZIOSpecDefault {

  // ─── JWT helpers ─────────────────────────────────────────────────────────────

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test",
      audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val dispatcherId: UUID = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val clientId: UUID     = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val companyId: UUID    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private def generateToken(role: PersonRole, uid: UUID = dispatcherId, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(uid),
          email = "test@example.com",
          name = "Test",
          role = role,
          passwordHash = "hash",
          companyId = cid.map(CompanyId.apply),
          status = UserStatus.ACTIVE
        )
      )
    )

  // ─── InMemory TokenRepository ─────────────────────────────────────────────

  private val inMemoryTokenRepository: ZLayer[Any, Nothing, TokenRepository] = ZLayer.succeed {
    new TokenRepository {
      private val store = new ConcurrentHashMap[String, UUID]()
      def create(token: String, userId: UUID): Task[Unit] = ZIO.succeed { store.put(token, userId) }
      def findUserIdByToken(token: String): Task[Option[UUID]] = ZIO.succeed(Option(store.get(token)))
      def deleteByToken(token: String): Task[Unit] = ZIO.succeed { store.remove(token) }
      def deleteByUserId(userId: UUID): Task[Unit] = ZIO.succeed {
        store.entrySet().asScala.filter(_.getValue == userId).foreach(e => store.remove(e.getKey))
      }
    }
  }

  // ─── Shared noop email/sms ───────────────────────────────────────────────

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
  )

  // ─── route runner helpers ─────────────────────────────────────────────────

  private def run[R](routes: zio.http.Routes[R, Response])(request: Request): ZIO[R, Nothing, Response] =
    routes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  private def bearer(token: String): Request => Request = _.addHeader(Header.Authorization.Bearer(token))

  // ═══════════════════════════════════════════════════════════════════════════
  // BlacklistRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val blacklistLayers = BlacklistRepository.inMemory ++ AuditService.inMemory ++ testJwtService

  private val blacklistSuite = suite("BlacklistRoutes")(
    test("returns 401 without auth header") {
      val request = Request.get(URL.decode("/api/blacklist").toOption.get)
      run(BlacklistRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(blacklistLayers),

    test("dispatcher can access blacklist (200)") {
      for {
        token    <- generateToken(PersonRole.Dispatcher)
        request   = bearer(token)(Request.get(URL.decode("/api/blacklist").toOption.get))
        response <- run(BlacklistRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(blacklistLayers),

    test("client cannot access blacklist (403)") {
      for {
        token    <- generateToken(PersonRole.Client, uid = clientId)
        request   = bearer(token)(Request.get(URL.decode("/api/blacklist").toOption.get))
        response <- run(BlacklistRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Forbidden)
    }.provide(blacklistLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════
  // CompanySettingsRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val settingsLayers = CompanySettingsRepository.inMemory ++ testJwtService

  private val companySettingsSuite = suite("CompanySettingsRoutes")(
    test("returns 401 without auth") {
      val request = Request.get(URL.decode("/api/company/settings").toOption.get)
      run(CompanySettingsRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(settingsLayers),

    test("dispatcher can get settings (200)") {
      for {
        token    <- generateToken(PersonRole.Dispatcher)
        request   = bearer(token)(Request.get(URL.decode("/api/company/settings").toOption.get))
        response <- run(CompanySettingsRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(settingsLayers),

    test("client cannot get settings (403)") {
      for {
        token    <- generateToken(PersonRole.Client, uid = clientId)
        request   = bearer(token)(Request.get(URL.decode("/api/company/settings").toOption.get))
        response <- run(CompanySettingsRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Forbidden)
    }.provide(settingsLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════
  // NotificationPreferenceRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val notifPrefLayers = NotificationPreferenceRepository.inMemory ++ testJwtService

  private val notifPrefSuite = suite("NotificationPreferenceRoutes")(
    test("returns 401 without auth") {
      val request = Request.get(URL.decode("/api/notification-preferences").toOption.get)
      run(NotificationPreferenceRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(notifPrefLayers),

    test("authenticated user can get preferences (200)") {
      for {
        token    <- generateToken(PersonRole.Driver)
        request   = bearer(token)(Request.get(URL.decode("/api/notification-preferences").toOption.get))
        response <- run(NotificationPreferenceRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(notifPrefLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════
  // SessionRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val sessionLayers = SessionRepository.inMemory ++ inMemoryTokenRepository ++ testJwtService

  private val sessionSuite = suite("SessionRoutes")(
    test("returns 401 without auth") {
      val request = Request.get(URL.decode("/api/sessions").toOption.get)
      run(SessionRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(sessionLayers),

    test("authenticated user can list sessions (200)") {
      for {
        token    <- generateToken(PersonRole.Driver)
        request   = bearer(token)(Request.get(URL.decode("/api/sessions").toOption.get))
        response <- run(SessionRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(sessionLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════
  // GeofenceRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val geofenceLayers =
    (GeofenceRepository.inMemory ++ EventHub.layer) >+> GeofenceService.layer ++ testJwtService

  private val geofenceSuite = suite("GeofenceRoutes")(
    test("returns 401 without auth") {
      val request = Request.get(URL.decode("/api/geofences").toOption.get)
      run(GeofenceRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(geofenceLayers),

    test("dispatcher can list geofences (200)") {
      for {
        token    <- generateToken(PersonRole.Dispatcher)
        request   = bearer(token)(Request.get(URL.decode("/api/geofences").toOption.get))
        response <- run(GeofenceRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(geofenceLayers),

    test("driver cannot access geofences (403)") {
      for {
        token    <- generateToken(PersonRole.Driver)
        request   = bearer(token)(Request.get(URL.decode("/api/geofences").toOption.get))
        response <- run(GeofenceRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Forbidden)
    }.provide(geofenceLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════
  // GdprRoutes
  // ═══════════════════════════════════════════════════════════════════════════

  private val noopRideRepository: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed {
    new RideRepository {
      def create(ride: Ride): Task[Ride] = ZIO.succeed(ride)
      def findById(id: RideId): Task[Option[Ride]] = ZIO.succeed(None)
      def findByStatus(status: RideStatus): Task[List[Ride]] = ZIO.succeed(Nil)
      def findAll(): Task[List[Ride]] = ZIO.succeed(Nil)
      def findByClientId(clientId: PersonId): Task[List[Ride]] = ZIO.succeed(Nil)
      def findByDriverId(driverId: PersonId): Task[List[Ride]] = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]] = ZIO.succeed(Nil)
      def update(ride: Ride): Task[Ride] = ZIO.succeed(ride)
      def delete(id: RideId): Task[Unit] = ZIO.unit
      def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]] = ZIO.succeed(Map.empty)
      def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]] = ZIO.succeed(Nil)
      def findByCompanyIdAndDateRange(companyId: CompanyId, from: java.time.Instant, to: java.time.Instant): Task[List[Ride]] = ZIO.succeed(Nil)
      def findActiveRideForDriver(driverId: PersonId): Task[Option[Ride]] = ZIO.succeed(None)
      def findCompletedByDateRange(companyId: CompanyId, from: java.time.Instant, to: java.time.Instant): Task[List[Ride]] = ZIO.succeed(Nil)
      def findByPoolId(poolId: RidePoolId): Task[List[Ride]] = ZIO.succeed(Nil)
      def findActiveRidesNearLocation(lat: Double, lng: Double, radiusMeters: Int, companyId: CompanyId): Task[List[Ride]] = ZIO.succeed(Nil)
      def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double] = ZIO.succeed(0.0)
      def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal] = ZIO.succeed(BigDecimal(0))
      def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal] = ZIO.succeed(BigDecimal(0))
      def earningsByDriver(
          driverId: PersonId,
          companyId: CompanyId,
          from: java.time.Instant,
          to: java.time.Instant
      ): Task[com.shevchyk.ride.domain.DriverEarnings] =
        ZIO.succeed(com.shevchyk.ride.domain.DriverEarnings(BigDecimal(0), 0, 0))
      def earningsBucketsByDriver(
          driverId: PersonId,
          companyId: CompanyId,
          from: java.time.Instant,
          to: java.time.Instant,
          bucket: com.shevchyk.ride.repository.TimeBucket
      ): Task[List[(java.time.Instant, BigDecimal)]] = ZIO.succeed(Nil)
      def findAssignedRidesInWindow(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]] = ZIO.succeed(Nil)
      def clearReminders(rideId: RideId): Task[Unit] = ZIO.unit
    }
  }

  private val noopPersonRepository: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed {
    new PersonRepository {
      def create(person: Person): Task[Person] = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]] = ZIO.succeed(None)
      def findByEmail(email: String): Task[Option[Person]] = ZIO.succeed(None)
      def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]] = ZIO.succeed(Nil)
      def update(person: Person): Task[Person] = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit] = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]] = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]] = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit] = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]] = ZIO.succeed(Nil)
    }
  }

  private val gdprLayers =
    GdprRepository.inMemory ++
    noopPersonRepository ++
    noopRideRepository ++
    ExpenseRepository.inMemory ++
    testJwtService

  private val gdprSuite = suite("GdprRoutes")(
    test("returns 401 without auth header on GET /api/gdpr/consents") {
      val request = Request.get(URL.decode("/api/gdpr/consents").toOption.get)
      run(GdprRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(gdprLayers),

    test("authenticated user can get consents") {
      for {
        token    <- generateToken(PersonRole.Client, uid = clientId, cid = Some(companyId))
        request   = bearer(token)(Request.get(URL.decode("/api/gdpr/consents").toOption.get))
        response <- run(GdprRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status == Status.Ok)
    }.provide(gdprLayers),

    test("returns 401 without auth on GET /api/gdpr/export") {
      val request = Request.get(URL.decode("/api/gdpr/export").toOption.get)
      run(GdprRoutes.authenticatedRoutes)(request).map(r => assertTrue(r.status == Status.Unauthorized))
    }.provide(gdprLayers),

    test("authenticated user can request GDPR export") {
      for {
        token    <- generateToken(PersonRole.Client, uid = clientId, cid = Some(companyId))
        request   = bearer(token)(Request.get(URL.decode("/api/gdpr/export").toOption.get))
        response <- run(GdprRoutes.authenticatedRoutes)(request)
      } yield assertTrue(response.status.code < 500)
    }.provide(gdprLayers)
  )

  // ═══════════════════════════════════════════════════════════════════════════

  def spec = suite("AppRoutes")(
    blacklistSuite,
    companySettingsSuite,
    notifPrefSuite,
    sessionSuite,
    geofenceSuite,
    gdprSuite
  )
}
