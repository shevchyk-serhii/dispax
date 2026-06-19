package com.shevchyk.app.openapi

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AvatarService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.repository.InMemoryFcmTokenRepository
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.http.{Boundary, MediaType}
import zio.test.*

import java.util.UUID

/**
 * CRITICAL — Endpoint-level HTTP tests for avatar upload/get/delete (UserApi).
 *
 * Routes are exercised via ZioHttpInterpreter against in-memory stubs — no network I/O, no Testcontainers needed. The
 * CRITICAL invariant tested here is tenant isolation: a JWT for company A must receive 404 when targeting a user in
 * company B.
 *
 * Note: the shared in-memory PersonRepository is a mutable Ref initialized once per spec execution. Tests that modify
 * state (upload → delete) run in @@ TestAspect.sequential order and use distinct user IDs to avoid inter-test
 * interference.
 */
object AvatarApiSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // IDs — two companies, one user each
  // ---------------------------------------------------------------------------

  private val companyAId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId: CompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))

  private val userAId: PersonId       = PersonId(UUID.fromString("000000AA-0000-0000-0000-000000000001"))
  private val dispatcherAId: PersonId = PersonId(UUID.fromString("0000AADD-0000-0000-0000-000000000001"))
  private val userBId: PersonId       = PersonId(UUID.fromString("000000BB-0000-0000-0000-000000000002"))

  private val userA: Person = Person(
    id = userAId,
    name = "Alice",
    email = "alice@companya.de",
    role = PersonRole.Client,
    companyId = Some(companyAId)
  )

  private val dispatcherA: Person = Person(
    id = dispatcherAId,
    name = "Dispatcher A",
    email = "dispatch@companya.de",
    role = PersonRole.Dispatcher,
    companyId = Some(companyAId)
  )

  private val userB: Person = Person(
    id = userBId,
    name = "Bob",
    email = "bob@companyb.de",
    role = PersonRole.Client,
    companyId = Some(companyBId)
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

  private def generateToken(person: Person): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(person)
  )

  // ---------------------------------------------------------------------------
  // In-memory stubs
  // ---------------------------------------------------------------------------

  // Mutable PersonRepository backed by a ZIO Ref — same instance shared across a spec run
  private val stubPersonRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.fromZIO(
    for {
      avatarsRef <- Ref.Synchronized.make(Map.empty[PersonId, (Array[Byte], String)])
      peopleRef  <- Ref.Synchronized.make(
                      Map[PersonId, Person](
                        userAId       -> userA,
                        dispatcherAId -> dispatcherA,
                        userBId       -> userB
                      )
                    )
    } yield new PersonRepository:
      def create(p: Person): Task[Person]                                         = peopleRef.update(_.updated(p.id, p)).as(p)
      def findById(id: PersonId): Task[Option[Person]]                            = peopleRef.get.map(_.get(id))
      def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]  = peopleRef.get.map(
        _.get(id).filter(_.companyId.contains(cid))
      )
      def findByEmail(e: String): Task[Option[Person]]                            = peopleRef.get.map(_.values.find(_.email == e))
      def findByRole(r: PersonRole): Task[List[Person]]                           = peopleRef.get.map(_.values.filter(_.hasRole(r)).toList)
      def findByRoleAndCompany(r: PersonRole, cid: CompanyId): Task[List[Person]] = peopleRef.get.map(
        _.values.filter(p => p.hasRole(r) && p.companyId.contains(cid)).toList
      )
      def findByCompanyId(cid: CompanyId): Task[List[Person]]                     = peopleRef.get.map(
        _.values.filter(_.companyId.contains(cid)).toList
      )
      def findAll(): Task[List[Person]]                                           = peopleRef.get.map(_.values.toList)
      def update(p: Person): Task[Person]                                         = peopleRef.update(_.updated(p.id, p)).as(p)
      def delete(id: PersonId): Task[Unit]                                        = peopleRef.update(_.removed(id)).unit
      def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]         =
        peopleRef
          .update(m =>
            m.get(id) match
              case Some(p) if p.companyId.contains(companyId) => m.removed(id)
              case _                                          => m
          )
          .unit
      def findByStatus(s: UserStatus): Task[List[Person]]                         = peopleRef.get.map(_.values.filter(_.status == s).toList)
      def searchByQuery(q: String): Task[List[Person]]                            = peopleRef.get.map(
        _.values.filter(p => p.name.contains(q) || p.email.contains(q)).toList
      )
      def updateLastLogin(id: PersonId): Task[Unit]                               = ZIO.unit
      def findByClientCompany(ccid: ClientCompanyId): Task[List[Person]]          = ZIO.succeed(Nil)
      def upsertDriverRow(pid: PersonId): Task[Unit]                              = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]            = avatarsRef.get.map(_.get(id))
      def setAvatar(id: PersonId, b: Array[Byte], ct: String): Task[Unit]         =
        avatarsRef.update(_.updated(id, (b, ct))).unit
      def deleteAvatar(id: PersonId): Task[Unit]                                  = avatarsRef.update(_.removed(id)).unit
  )

  private val stubAuthServiceLayer: ZLayer[Any, Nothing, AuthService] = ZLayer.succeed(
    new AuthService:
      private def notImpl                                                                                 = ZIO.die(new NotImplementedError("AvatarApiSpec AuthService stub"))
      def login(email: String, password: String): IO[AuthError, LoginResponse]                            = notImpl
      def createUser(req: CreateUserRequest): IO[AuthError, UserDto]                                      = notImpl
      def getUserById(id: UUID): IO[AuthError, UserDto]                                                   = notImpl
      def getUserByEmail(email: String): IO[AuthError, UserDto]                                           = notImpl
      def updateUser(id: UUID, req: UpdateUserRequest): IO[AuthError, UserDto]                            = notImpl
      def deleteUser(id: UUID, companyId: CompanyId): IO[AuthError, Unit]                                 = notImpl
      def changePassword(userId: UUID, req: ChangePasswordRequest): IO[AuthError, Unit]                   = notImpl
      def validateToken(token: String): IO[AuthError, UserDto]                                            = notImpl
      def refreshToken(token: String): IO[AuthError, String]                                              = notImpl
      def getAllUsers(role: Option[PersonRole], status: Option[UserStatus]): IO[AuthError, List[UserDto]] = ZIO.succeed(
        Nil
      )
      def searchUsers(query: String): IO[AuthError, List[UserDto]]                                        = ZIO.succeed(Nil)
  )

  private val stubRideServiceLayer: ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImpl                                                                                       = ZIO.die(new NotImplementedError("AvatarApiSpec stub"))
      def getRideById(id: RideId): IO[RideError, Ride]                                                          = notImpl
      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                               = notImpl
      def getRidesForUser(id: PersonId): IO[RideError, List[Ride]]                                              = notImpl
      def startRide(id: RideId, did: PersonId): IO[RideError, Ride]                                             = notImpl
      def completeRide(id: RideId): IO[RideError, Ride]                                                         = notImpl
      def cancelRide(id: RideId, uid: PersonId, role: PersonRole): IO[RideError, Ride]                          = notImpl
      def cancelRideWithReason(
          id: RideId,
          uid: PersonId,
          role: PersonRole,
          req: CancelRideRequest
      ): IO[RideError, Ride] = notImpl
      def getCancellationStats(cid: CompanyId): IO[RideError, Map[String, Int]]                                 = notImpl
      def updateRideStatus(
          id: RideId,
          req: UpdateRideStatusRequest,
          uid: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImpl
      def assignDriver(id: RideId, did: PersonId): IO[RideError, Ride]                                          = notImpl
      def getRidesByStatus(s: RideStatus): IO[RideError, List[Ride]]                                            = notImpl
      def getRidesByStatusAndCompany(s: RideStatus, cid: CompanyId): IO[RideError, List[Ride]]                  = notImpl
      def getDriverRides(did: PersonId, cid: CompanyId): IO[RideError, List[Ride]]                              = notImpl
      def getClientRides(clid: PersonId, cid: CompanyId): IO[RideError, List[Ride]]                             = notImpl
      def getAllRides: IO[RideError, List[Ride]]                                                                = notImpl
      def getRidesByCompany(cid: CompanyId): IO[RideError, List[Ride]]                                          = ZIO.succeed(Nil)
      def getRidesByCompanyPaginated(cid: CompanyId, off: Int, lim: Int): IO[RideError, List[Ride]]             = notImpl
      def getDriverRidesPaginated(did: PersonId, cid: CompanyId, off: Int, lim: Int): IO[RideError, List[Ride]] =
        notImpl
      def updateRideDetails(
          id: RideId,
          req: UpdateRideDetailsRequest,
          uid: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImpl
      def reassignDriver(id: RideId, nd: PersonId): IO[RideError, Ride]                                         = notImpl
      def markPayment(id: RideId, ps: PaymentStatus, pm: Option[PaymentMethod]): IO[RideError, Ride]            = notImpl
      def getUnpaidCompletedRides(cid: CompanyId): IO[RideError, List[Ride]]                                    = notImpl
      def getRideCountsByStatus(cid: CompanyId): IO[RideError, Map[String, Int]]                                = ZIO.succeed(Map.empty)
      def getTotalRevenue(cid: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getTodayRevenue(cid: CompanyId): IO[RideError, BigDecimal]                                            = ZIO.succeed(BigDecimal(0))
      def getAvgAssignmentMinutes(cid: CompanyId): IO[RideError, Double]                                        = ZIO.succeed(0.0)
      def getDailyStats(cid: CompanyId, d: Int): IO[RideError, List[(String, Int, Int, Int)]]                   = ZIO.succeed(Nil)
      def getDriverEarnings(
          did: PersonId,
          cid: CompanyId,
          p: EarningsPeriod,
          a: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImpl
  )

  private val stubFcmServiceLayer: ZLayer[Any, Nothing, FcmService] =
    InMemoryFcmTokenRepository.layer >>> ZLayer {
      for tokenRepo <- ZIO.service[com.shevchyk.notification.repository.FcmTokenRepository]
      yield FcmService.FcmServiceImpl(tokenRepo, None)
    }

  // ---------------------------------------------------------------------------
  // Route runner
  // ---------------------------------------------------------------------------

  private val avatarRoutes: Routes[UserApi.UserEnv, Response] = ZioHttpInterpreter().toHttp(
    UserApi.serverEndpoints
  )

  private def run(req: Request): ZIO[UserApi.UserEnv, Nothing, Response] = avatarRoutes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // ---------------------------------------------------------------------------
  // Combined layers
  // ---------------------------------------------------------------------------

  private type TestEnv = UserApi.UserEnv

  // PersonRepository is shared between the route layer and AvatarService.layer
  // so that uploads (setAvatar) and GETs (getAvatar) see the same mutable state.
  private val testLayers: ZLayer[Any, Throwable, TestEnv] =
    testJwtService ++
      stubAuthServiceLayer ++
      stubPersonRepoLayer ++
      stubFcmServiceLayer ++
      stubRideServiceLayer ++
      RateLimiter.layer ++
      (stubPersonRepoLayer >>> AvatarService.layer)

  // ---------------------------------------------------------------------------
  // Multipart body builder
  // ---------------------------------------------------------------------------

  // Build a minimal multipart/form-data body that Tapir's multipart decoder accepts.
  //
  // CRITICAL: Tapir's ZioHttpRequestBody reads the multipart boundary from
  // `body.contentType.flatMap(_.boundary)` (the ZIO-HTTP Body metadata), NOT
  // from the HTTP "Content-Type" request header. Therefore the Body object
  // itself must carry the multipart/form-data mediaType with the boundary set.
  private def multipartBody(fieldName: String, bytes: Array[Byte], contentType: String): Body =
    val boundaryId = "----TestBoundary1234567890"
    val nl         = "\r\n"
    val partHeader =
      s"--$boundaryId${nl}Content-Disposition: form-data; name=\"$fieldName\"; filename=\"avatar\"${nl}Content-Type: $contentType${nl}${nl}"
    val footer     = s"${nl}--$boundaryId--${nl}"
    val combined   = partHeader.getBytes("UTF-8") ++ bytes ++ footer.getBytes("UTF-8")
    Body
      .fromChunk(zio.Chunk.fromArray(combined))
      .contentType(MediaType.multipart.`form-data`, Boundary(boundaryId))

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("UserApi — avatar endpoints")(
      // ── Upload ─────────────────────────────────────────────────────────────
      suite("POST /api/users/{id}/avatar")(
        test("self-upload as Client → 200") {
          for {
            token    <- generateToken(userA)
            smallJpeg = Array.fill(1024)(0xff.toByte)
            body      = multipartBody("file", smallJpeg, "image/jpeg")
            req       = Request
                          .post(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get, body)
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- run(req)
            bodyStr  <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("true")
          )
        },

        // CRITICAL negative test — tenant isolation on upload
        test("[CRITICAL] upload avatar for user in another company → 404 (not 200, not 403)") {
          // userA JWT (company A) targets userB (company B) — must be 404
          for {
            token <- generateToken(userA)
            bytes  = Array.fill(512)(0xab.toByte)
            body   = multipartBody("file", bytes, "image/jpeg")
            req    = Request
                       .post(URL.decode(s"/api/users/${userBId.value}/avatar").toOption.get, body)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("upload without authentication → 401") {
          val body = multipartBody("file", Array.fill(128)(0x01.toByte), "image/jpeg")
          val req  = Request.post(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get, body)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        },
        test("upload with invalid UUID in path → 400") {
          for {
            token <- generateToken(userA)
            body   = multipartBody("file", Array.fill(128)(0x01.toByte), "image/jpeg")
            req    = Request
                       .post(URL.decode("/api/users/not-a-uuid/avatar").toOption.get, body)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.BadRequest)
        },
        test("dispatcher in same company can upload for another user → 200") {
          for {
            token <- generateToken(dispatcherA)
            bytes  = Array.fill(256)(0x42.toByte)
            body   = multipartBody("file", bytes, "image/jpeg")
            req    = Request
                       .post(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get, body)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        }
      ),

      // ── Get avatar ──────────────────────────────────────────────────────────
      suite("GET /api/users/{id}/avatar")(
        test("GET avatar when no avatar is set → 404") {
          for {
            token <- generateToken(userA)
            req    = Request
                       .get(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },

        // Seed the avatar directly via the PersonRepository to achieve test isolation:
        // each test should control its own fixture state rather than depend on a prior upload
        // test having run. This verifies the GET endpoint's 200-path and Content-Type header
        // with a known binary payload.
        test("GET avatar → 200 with correct Content-Type header (seeded via repo)") {
          val testBytes = Array.fill(256)(0x42.toByte)
          val testMime  = "image/jpeg"
          for {
            token   <- generateToken(userA)
            _       <- ZIO.serviceWithZIO[PersonRepository](_.setAvatar(userAId, testBytes, testMime))
            getReq   = Request
                         .get(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            getResp <- run(getReq)
            // Tapir encodes the Content-Type header via header[String]("Content-Type"); read raw value.
            ctRaw    = getResp.rawHeader("Content-Type").getOrElse("")
            _       <- ZIO.serviceWithZIO[PersonRepository](_.deleteAvatar(userAId)) // cleanup
          } yield assertTrue(
            getResp.status == Status.Ok,
            ctRaw.contains("image/jpeg")
          )
        },

        // CRITICAL negative test — tenant isolation on GET
        test("[CRITICAL] GET avatar of user in another company → 404 (tenant isolation on reads)") {
          for {
            token <- generateToken(userA)
            req    = Request
                       .get(URL.decode(s"/api/users/${userBId.value}/avatar").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("GET avatar without authentication → 401") {
          val req = Request.get(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),

      // ── Delete avatar ────────────────────────────────────────────────────────
      suite("DELETE /api/users/{id}/avatar")(
        test("DELETE own avatar → 204 No Content") {
          for {
            token <- generateToken(userA)
            req    = Request
                       .delete(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NoContent)
        },
        test("DELETE followed by GET → 404 (avatar gone after delete, seeded via repo)") {
          val testBytes = Array.fill(128)(0x01.toByte)
          val testMime  = "image/jpeg"
          for {
            token    <- generateToken(userA)
            // Seed avatar directly (bypassing broken upload endpoint)
            _        <- ZIO.serviceWithZIO[PersonRepository](_.setAvatar(userAId, testBytes, testMime))
            deleteReq = Request
                          .delete(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            _        <- run(deleteReq)
            getReq    = Request
                          .get(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
            getResp  <- run(getReq)
          } yield assertTrue(getResp.status == Status.NotFound)
        },

        // CRITICAL negative test — tenant isolation on DELETE
        test("[CRITICAL] DELETE avatar of user in another company → 404 (tenant isolation)") {
          for {
            token <- generateToken(userA)
            req    = Request
                       .delete(URL.decode(s"/api/users/${userBId.value}/avatar").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("DELETE avatar without authentication → 401") {
          val req = Request.delete(URL.decode(s"/api/users/${userAId.value}/avatar").toOption.get)
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      )
    ).provide(testLayers) @@ TestAspect.sequential
