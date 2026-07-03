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
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

/**
 * CRITICAL — routing lock for the self-service privilege-escalation fix.
 *
 * `PUT /api/users/{id}` is reachable by the account owner (checkRoleOrOwner) and `PUT /api/users/profile` is
 * owner-only. Before the fix both called the generic `AuthService.updateUser`, which applies EVERY field of the request
 * — any authenticated user could self-grant ADMIN (or isVip / clientCompanyId / status). The route must send owner
 * calls through `updateOwnProfile` (which rejects privileged fields — locked by AuthServiceSpec) and keep `updateUser`
 * for dispatcher/admin callers. This spec locks that routing decision with a recording AuthService stub.
 */
object UserSelfUpdatePrivilegeSpec extends ZIOSpecDefault:

  private val companyAId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-0000000000A1"))

  private val clientId: PersonId     = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val dispatcherId: PersonId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))

  private val client: Person = Person(
    id = clientId,
    name = "Clara Client",
    email = "clara@companya.de",
    role = PersonRole.Client,
    companyId = Some(companyAId)
  )

  private val dispatcher: Person = Person(
    id = dispatcherId,
    name = "Dieter Dispatcher",
    email = "dieter@companya.de",
    role = PersonRole.Dispatcher,
    companyId = Some(companyAId)
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
  // Recording AuthService stub: records WHICH update method the route invoked.
  // ---------------------------------------------------------------------------

  private def dummyDto(id: UUID): UserDto = UserDto(id = id, email = "x@x.de", name = "X", role = "CLIENT")

  private class RecordingAuthService(val calls: Ref[List[String]]) extends AuthService:
    private def notImpl = ZIO.die(new NotImplementedError("UserSelfUpdatePrivilegeSpec AuthService stub"))

    def login(
        email: String,
        password: String,
        deviceInfo: Option[String],
        ipAddress: Option[String]
    ): IO[AuthError, LoginResponse] = notImpl
    def createUser(req: CreateUserRequest, companyId: CompanyId): IO[AuthError, UserDto] = notImpl
    def getUserById(id: UUID): IO[AuthError, UserDto]                                    = notImpl
    def getUserByEmail(email: String): IO[AuthError, UserDto]                            = notImpl

    def updateUser(id: UUID, companyId: CompanyId, req: UpdateUserRequest): IO[AuthError, UserDto] = calls
      .update("updateUser" :: _)
      .as(dummyDto(id))

    def updateOwnProfile(id: UUID, companyId: CompanyId, req: UpdateUserRequest): IO[AuthError, UserDto]    = calls
      .update("updateOwnProfile" :: _)
      .as(dummyDto(id))

    def upgradeProvisionalClient(
        id: UUID,
        companyId: CompanyId,
        req: UpgradeProvisionalClientRequest
    ): IO[AuthError, UserDto] = notImpl
    def deleteUser(id: UUID, companyId: CompanyId): IO[AuthError, Unit]                                     = notImpl
    def changePassword(userId: UUID, companyId: CompanyId, req: ChangePasswordRequest): IO[AuthError, Unit] = notImpl
    def validateToken(token: String): IO[AuthError, UserDto]                                                = notImpl
    def refreshToken(token: String): IO[AuthError, String]                                                  = notImpl

    def getAllUsers(role: Option[PersonRole], status: Option[UserStatus]): IO[AuthError, List[UserDto]] = ZIO.succeed(
      Nil
    )
    def searchUsers(query: String): IO[AuthError, List[UserDto]]                                        = ZIO.succeed(Nil)

  private val recordingAuthLayer: ZLayer[Any, Nothing, AuthService & Ref[List[String]]] = ZLayer.fromZIOEnvironment(
    Ref
      .make(List.empty[String])
      .map(ref => ZEnvironment[AuthService, Ref[List[String]]](RecordingAuthService(ref), ref))
  )

  // ---------------------------------------------------------------------------
  // Minimal env stubs (same shapes as AvatarApiSpec)
  // ---------------------------------------------------------------------------

  private val stubPersonRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.fromZIO(
    for peopleRef <- Ref.Synchronized.make(Map[PersonId, Person](clientId -> client, dispatcherId -> dispatcher))
    yield new PersonRepository:
      private def notImpl                                                                       = ZIO.die(new NotImplementedError("UserSelfUpdatePrivilegeSpec PersonRepository stub"))
      def create(p: Person): Task[Person]                                                       = notImpl
      def findById(id: PersonId): Task[Option[Person]]                                          = peopleRef.get.map(_.get(id))
      def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]                = peopleRef.get.map(
        _.get(id).filter(_.companyId.contains(cid))
      )
      def findByEmail(e: String): Task[Option[Person]]                                          = peopleRef.get.map(_.values.find(_.email == e))
      def findByRole(r: PersonRole): Task[List[Person]]                                         = notImpl
      def findByRoleAndCompany(r: PersonRole, cid: CompanyId): Task[List[Person]]               = notImpl
      def findByCompanyId(cid: CompanyId): Task[List[Person]]                                   = notImpl
      def findAll(): Task[List[Person]]                                                         = notImpl
      def update(p: Person): Task[Person]                                                       = notImpl
      def delete(id: PersonId): Task[Unit]                                                      = notImpl
      def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                       = notImpl
      def findByStatus(s: UserStatus): Task[List[Person]]                                       = notImpl
      def searchByQuery(q: String): Task[List[Person]]                                          = notImpl
      def updateLastLogin(id: PersonId, companyId: Option[CompanyId]): Task[Unit]               = ZIO.unit
      def findByClientCompany(ccid: ClientCompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
      def upsertDriverRow(pid: PersonId): Task[Unit]                                            = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                          = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, b: Array[Byte], ct: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                          = ZIO.unit
  )

  private val stubFcmServiceLayer: ZLayer[Any, Nothing, FcmService] =
    InMemoryFcmTokenRepository.layer >>> ZLayer {
      for tokenRepo <- ZIO.service[com.shevchyk.notification.repository.FcmTokenRepository]
      yield FcmService.FcmServiceImpl(tokenRepo, None)
    }

  private val stubCompanyRepoLayer: ZLayer[Any, Nothing, com.shevchyk.core.repository.CompanyRepository] = ZLayer
    .succeed(
      new com.shevchyk.core.repository.CompanyRepository:
        private def notImpl                                  = ZIO.die(new NotImplementedError("UserSelfUpdatePrivilegeSpec CompanyRepository stub"))
        def findById(id: CompanyId): Task[Option[Company]]   = ZIO.none
        def findAll(): Task[List[Company]]                   = ZIO.succeed(Nil)
        def create(company: Company): Task[Company]          = notImpl
        def update(company: Company): Task[Company]          = notImpl
        def countByStatus(): Task[Map[CompanyStatus, Int]]   = ZIO.succeed(Map.empty)
        def softDelete(id: CompanyId): Task[Option[Company]] = notImpl
    )

  // ---------------------------------------------------------------------------
  // Route runner
  // ---------------------------------------------------------------------------

  private val routes: Routes[UserApi.UserEnv, Response] = ZioHttpInterpreter().toHttp(UserApi.serverEndpoints)

  private def run(req: Request): ZIO[UserApi.UserEnv, Nothing, Response] = routes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def putJson(path: String, token: String, json: String): Request = Request
    .put(URL.decode(path).toOption.get, Body.fromString(json))
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(MediaType.application.json))

  private def recordedCalls: ZIO[Ref[List[String]], Nothing, List[String]] = ZIO.serviceWithZIO[Ref[List[String]]](
    _.getAndSet(List.empty)
  )

  private val layers =
    recordingAuthLayer ++ stubPersonRepoLayer ++ testJwtService ++ stubFcmServiceLayer ++
      ZLayer.succeed(StubRideService.notImplemented("UserSelfUpdatePrivilegeSpec RideService stub")) ++
      RateLimiter.layer ++ (stubPersonRepoLayer >>> AvatarService.layer) ++ stubCompanyRepoLayer

  def spec =
    suite("UserApi update routing — owner vs staff (privilege escalation lock)")(
      test("owner PUT /api/users/{ownId} goes through updateOwnProfile, never the generic updateUser") {
        for {
          token <- generateToken(client)
          resp  <- run(putJson(s"/api/users/${clientId.value}", token, """{"role":"ADMIN","roles":["ADMIN"]}"""))
          calls <- recordedCalls
        } yield assertTrue(
          resp.status == Status.Ok, // the recording stub accepts; the real rejection is locked in AuthServiceSpec
          calls == List("updateOwnProfile")
        )
      },
      test("dispatcher PUT /api/users/{id} keeps the privileged updateUser path") {
        for {
          token <- generateToken(dispatcher)
          resp  <- run(putJson(s"/api/users/${clientId.value}", token, """{"role":"DRIVER"}"""))
          calls <- recordedCalls
        } yield assertTrue(
          resp.status == Status.Ok,
          calls == List("updateUser")
        )
      },
      test("owner PUT /api/users/profile goes through updateOwnProfile") {
        for {
          token <- generateToken(client)
          resp  <- run(putJson("/api/users/profile", token, """{"name":"New Name"}"""))
          calls <- recordedCalls
        } yield assertTrue(
          resp.status == Status.Ok,
          calls == List("updateOwnProfile")
        )
      }
    ).provide(layers) @@ TestAspect.sequential
