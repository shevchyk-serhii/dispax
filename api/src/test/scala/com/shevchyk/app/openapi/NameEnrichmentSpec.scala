package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{ActiveRideInfo, AuditService, EventHub, GeofenceService}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.*
import com.shevchyk.ride.application.service.RideService
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import sttp.tapir.ztapir.ZServerEndpoint
import zio.*
import zio.http.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Endpoint-level tests for the person-name enrichment of admin list endpoints (blacklist, ride pools, emergency
 * reassignments, geofence alerts). The UI must never have to show a bare person UUID, so every list response carries
 * the resolved display names (`clientName`, `driverName`, ...). Exercised via ZioHttpInterpreter against in-memory
 * stubs — no network I/O, no Testcontainers.
 */
object NameEnrichmentSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // Fixture ids / persons
  // ---------------------------------------------------------------------------

  private val companyId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-0000000000AA"))

  private val clientId: PersonId  = PersonId(UUID.fromString("000000CC-0000-0000-0000-0000000000C1"))
  private val driverId: PersonId  = PersonId(UUID.fromString("000000DD-0000-0000-0000-0000000000D1"))
  private val driver2Id: PersonId = PersonId(UUID.fromString("000000DD-0000-0000-0000-0000000000D2"))

  private def person(id: PersonId, name: String, role: PersonRole): Person = Person(
    id = id,
    name = name,
    email = s"${name.toLowerCase.replace(" ", ".")}@test.de",
    role = role,
    companyId = Some(companyId)
  )

  private val people: Map[PersonId, Person] = Map(
    clientId  -> person(clientId, "Max Mustermann", PersonRole.Client),
    driverId  -> person(driverId, "Hans Weber", PersonRole.Driver),
    driver2Id -> person(driver2Id, "Erika Musterfrau", PersonRole.Driver)
  )

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

  private val dispatcherToken: ZIO[Any, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = "dispatcher@test.de",
          name = "Dispatcher",
          role = PersonRole.Dispatcher,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )
    .provideLayer(testJwtService)

  // ---------------------------------------------------------------------------
  // Stubs
  // ---------------------------------------------------------------------------

  /**
   * PersonRepository stub whose findById resolves from the fixture map; everything else is unused.
   */
  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      private def notImpl                                                                              = ZIO.die(new NotImplementedError("NameEnrichmentSpec PersonRepository stub"))
      def create(p: Person): Task[Person]                                                              = notImpl
      def findById(id: PersonId): Task[Option[Person]]                                                 = ZIO.succeed(people.get(id))
      def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]                       = notImpl
      def findByEmail(email: String): Task[Option[Person]]                                             = notImpl
      def findByRole(role: PersonRole): Task[List[Person]]                                             = notImpl
      def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]]                   = notImpl
      def findByCompanyId(cid: CompanyId): Task[List[Person]]                                          = notImpl
      def findAll(): Task[List[Person]]                                                                = notImpl
      def update(p: Person): Task[Person]                                                              = notImpl
      def delete(id: PersonId): Task[Unit]                                                             = notImpl
      def deleteInCompany(id: PersonId, cid: CompanyId): Task[Unit]                                    = notImpl
      def findByStatus(status: UserStatus): Task[List[Person]]                                         = notImpl
      def searchByQuery(query: String): Task[List[Person]]                                             = notImpl
      def updateLastLogin(id: PersonId): Task[Unit]                                                    = notImpl
      def findByClientCompany(ccid: ClientCompanyId): Task[List[Person]]                               = notImpl
      def upsertDriverRow(pid: PersonId): Task[Unit]                                                   = notImpl
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                 = notImpl
      def setAvatar(id: PersonId, cid: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = notImpl
      def deleteAvatar(id: PersonId, cid: CompanyId): Task[Unit]                                       = notImpl
  )

  private val stubRideService: ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    StubRideService.notImplemented("NameEnrichmentSpec RideService stub")
  )

  private val stubGeofenceService: ZLayer[Any, Nothing, GeofenceService] = ZLayer.succeed(
    new GeofenceService:
      private def notImpl                                                                                     = new NotImplementedError("NameEnrichmentSpec GeofenceService stub")
      def checkDriverLocation(d: PersonId, c: CompanyId, lat: Double, lng: Double): UIO[List[GeofenceAlert]]  = ZIO.die(
        notImpl
      )
      def checkClientProximity(d: PersonId, lat: Double, lng: Double, rides: List[ActiveRideInfo]): UIO[Unit] = ZIO.die(
        notImpl
      )
  )

  // ---------------------------------------------------------------------------
  // HTTP runner
  // ---------------------------------------------------------------------------

  private def get(token: String, path: String): Request = Request
    .get(URL.decode(path).toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  private def runWith[Env](
      endpoints: List[ZServerEndpoint[Env, Any]],
      req: Request
  ): ZIO[Env, Throwable, String] = ZioHttpInterpreter()
    .toHttp(endpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .flatMap(_.body.asString)

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("Admin list endpoints resolve person names (no bare UUIDs for the UI)")(
      test("GET /api/blacklist returns clientName and driverName") {
        val repoLayer = BlacklistRepository.inMemory
        val layers    = testJwtService ++ repoLayer ++ AuditService.inMemory ++ stubPersonRepo
        val entry     = BlacklistEntry(
          id = BlacklistEntryId.generate(),
          companyId = companyId,
          clientId = clientId,
          driverId = driverId,
          createdBy = driverId
        )
        (for {
          _     <- ZIO.serviceWithZIO[BlacklistRepository](_.create(entry))
          token <- dispatcherToken
          body  <- runWith(BlacklistApi.serverEndpoints, get(token, "/api/blacklist"))
        } yield assertTrue(
          body.contains(""""clientName":"Max Mustermann""""),
          body.contains(""""driverName":"Hans Weber"""")
        )).provideLayer(layers)
      },
      test("GET /api/pools returns driverName, GET /api/pools/{id} adds member clientName") {
        val repoLayer = RidePoolRepository.inMemory
        val layers    =
          testJwtService ++ repoLayer ++ stubRideService ++ AuditService.inMemory ++ EventHub.layer ++ stubPersonRepo
        val pool      = RidePool(
          id = RidePoolId.generate(),
          companyId = companyId,
          driverId = Some(driverId),
          createdBy = driverId
        )
        val member    = RidePoolMember(
          id = RidePoolMemberId.generate(),
          poolId = pool.id,
          rideId = RideId(UUID.randomUUID()),
          clientId = clientId
        )
        (for {
          _          <- ZIO.serviceWithZIO[RidePoolRepository](r => r.create(pool) *> r.addMember(member))
          token      <- dispatcherToken
          listBody   <- runWith(RidePoolApi.serverEndpoints, get(token, "/api/pools"))
          detailBody <- runWith(RidePoolApi.serverEndpoints, get(token, s"/api/pools/${pool.id.value}"))
        } yield assertTrue(
          listBody.contains(""""driverName":"Hans Weber""""),
          detailBody.contains(""""driverName":"Hans Weber""""),
          detailBody.contains(""""clientName":"Max Mustermann"""")
        )).provideLayer(layers)
      },
      test("GET /api/emergency/reassignments returns originalDriverName and newDriverName") {
        val repoLayer = EmergencyReassignmentRepository.inMemory
        val layers    =
          testJwtService ++ repoLayer ++ BlacklistRepository.inMemory ++ stubRideService ++
            stubPersonRepo ++ AuditService.inMemory ++ EventHub.layer
        val row       = EmergencyReassignment(
          id = EmergencyReassignmentId.generate(),
          rideId = RideId(UUID.randomUUID()),
          companyId = companyId,
          originalDriverId = driverId,
          newDriverId = Some(driver2Id),
          reason = EmergencyReason.DriverIllness,
          reassignedBy = driverId
        )
        (for {
          _     <- ZIO.serviceWithZIO[EmergencyReassignmentRepository](_.create(row))
          token <- dispatcherToken
          body  <- runWith(EmergencyApi.serverEndpoints, get(token, "/api/emergency/reassignments"))
        } yield assertTrue(
          body.contains(""""originalDriverName":"Hans Weber""""),
          body.contains(""""newDriverName":"Erika Musterfrau"""")
        )).provideLayer(layers)
      },
      test("GET /api/geofences/alerts returns driverName") {
        val repoLayer = GeofenceRepository.inMemory
        val layers    = testJwtService ++ repoLayer ++ stubGeofenceService ++ stubPersonRepo
        val alert     = GeofenceAlert(
          id = UUID.randomUUID(),
          geofenceId = GeofenceId.generate(),
          driverId = driverId,
          companyId = companyId,
          alertType = "entry",
          geofenceName = "Airport zone",
          latitude = 48.35,
          longitude = 11.78,
          timestamp = Instant.now()
        )
        (for {
          _     <- ZIO.serviceWithZIO[GeofenceRepository](_.saveAlert(alert))
          token <- dispatcherToken
          body  <- runWith(GeofenceApi.serverEndpoints, get(token, "/api/geofences/alerts"))
        } yield assertTrue(body.contains(""""driverName":"Hans Weber""""))).provideLayer(layers)
      }
    ) @@ TestAspect.sequential
