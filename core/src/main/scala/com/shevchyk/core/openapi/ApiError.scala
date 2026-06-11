package com.shevchyk.core.openapi

import sttp.tapir.Schema
import zio.json.{DeriveJsonDecoder, DeriveJsonEncoder, JsonDecoder, JsonEncoder}

/**
 * Uniform error body returned by the API. The existing zio-http handlers already emit `{"error": "..."}` JSON for
 * failures, so this mirrors that exact shape. It is declared once here so every Tapir endpoint can reference it in its
 * `errorOut`, giving consistent OpenAPI documentation for error responses.
 */
final case class ApiError(error: String)

object ApiError:
  given JsonEncoder[ApiError] = DeriveJsonEncoder.gen[ApiError]
  given JsonDecoder[ApiError] = DeriveJsonDecoder.gen[ApiError]
  given Schema[ApiError]      = Schema.derived[ApiError]
