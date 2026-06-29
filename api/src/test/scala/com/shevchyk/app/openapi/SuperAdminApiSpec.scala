package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.repository.InvoiceRepository
import com.shevchyk.billing.domain.InvoiceStatus
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{CompanyRepository, SessionRepository}
import com.shevchyk.ride.repository.RideRepository
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

/**
 * CRITICAL — Negative tenant-isolation HTTP tests for the SuperAdmin escape hatch.
 *
 * Every handler in SuperAdminApi starts with `requireSuperAdmin(user)`. These tests verify the isolation invariant:
 *   - SuperAdmin JWT → 200 (escape hatch grants access)
 *   - Admin JWT → 403 (most privileged normal role must still be denied)
 *   - Dispatcher JWT → 403 (another normal role, denied)
 *   - no token → 401 (unauthenticated)
 *   - Admin with companyId=None (crafted edge-case) → 403 (role check is primary)
 *
 * Routes are exercised via ZioHttpInterpreter against in-memory stubs — no network I/O, no Testcontainers needed for
 * these HTTP-level checks.
 */
object SuperAdminApiSpec extends ZIOSpecDefault:

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

  private def generateToken(role: PersonRole, cid: Option[UUID]): ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = s"${role.toString.toLowerCase}@test.de",
          name = s"${role.toString} User",
          role = role,
          passwordHash = "hash",
          companyId = cid.map(CompanyId.apply),
          status = UserStatus.ACTIVE
        )
      )
    )

  private val testCompanyId = UUID.fromString("10101010-1010-1010-1010-101010101010")

  // A company pre-seeded in the stub so softDelete can return Some(...)
  private val knownCompany = Company(
    id = CompanyId(testCompanyId),
    name = "Test GmbH",
    email = "test@company.de",
    phone = "+491234567890",
    address = "Leopoldstraße 1, München",
    status = CompanyStatus.Active,
    subscriptionPlan = SubscriptionPlan.Free
  )

  // ---------------------------------------------------------------------------
  // In-memory repository stubs (minimal — just enough for the route to respond)
  // ---------------------------------------------------------------------------

  private val stubCompanyRepo: ZLayer[Any, Nothing, CompanyRepository] = ZLayer.succeed(
    new CompanyRepository:
      def findAll()                 = ZIO.succeed(Nil)
      def findById(id: CompanyId)   = ZIO.none
      def create(c: Company)        = ZIO.succeed(c)
      def update(c: Company)        = ZIO.succeed(c)
      def countByStatus()           = ZIO.succeed(Map.empty)
      // Returns the known company (Inactive) when the known testCompanyId is requested;
      // returns None (→ 404) for any other id — exercises both the 200 and 404 branches.
      def softDelete(id: CompanyId) =
        if id == CompanyId(testCompanyId)
        then ZIO.succeed(Some(knownCompany.copy(status = CompanyStatus.Inactive)))
        else ZIO.none
  )

  private val stubInvoiceRepo: ZLayer[Any, Nothing, InvoiceRepository] = ZLayer.succeed(
    new InvoiceRepository:
      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]                                   = ZIO.succeed("INV-0001")
      def create(invoice: com.shevchyk.billing.domain.Invoice): Task[com.shevchyk.billing.domain.Invoice]        = ZIO.succeed(
        invoice
      )
      def findById(id: com.shevchyk.billing.domain.InvoiceId): Task[Option[com.shevchyk.billing.domain.Invoice]] = ZIO
        .succeed(None)
      def findByCompany(
          taxiCompanyId: CompanyId,
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[com.shevchyk.billing.domain.Invoice]] = ZIO.succeed(Nil)
      def update(invoice: com.shevchyk.billing.domain.Invoice): Task[com.shevchyk.billing.domain.Invoice]        = ZIO.succeed(
        invoice
      )
      def findOverdueUnpaid(now: java.time.Instant): Task[List[com.shevchyk.billing.domain.Invoice]]             = ZIO.succeed(Nil)
      def delete(id: com.shevchyk.billing.domain.InvoiceId, taxiCompanyId: CompanyId): Task[Boolean]             = ZIO.succeed(
        false
      )
      def addItems(items: List[com.shevchyk.billing.domain.InvoiceItem]): Task[Unit]                             = ZIO.unit
      def deleteItems(invoiceId: com.shevchyk.billing.domain.InvoiceId): Task[Unit]                              = ZIO.unit
      def replaceItems(
          invoiceId: com.shevchyk.billing.domain.InvoiceId,
          taxiCompanyId: CompanyId,
          items: List[com.shevchyk.billing.domain.InvoiceItem]
      ): Task[Unit] = ZIO.unit
      def unlinkRides(invoiceId: com.shevchyk.billing.domain.InvoiceId, taxiCompanyId: CompanyId): Task[Unit]    = ZIO.unit
      def findUnbilledRides(
          clientCompanyId: ClientCompanyId,
          from: java.time.LocalDate,
          to: java.time.LocalDate
      ): Task[List[com.shevchyk.billing.repository.UnbilledRide]] = ZIO.succeed(Nil)
      def findBillableRides(
          taxiCompanyId: CompanyId,
          clientCompanyId: ClientCompanyId,
          from: Option[java.time.LocalDate],
          to: Option[java.time.LocalDate]
      ): Task[List[com.shevchyk.billing.repository.UnbilledRide]] = ZIO.succeed(Nil)
      def findRidesByIds(
          taxiCompanyId: CompanyId,
          rideIds: List[UUID]
      ): Task[List[com.shevchyk.billing.repository.UnbilledRide]] = ZIO.succeed(Nil)
      def findRideForReceipt(
          taxiCompanyId: CompanyId,
          rideId: UUID
      ): Task[Option[com.shevchyk.billing.repository.UnbilledRide]] = ZIO.none
      def findAllPlatform(
          status: Option[InvoiceStatus],
          limit: Int,
          offset: Int
      ): Task[List[com.shevchyk.billing.domain.Invoice]] = ZIO.succeed(Nil)
      def sumRevenueByCompany(from: java.time.Instant, to: java.time.Instant): Task[Map[UUID, BigDecimal]]       = ZIO
        .succeed(Map.empty)
      def countOverdueByCompany(): Task[Map[UUID, Int]]                                                          = ZIO.succeed(Map.empty)
  )

  private val stubRideRepo: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed(
    new RideRepository:
      import com.shevchyk.ride.domain.{Ride, RideStatus, DriverEarnings}
      import com.shevchyk.ride.repository.TimeBucket
      def create(ride: Ride): Task[Ride]                                                                           = ZIO.succeed(ride)
      def findById(id: RideId): Task[Option[Ride]]                                                                 = ZIO.none
      def findByStatus(status: RideStatus): Task[List[Ride]]                                                       = ZIO.succeed(Nil)
      def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]                       = ZIO.succeed(Nil)
      def findAll(): Task[List[Ride]]                                                                              = ZIO.succeed(Nil)
      def findByClientId(clientId: PersonId): Task[List[Ride]]                                                     = ZIO.succeed(Nil)
      def findByDriverId(driverId: PersonId): Task[List[Ride]]                                                     = ZIO.succeed(Nil)
      def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]                     = ZIO.succeed(Nil)
      def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]                     = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                                  = ZIO.succeed(Nil)
      def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]]                = ZIO.succeed(Nil)
      def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]                   = ZIO.succeed(Nil)
      def findByDriverIdAndCompanyPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): Task[List[Ride]] = ZIO.succeed(Nil)
      def update(ride: Ride): Task[Ride]                                                                           = ZIO.succeed(ride)
      def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                             = ZIO.succeed(true)
      def markPaidIfCompleted(
          rideId: RideId,
          paymentMethod: Option[com.shevchyk.ride.domain.PaymentMethod]
      ): Task[Boolean] = ZIO.succeed(true)
      def delete(id: RideId, companyId: CompanyId): Task[Unit]                                                     = ZIO.unit
      def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]                              = ZIO.succeed(Map.empty)
      def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                              = ZIO.succeed(BigDecimal(0))
      def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                         = ZIO.succeed(BigDecimal(0))
      def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]                                        = ZIO.succeed(0.0)
      def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]           = ZIO.succeed(
        Nil
      )
      def earningsByDriver(
          d: PersonId,
          c: CompanyId,
          f: java.time.Instant,
          t: java.time.Instant
      ): Task[DriverEarnings] = ZIO.succeed(DriverEarnings(BigDecimal(0), 0, 0))
      def earningsBucketsByDriver(
          d: PersonId,
          c: CompanyId,
          f: java.time.Instant,
          t: java.time.Instant,
          bucket: TimeBucket
      ): Task[List[(java.time.Instant, BigDecimal)]] = ZIO.succeed(Nil)
      def findAssignedRidesInWindow(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]              = ZIO.succeed(Nil)
      def findActiveRidesInWindow(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]                = ZIO.succeed(Nil)
      def findRidesNeedingConfirmation(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]           = ZIO.succeed(
        Nil
      )
      def clearReminders(rideId: RideId): Task[Unit]                                                               = ZIO.unit
      def countAllRidesByStatus(): Task[Map[String, Int]]                                                          = ZIO.succeed(Map.empty)
      def sumAllRevenue(from: java.time.Instant, to: java.time.Instant): Task[BigDecimal]                          = ZIO.succeed(BigDecimal(0))
      def countRidesByCompany(from: java.time.Instant, to: java.time.Instant): Task[Map[UUID, Int]]                = ZIO.succeed(
        Map.empty
      )
      def sumRevenueByCompanyPlatform(from: java.time.Instant, to: java.time.Instant): Task[Map[UUID, BigDecimal]] = ZIO
        .succeed(Map.empty)
      def updateCheckpoint(rideId: RideId, checkpoint: com.shevchyk.ride.domain.AirportCheckpoint): Task[Boolean]  = ZIO
        .succeed(false)
      def updateFlightStatus(
          rideId: RideId,
          gate: Option[String],
          terminal: Option[String],
          flightStatus: Option[String],
          flightTime: Option[java.time.Instant],
          scheduledTime: Option[java.time.Instant]
      ): Task[Boolean] = ZIO.succeed(false)
      def findFlightStatus(rideId: RideId): Task[Option[com.shevchyk.ride.domain.FlightStatusRow]]                 = ZIO.none
      def findFlightStatusFor(
          rideIds: List[RideId]
      ): Task[Map[RideId, com.shevchyk.ride.domain.FlightStatusRow]] = ZIO.succeed(Map.empty)
  )

  private val stubSessionRepo: ZLayer[Any, Nothing, SessionRepository] = SessionRepository.inMemory

  // ---------------------------------------------------------------------------
  // Route under test
  // ---------------------------------------------------------------------------

  private val superAdminRoutes: Routes[SuperAdminApi.SuperAdminEnv, Response] = ZioHttpInterpreter().toHttp(
    SuperAdminApi.serverEndpoints
  )

  private def run(req: Request): ZIO[SuperAdminApi.SuperAdminEnv, Nothing, Response] = superAdminRoutes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  private type TestEnv = SuperAdminApi.SuperAdminEnv

  private val testLayers: ZLayer[Any, Throwable, TestEnv] =
    testJwtService ++ stubCompanyRepo ++ stubInvoiceRepo ++ stubRideRepo ++ stubSessionRepo

  // ---------------------------------------------------------------------------
  // Tests — GET /api/superadmin/companies
  // ---------------------------------------------------------------------------

  def spec =
    suite("SuperAdminApi — negative tenant-isolation tests [CRITICAL]")(
      suite("GET /api/superadmin/companies")(
        test("SuperAdmin JWT → 200 (escape hatch grants access)") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .get(URL.decode("/api/superadmin/companies").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("Admin JWT → 403 (highest normal role must still be denied)") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/companies").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Dispatcher JWT → 403") {
          for {
            token <- generateToken(PersonRole.Dispatcher, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/companies").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Driver JWT → 403") {
          for {
            token <- generateToken(PersonRole.Driver, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/companies").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401 (unauthenticated)") {
          val req = Request.get(URL.decode("/api/superadmin/companies").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        },
        test("Admin with companyId=None (crafted edge-case) → 403 (role check is primary)") {
          // A non-SuperAdmin user must not be able to bypass the check even if their
          // companyId is None in the JWT. The role field is the sole gate.
          for {
            token <- generateToken(PersonRole.Admin, cid = None)
            req    = Request
                       .get(URL.decode("/api/superadmin/companies").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/superadmin/analytics/rides")(
        test("SuperAdmin JWT → 200") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/rides").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("Admin JWT → 403") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/rides").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401") {
          val req = Request.get(URL.decode("/api/superadmin/analytics/rides").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),
      suite("GET /api/superadmin/analytics/billing")(
        test("SuperAdmin JWT → 200") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/billing").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("Admin JWT → 403") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/billing").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/superadmin/analytics/connections")(
        test("SuperAdmin JWT → 200") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/connections").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("Dispatcher JWT → 403") {
          for {
            token <- generateToken(PersonRole.Dispatcher, cid = Some(testCompanyId))
            req    = Request
                       .get(URL.decode("/api/superadmin/analytics/connections").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401") {
          val req = Request.get(URL.decode("/api/superadmin/analytics/connections").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),
      suite("POST /api/superadmin/companies — create")(
        test("SuperAdmin JWT → 201 Created") {
          val body = """{"name":"New Operator","email":"op@test.de","phone":"+491234","address":"Str. 1"}"""
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .post(URL.decode("/api/superadmin/companies").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader(Header.ContentType(MediaType.application.json))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Created)
        },
        test("Admin JWT → 403 on create") {
          val body = """{"name":"Hacker Corp","email":"hack@evil.com","phone":"+491234","address":"Bad Str. 1"}"""
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .post(URL.decode("/api/superadmin/companies").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader(Header.ContentType(MediaType.application.json))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("PATCH /api/superadmin/companies/{id}")(
        test("Admin JWT → 403 on update") {
          val body = """{"status":"Suspended"}"""
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .patch(
                         URL.decode(s"/api/superadmin/companies/$testCompanyId").toOption.get,
                         Body.fromString(body)
                       )
                       .addHeader(Header.Authorization.Bearer(token))
                       .addHeader(Header.ContentType(MediaType.application.json))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      // -----------------------------------------------------------------------
      // DELETE /api/superadmin/companies/{id}  (soft-delete)
      // -----------------------------------------------------------------------
      suite("DELETE /api/superadmin/companies/{id}")(
        test("SuperAdmin JWT + existing company → 200 with Inactive status in body") {
          for {
            token   <- generateToken(PersonRole.SuperAdmin, cid = None)
            req      = Request
                         .delete(URL.decode(s"/api/superadmin/companies/$testCompanyId").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- run(req)
            bodyStr <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("Inactive")
          )
        },
        test("Admin JWT → 403 on delete (escape-hatch negative test [CRITICAL])") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = Request
                       .delete(URL.decode(s"/api/superadmin/companies/$testCompanyId").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("SuperAdmin JWT + unknown company id → 404") {
          val unknownId = UUID.fromString("ffffffff-ffff-ffff-ffff-ffffffffffff")
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = Request
                       .delete(URL.decode(s"/api/superadmin/companies/$unknownId").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("no token → 401 on delete") {
          val req = Request.delete(URL.decode(s"/api/superadmin/companies/$testCompanyId").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      )
    ).provide(testLayers) @@ TestAspect.sequential
