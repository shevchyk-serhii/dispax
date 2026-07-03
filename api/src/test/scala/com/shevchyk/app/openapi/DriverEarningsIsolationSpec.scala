package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.{DriverLocationService, EtaService}
import com.shevchyk.driver.openapi.DriverApi
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{DriverEarningsReport, EarningsPeriod, Ride, RideError}

/**
 * Endpoint-level tests for GET /api/drivers/{driverId}/earnings on DriverApi.
 *
 * Regression coverage for the audit finding: getEarningsServer was the only one of the four per-driver endpoints
 * WITHOUT `assertDriverInCompany`, so a dispatcher of company B querying a company-A driver got 200 with an all-zero
 * report instead of the 404 its siblings return. No cross-tenant data leaked (the service scopes by the caller's
 * companyId), but the inconsistency both reveals nothing-vs-404 semantics and drops the defense-in-depth guard.
 *
 * Runs the REAL `DriverApi.serverEndpoints` through `ZioHttpInterpreter`.
 */
object DriverEarningsIsolationSpec extends ZIOSpecDefault:

  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val driverId   = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val callerId   = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000009"))

  private val companyADriver = Person(
    id = driverId,
    name = "Company A Driver",
    email = "driver-a@example.com",
    role = PersonRole.Driver,
    companyId = Some(companyAId)
  )

  // -- Stub layers -----------------------------------------------------------
  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(
        Option.when(id == driverId)(companyADriver)
      )
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.succeed(
        Option.when(id == driverId && companyADriver.companyId.contains(companyId))(companyADriver)
      )
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

  private val sentinelReport = DriverEarningsReport(
    period = EarningsPeriod.Week,
    from = Instant.parse("2026-06-29T00:00:00Z"),
    to = Instant.parse("2026-07-06T00:00:00Z"),
    grossRevenue = BigDecimal("321.50"),
    totalExpenses = BigDecimal("21.50"),
    completedRides = 7,
    cancelledRides = 1,
    buckets = Nil
  )

  // RideService whose getDriverEarnings answers with a sentinel report; everything else dies loudly.
  private val stubRideService: ZLayer[Any, Nothing, RideService] = ZLayer.succeed {
    val base = StubRideService.notImplemented("DriverEarningsIsolationSpec")
    new RideService:
      export base.{getDriverEarnings as _, *}
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = ZIO.succeed(sentinelReport)
  }

  private val stubLocationService: ZLayer[Any, Nothing, DriverLocationService] = ZLayer.succeed(
    new DriverLocationService:
      def updateLocation(driverId: PersonId, latitude: Double, longitude: Double) = ZIO.die(
        new NotImplementedError("stub")
      )
      def getLocation(driverId: PersonId)                                         = ZIO.none
      def updateAvailability(driverId: PersonId, status: String)                  = ZIO.die(new NotImplementedError("stub"))
      def getAvailability(driverId: PersonId)                                     = ZIO.die(new NotImplementedError("stub"))
      def getAvailableDrivers(companyId: CompanyId)                               = ZIO.succeed(Nil)
  )

  private val stubEtaService: ZLayer[Any, Nothing, EtaService] = ZLayer.succeed(
    new EtaService:
      def etaForRide(ride: Ride): Task[Option[Int]] = ZIO.none
  )

  private val layers: ZLayer[Any, Throwable, DriverApi.DriverEnv] =
    TestJwt.serviceLayer ++ stubRideService ++ stubLocationService ++ stubEtaService ++
      GeocodingService.noop ++ stubPersonRepo

  private def run(req: Request): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(DriverApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(layers)

  private def earningsReq(token: String): Request = Request
    .get(URL.decode(s"/api/drivers/${driverId.value}/earnings").toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  private def tokenFor(role: PersonRole, companyId: CompanyId, userId: PersonId): ZIO[Any, Throwable, String] = TestJwt
    .generateToken(role, companyId, userId)
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("DriverApi — GET /api/drivers/{driverId}/earnings company isolation [real serverEndpoints]")(
      test("a dispatcher of ANOTHER company gets 404 for a foreign driver (no all-zero 200)") {
        for {
          token <- tokenFor(PersonRole.Dispatcher, companyBId, callerId)
          resp  <- run(earningsReq(token))
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.NotFound,
          !body.contains("321.5")
        )
      },
      test("a same-company dispatcher gets the earnings report (200)") {
        for {
          token <- tokenFor(PersonRole.Dispatcher, companyAId, callerId)
          resp  <- run(earningsReq(token))
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("321.5")
        )
      },
      test("the driver still reads their own earnings (200)") {
        for {
          token <- tokenFor(PersonRole.Driver, companyAId, driverId)
          resp  <- run(earningsReq(token))
        } yield assertTrue(resp.status == Status.Ok)
      }
    ) @@ TestAspect.sequential
