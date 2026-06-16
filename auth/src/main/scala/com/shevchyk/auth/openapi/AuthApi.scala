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

  // -- Endpoint descriptions (schema only) ---------------------------------

  val loginEndpoint = endpoint.post
    .in("api" / "auth" / "login")
    .in(jsonBody[LoginRequest])
    .in(clientIp)
    .out(jsonBody[LoginResponse])
    .errorOut(
      oneOf[ApiError](
        oneOfVariant(StatusCode.Unauthorized, jsonBody[ApiError].description("Invalid credentials")),
        oneOfVariant(StatusCode.TooManyRequests, jsonBody[ApiError].description("Rate limit exceeded")),
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

  private val loginServer = loginEndpoint.zServerLogic[AuthEnv] { case (req, ip) =>
    val ipKey = ip.getOrElse("unknown")
    for {
      allowed  <- ZIO.serviceWithZIO[RateLimiter](_.checkRate(ipKey))
      _        <- ZIO.unless(allowed)(ZIO.fail(ApiError("Too many requests. Please try again later.")))
      response <- ZIO
                    .serviceWithZIO[AuthService](_.login(req.email, req.password))
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
