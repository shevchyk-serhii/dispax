package com.shevchyk.core.openapi

import sttp.tapir.*
import sttp.tapir.json.zio.*

/**
 * Building blocks shared by every documented endpoint.
 *
 * The handlers in this codebase already encode their own success/error responses as raw bodies, so for documentation we
 * describe the *outer shape* (paths, query params, security, error body) with Tapir and let a thin adapter forward the
 * actual request to the existing zio-http handler. Authenticated endpoints declare their own module-local `secureBase`
 * (e.g. `RideSecure`, `AppSecure`, `UserApi`) that validates the bearer token and builds the `AuthenticatedUser` with
 * wire-form roles via `PersonRole.toWire`.
 */
object BaseEndpoint:

  /**
   * Base for public (unauthenticated) endpoints. Declares the common `application/json` error body so failures are
   * documented uniformly as `{ "error": "..." }`.
   */
  val publicEndpoint: PublicEndpoint[Unit, ApiError, Unit, Any] = endpoint.errorOut(jsonBody[ApiError])
