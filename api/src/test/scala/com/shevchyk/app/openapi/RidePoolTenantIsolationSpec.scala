package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{InMemoryRidePoolRepository, PersonRepository, RidePoolRepository}
import com.shevchyk.ride.domain.*

/**
 * CRITICAL — endpoint-level regression for tenant isolation on the ride-pool routes:
 *   - POST /api/pools (createServer) — builds pool members from `rideIds`;
 *   - POST /api/pools/{id}/rides (addRideServer) — adds one ride to an existing pool.
 *
 * Bug context: both handlers resolved the ride via `RideService.getRideById`, which is NOT company-scoped, and never
 * checked `ride.companyId == companyId`. A dispatcher of company A could pull a ride of company B into their pool —
 * capturing B's clientId into a `RidePoolMember` and emitting a cross-tenant `RideStatusChanged` event. The pool itself
 * was already tenant-gated; the RIDE was not.
 *
 * The fix adds, right after `getRideById`: _ <- ZIO.fail((StatusCode.NotFound, ApiError("Ride not
 * found"))).when(ride.companyId != companyId)
 *
 * These tests run the REAL `RidePoolApi.serverEndpoints` through `ZioHttpInterpreter` over an in-memory pool repo and a
 * `getRideById` that returns the seeded ride (via `RideServiceFromRepo`). A cross-tenant ride must yield 404 and must
 * NOT become a pool member.
 */
object RidePoolTenantIsolationSpec extends ZIOSpecDefault:

  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val clientBId  = PersonId(UUID.fromString("000000CC-0000-0000-0000-00000000000B"))
  private val rideBId    = RideId(UUID.fromString("000000BB-BBBB-0000-0000-000000000001"))
  private val rideAId    = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))
  private val clientAId  = PersonId(UUID.fromString("000000CC-0000-0000-0000-00000000000A"))

  // -- JWT --------------------------------------------------------------------
  private val testJwtService: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
        issuer = "test-issuer",
        audience = "test-audience",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def dispatcherToken(companyId: CompanyId): ZIO[JwtService, Throwable, String] = ZIO
    .serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = "dispatcher@test.de",
          name = "Dispatcher User",
          role = PersonRole.Dispatcher,
          passwordHash = "hash",
          companyId = Some(companyId),
          status = UserStatus.ACTIVE
        )
      )
    )

  // -- Ride factory -----------------------------------------------------------
  private def ride(id: RideId, companyId: CompanyId, clientId: PersonId): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    status = RideStatus.Requested,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  // A ride-pool test seeds rides into the reusable CheckpointRideRepository double (its `findById`
  // reads the seeded map); RideServiceFromRepo turns that into a RideService whose getRideById the
  // pool handlers call.

  // -- PersonRepository stub (name enrichment tolerates empty) ---------------
  private val personRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.none
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
      def updateLastLogin(id: PersonId, companyId: Option[CompanyId]): Task[Unit]                            = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  )

  // The pool repo must be a SINGLE shared instance across the create+add+lookup calls of one test —
  // each `run` re-provides the layer, so a fresh `RidePoolRepository.inMemory` per call would lose the
  // pool created in the first call. Passing one instance via `ZLayer.succeed` keeps its state.
  private def layers(
      rideRepo: CheckpointRideRepository,
      poolRepo: RidePoolRepository
  ): ZLayer[Any, Throwable, RidePoolApi.RidePoolEnv] =
    testJwtService ++
      ZLayer.succeed(poolRepo) ++
      RideServiceFromRepo.layer(rideRepo) ++
      AuditService.inMemory ++
      EventHub.layer ++
      personRepoLayer

  private def run(req: Request, ls: ZLayer[Any, Throwable, RidePoolApi.RidePoolEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(RidePoolApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(ls)

  def spec =
    suite("RidePoolApi — tenant isolation on getRideById [CRITICAL regression]")(
      test("createServer: dispatcher of company A cannot seed the pool with a ride of company B → 404") {
        for {
          repo  <- CheckpointRideRepository.make(ride(rideBId, companyBId, clientBId))
          ls     = layers(repo, new InMemoryRidePoolRepository)
          token <- dispatcherToken(companyAId).provideLayer(testJwtService)
          req    = Request
                     .post(
                       URL.decode("/api/pools").toOption.get,
                       Body.fromString(s"""{"name":"Pool A","rideIds":["${rideBId.value}"]}""")
                     )
                     .addHeader(Header.Authorization.Bearer(token))
                     .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp  <- run(req, ls)
        } yield assertTrue(resp.status == Status.NotFound)
      },
      test("addRideServer: dispatcher of company A cannot add a ride of company B to their pool → 404, no member") {
        for {
          repo        <- CheckpointRideRepository.make(ride(rideBId, companyBId, clientBId))
          ls           = layers(repo, new InMemoryRidePoolRepository)
          token       <- dispatcherToken(companyAId).provideLayer(testJwtService)
          // Create an empty pool for company A first (rideIds empty → no cross-tenant issue).
          createReq    = Request
                           .post(
                             URL.decode("/api/pools").toOption.get,
                             Body.fromString("""{"name":"Pool A"}""")
                           )
                           .addHeader(Header.Authorization.Bearer(token))
                           .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          createResp  <- run(createReq, ls)
          createdBody <- createResp.body.asString
          poolId       = extractId(createdBody)
          addReq       = Request
                           .post(
                             URL.decode(s"/api/pools/$poolId/rides").toOption.get,
                             Body.fromString(s"""{"rideId":"${rideBId.value}"}""")
                           )
                           .addHeader(Header.Authorization.Bearer(token))
                           .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          addResp     <- run(addReq, ls)
          // The pool must have gained no cross-tenant member: fetch it by the foreign ride → not found.
          lookupReq    = Request
                           .get(URL.decode(s"/api/pools/ride/${rideBId.value}").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
          lookupResp  <- run(lookupReq, ls)
        } yield assertTrue(
          createResp.status == Status.Created,
          addResp.status == Status.NotFound,
          lookupResp.status == Status.NotFound
        )
      },
      test("createServer: a ride of the caller's own company is accepted → 201") {
        for {
          repo  <- CheckpointRideRepository.make(ride(rideAId, companyAId, clientAId))
          ls     = layers(repo, new InMemoryRidePoolRepository)
          token <- dispatcherToken(companyAId).provideLayer(testJwtService)
          req    = Request
                     .post(
                       URL.decode("/api/pools").toOption.get,
                       Body.fromString(s"""{"name":"Pool A","rideIds":["${rideAId.value}"]}""")
                     )
                     .addHeader(Header.Authorization.Bearer(token))
                     .addHeader(Header.ContentType(zio.http.MediaType.application.json))
          resp  <- run(req, ls)
        } yield assertTrue(resp.status == Status.Created)
      }
    ) @@ TestAspect.sequential

  // Extracts the pool "id" value from a RidePoolDto JSON response.
  private def extractId(json: String): String =
    val marker = "\"id\":\""
    val start  = json.indexOf(marker) + marker.length
    json.substring(start, json.indexOf('"', start))
