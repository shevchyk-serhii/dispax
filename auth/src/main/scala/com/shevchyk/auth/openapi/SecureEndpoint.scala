package com.shevchyk.auth.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Authenticated endpoint building block.
 *
 * Declares the HTTP `Bearer` security scheme once (so it shows up in OpenAPI as `bearerAuth`) and wires the
 * `serverSecurityLogic` that validates the JWT and resolves an [[AuthenticatedUser]]. Every authenticated endpoint is
 * built from [[secureEndpoint]] and only needs to add its own inputs/outputs and `serverLogic`.
 *
 * This mirrors the validation previously performed by `AuthMiddleware.authenticateRequest`: a missing/invalid token
 * yields `401` with `{ "error": "..." }`.
 */
object SecureEndpoint:

  /**
   * Base authenticated endpoint: takes a Bearer token, fails with a documented JSON error, and exposes the validated
   * [[AuthenticatedUser]] to the server logic.
   */
  val secureEndpoint: ZPartialServerEndpoint[JwtService, String, AuthenticatedUser, Unit, ApiError, Unit, Any] =
    endpoint
      .securityIn(auth.bearer[String]())
      .errorOut(
        oneOf[ApiError](
          oneOfVariant(StatusCode.Unauthorized, jsonBody[ApiError].description("Missing or invalid token")),
          oneOfVariant(StatusCode.Forbidden, jsonBody[ApiError].description("Insufficient permissions")),
          oneOfVariant(StatusCode.BadRequest, jsonBody[ApiError].description("Invalid request")),
          oneOfVariant(StatusCode.NotFound, jsonBody[ApiError].description("Not found")),
          oneOfDefaultVariant(jsonBody[ApiError].description("Error"))
        )
      )
      .zServerSecurityLogic[JwtService, AuthenticatedUser](validateBearer)

  /**
   * Validate the Bearer token into an [[AuthenticatedUser]], mapping JWT failures to a documented 401.
   */
  private def validateBearer(token: String): ZIO[JwtService, ApiError, AuthenticatedUser] = ZIO
    .serviceWithZIO[JwtService](_.validateToken(token))
    .mapBoth(
      {
        case _: InvalidTokenError | _: ExpiredTokenError => ApiError("Invalid or expired token")
        case _: JwtError                                 => ApiError("Authentication failed")
      },
      payload =>
        AuthenticatedUser(
          userId = payload.userId,
          email = payload.email,
          role = payload.role.toString,
          companyId = payload.companyId,
          clientCompanyId = payload.clientCompanyId
        )
    )
