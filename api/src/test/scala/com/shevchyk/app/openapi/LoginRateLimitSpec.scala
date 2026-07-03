package com.shevchyk.app.openapi

import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.openapi.AuthApi
import com.shevchyk.core.domain.{CompanyId, PersonRole, UserStatus}

/**
 * Endpoint-level tests for POST /api/auth/login rate limiting.
 *
 * Regression coverage for the audit findings:
 *   - a rate-limited login must answer 429 TooManyRequests (all three `oneOf` error variants shared the bare `ApiError`
 *     body, so Tapir always matched the first variant and throttling surfaced as 401);
 *   - the limiter must be keyed by BOTH source IP and normalized email, so a distributed password-spraying attack on
 *     one account (one attempt per IP) is still throttled.
 *
 * Runs the REAL `AuthApi.serverEndpoints` through `ZioHttpInterpreter` with stub AuthService/RateLimiter layers.
 */
object LoginRateLimitSpec extends ZIOSpecDefault:

  // -- Stub AuthService ------------------------------------------------------
  private def notImpl: Nothing = throw new NotImplementedError("LoginRateLimitSpec stub")

  private val userDto = UserDto(
    id = UUID.fromString("000000CC-0000-0000-0000-000000000001"),
    email = "client@test.de",
    name = "Client",
    role = "CLIENT"
  )

  private def authService(
      result: IO[AuthError, LoginResponse]
  ): ZLayer[Any, Nothing, AuthService] = ZLayer.succeed(
    new AuthService:
      def login(email: String, password: String, deviceInfo: Option[String], ipAddress: Option[String])      = result
      def createUser(request: CreateUserRequest, companyId: CompanyId)                                       = notImpl
      def getUserById(id: UUID)                                                                              = notImpl
      def getUserByEmail(email: String)                                                                      = notImpl
      def updateUser(id: UUID, companyId: CompanyId, request: UpdateUserRequest)                             = notImpl
      def updateOwnProfile(id: UUID, companyId: CompanyId, request: UpdateUserRequest)                       = notImpl
      def upgradeProvisionalClient(id: UUID, companyId: CompanyId, request: UpgradeProvisionalClientRequest) = notImpl
      def deleteUser(id: UUID, companyId: CompanyId)                                                         = notImpl
      def changePassword(userId: UUID, companyId: CompanyId, request: ChangePasswordRequest)                 = notImpl
      def validateToken(token: String)                                                                       = notImpl
      def refreshToken(token: String)                                                                        = notImpl
      def getAllUsers(role: Option[PersonRole], status: Option[UserStatus])                                  = notImpl
      def searchUsers(query: String)                                                                         = notImpl
  )

  private val loginOk: IO[AuthError, LoginResponse]    = ZIO.succeed(LoginResponse(userDto, "test-token"))
  private val loginWrong: IO[AuthError, LoginResponse] = ZIO.fail(InvalidCredentials("client@test.de"))

  // -- Stub / recording rate limiters ---------------------------------------
  private def limiter(f: String => Boolean): ZLayer[Any, Nothing, RateLimiter] = ZLayer.succeed(
    new RateLimiter:
      def checkRate(key: String): UIO[Boolean] = ZIO.succeed(f(key))
  )

  private val denyAll: ZLayer[Any, Nothing, RateLimiter]  = limiter(_ => false)
  private val allowAll: ZLayer[Any, Nothing, RateLimiter] = limiter(_ => true)

  /**
   * Denies exactly one key, allows everything else.
   */
  private def denyKey(key: String): ZLayer[Any, Nothing, RateLimiter] = limiter(_ != key)

  /**
   * Allows everything and records the keys it was asked about.
   */
  final private class RecordingLimiter(val keys: Ref[List[String]]) extends RateLimiter:
    def checkRate(key: String): UIO[Boolean] = keys.update(_ :+ key).as(true)

  // -- Request plumbing ------------------------------------------------------
  private def run(
      req: Request,
      layers: ZLayer[Any, Throwable, AuthApi.AuthEnv]
  ): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(AuthApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(layers)

  private def loginReq(email: String = "client@test.de"): Request = Request
    .post(
      URL.decode("/api/auth/login").toOption.get,
      Body.fromString(s"""{"email":"$email","password":"secret123"}""")
    )
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  def spec =
    suite("AuthApi — POST /api/auth/login rate limiting [real serverEndpoints]")(
      test("a rate-limited login answers 429 TooManyRequests, not 401") {
        val layers = authService(loginOk) ++ denyAll ++ TestJwt.serviceLayer
        for {
          resp <- run(loginReq(), layers)
          body <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.TooManyRequests,
          body.contains("Too many requests")
        )
      },
      test("wrong credentials still answer 401 when the limiter allows") {
        val layers = authService(loginWrong) ++ allowAll ++ TestJwt.serviceLayer
        for {
          resp <- run(loginReq(), layers)
          body <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Unauthorized,
          body.contains("Invalid credentials")
        )
      },
      test("a successful login still answers 200 with the token") {
        val layers = authService(loginOk) ++ allowAll ++ TestJwt.serviceLayer
        for {
          resp <- run(loginReq(), layers)
          body <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("test-token")
        )
      },
      test("an exhausted per-email bucket throttles the login even when the IP bucket allows") {
        // Distributed password spraying: each attempt comes from a fresh IP, so only the
        // per-email bucket can catch it. Deny exactly that key.
        val layers = authService(loginOk) ++ denyKey("email:client@test.de") ++ TestJwt.serviceLayer
        for {
          resp <- run(loginReq(), layers)
        } yield assertTrue(resp.status == Status.TooManyRequests)
      },
      test("the limiter is consulted with both the ip- and the normalized email-key") {
        for {
          keys    <- Ref.make(List.empty[String])
          recorder = new RecordingLimiter(keys)
          layers   = authService(loginOk) ++ ZLayer.succeed(recorder: RateLimiter) ++ TestJwt.serviceLayer
          resp    <- run(loginReq(email = "Client@Test.DE"), layers)
          seen    <- keys.get
        } yield assertTrue(
          resp.status == Status.Ok,
          // no client address is attached to the stub request → the ip bucket key falls back to "unknown"
          seen.exists(_.startsWith("ip:")),
          seen.contains("email:client@test.de")
        )
      }
    ) @@ TestAspect.sequential
