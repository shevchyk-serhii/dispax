package com.shevchyk.auth.openapi

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the public authentication endpoints. These replace the hand-written zio-http
 * handlers in `AuthRoutes` while keeping the exact same paths, request/response shapes and status codes. The same
 * `ServerEndpoint`s drive both the OpenAPI document and the running server.
 */
object AuthApi:

  private val authTag = "Authentication"

  // Sentinel message that tags a rate-limit failure so the Tapir error `oneOf` can route it to 429
  // (see loginEndpoint.errorOut). Also the body a throttled client receives.
  private[openapi] val RateLimitError = "Too many requests. Please try again later."

  // -- Endpoint descriptions (schema only) ---------------------------------

  val loginEndpoint = endpoint.post
    .in("api" / "auth" / "login")
    .in(jsonBody[LoginRequest])
    .in(clientIp)
    .in(header[Option[String]]("User-Agent"))
    .out(jsonBody[LoginResponse])
    // All three variants carry a bare `ApiError` body, so Tapir cannot pick the variant by TYPE — it
    // matched the FIRST (Unauthorized) for every failure, making the 429 unreachable (throttling
    // surfaced as 401). Discriminate the rate-limit case by VALUE: the login server fails with the
    // sentinel `RateLimitError` message, matched here to the 429 variant; everything else stays 401
    // or the default.
    .errorOut(
      oneOf[ApiError](
        oneOfVariantValueMatcher(
          StatusCode.TooManyRequests,
          jsonBody[ApiError].description("Rate limit exceeded")
        ) { case ApiError(RateLimitError, _) => true },
        oneOfVariant(StatusCode.Unauthorized, jsonBody[ApiError].description("Invalid credentials")),
        oneOfDefaultVariant(jsonBody[ApiError].description("Error"))
      )
    )
    .tag(authTag)
    .summary("Authenticate with email and password")

  val validateEndpoint = endpoint.get
    .in("api" / "auth" / "validate")
    .securityIn(auth.bearer[String]())
    .out(jsonBody[TokenValidationResponse])
    .errorOut(statusCode(StatusCode.Unauthorized).and(jsonBody[ApiError]))
    .tag(authTag)
    .summary("Validate the current bearer token")

  val logoutEndpoint = endpoint.post
    .in("api" / "auth" / "logout")
    .out(jsonBody[AuthSuccessResponse])
    .errorOut(jsonBody[ApiError])
    .tag(authTag)
    .summary("Log out (stateless stub)")

  val passwordResetEndpoint = endpoint.post
    .in("api" / "auth" / "password" / "reset-request")
    .in(jsonBody[PasswordResetRequest])
    .out(jsonBody[AuthSuccessResponse])
    .errorOut(jsonBody[ApiError])
    .tag(authTag)
    .summary("Request a password reset link")

  val biometricSetupEndpoint = endpoint.post
    .in("api" / "auth" / "biometric" / "setup")
    .in(jsonBody[BiometricSetupRequest])
    .out(jsonBody[BiometricSetupResponse])
    .errorOut(jsonBody[ApiError])
    .tag(authTag)
    .summary("Enable biometric login (stub)")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    loginEndpoint,
    validateEndpoint,
    logoutEndpoint,
    passwordResetEndpoint,
    biometricSetupEndpoint
  )

  // -- Server logic --------------------------------------------------------
  //
  // All server endpoints share one environment so they can be interpreted together.
  type AuthEnv = AuthService & RateLimiter & JwtService

  private val loginServer = loginEndpoint.zServerLogic[AuthEnv] { case (req, ip, userAgent) =>
    // Throttle by BOTH source IP and normalized email: a single IP hammering one login is caught by
    // the ip bucket, and distributed password-spraying on one account (one attempt per IP) is caught
    // by the per-email bucket. Both must pass. The email is lowercased so case variants share a bucket.
    //
    // The email bucket counts only FAILED attempts (peek before login, record after a credentials
    // failure). Counting every attempt would hand an attacker a targeted lockout: ~10 requests per
    // window carrying the victim's email — from any IPs, wrong password and all — would 429 the
    // victim's own correct-password login indefinitely. Successful logins never consume the bucket.
    val ipKey    = s"ip:${ip.getOrElse("unknown")}"
    val emailKey = s"email:${req.email.trim.toLowerCase}"
    for {
      limiter      <- ZIO.service[RateLimiter]
      ipOk         <- limiter.checkRate(ipKey)
      emailLimited <- limiter.isLimited(emailKey)
      _            <- ZIO.unless(ipOk && !emailLimited)(ZIO.fail(ApiError(RateLimitError)))
      response     <- ZIO
                        .serviceWithZIO[AuthService](_.login(req.email, req.password, userAgent, ip))
                        .tapError {
                          case _: UserNotFound | _: InvalidCredentials => limiter.record(emailKey)
                          case _                                       => ZIO.unit
                        }
                        .mapError {
                          case _: UserNotFound | _: InvalidCredentials => ApiError("Invalid credentials")
                          case _                                       => ApiError("Internal server error")
                        }
    } yield response
  }

  // validate really checks the token: a valid bearer yields { valid: true }, an
  // invalid/expired/missing one yields 401 — same behaviour as the old handler.
  private val validateServer: ZServerEndpoint[AuthEnv, Any] = validateEndpoint
    .zServerSecurityLogic[AuthEnv, TokenValidationResponse] { token =>
      ZIO
        .serviceWithZIO[JwtService](_.validateToken(token))
        .mapBoth(_ => ApiError("Invalid or expired token"), _ => TokenValidationResponse(valid = true))
    }
    .serverLogic(result => _ => ZIO.succeed(result))

  private val logoutServer = logoutEndpoint.zServerLogic[AuthEnv](_ => ZIO.succeed(AuthSuccessResponse(success = true)))

  private val passwordResetServer = passwordResetEndpoint.zServerLogic[AuthEnv](_ =>
    ZIO.succeed(AuthSuccessResponse(success = true, message = Some("Reset link sent if account exists")))
  )

  private val biometricSetupServer = biometricSetupEndpoint.zServerLogic[AuthEnv](_ =>
    ZIO.succeed(BiometricSetupResponse(success = true, biometricEnabled = true))
  )

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[AuthEnv, Any]] = List(
    loginServer,
    validateServer,
    logoutServer,
    passwordResetServer,
    biometricSetupServer
  )
