package com.shevchyk.core.openapi

import sttp.tapir.Schema
import zio.json.{DeriveJsonDecoder, DeriveJsonEncoder, JsonDecoder, JsonEncoder}

/**
 * Uniform error body returned by the API. The existing zio-http handlers already emit `{"error": "..."}` JSON for
 * failures, so this mirrors that exact shape. It is declared once here so every Tapir endpoint can reference it in its
 * `errorOut`, giving consistent OpenAPI documentation for error responses.
 */
final case class ApiError(error: String, scheduleConflict: Option[ScheduleConflictDetails] = None)

object ApiError:
  given JsonEncoder[ApiError] = DeriveJsonEncoder.gen[ApiError]
  given JsonDecoder[ApiError] = DeriveJsonDecoder.gen[ApiError]
  given Schema[ApiError]      = Schema.derived[ApiError]

/**
 * Structured details of a schedule-conflict, attached to the error body so the client can render a human-readable,
 * localized dialog (route + client + the dispatcher's local pickup time) instead of a raw id. Present only on the
 * assign/reassign schedule-conflict response; absent (None) for every other error.
 */
final case class ScheduleConflictDetails(
    rideId: Option[String] = None,
    clientId: Option[String] = None,
    from: Option[String] = None,
    to: Option[String] = None,
    pickupAt: Option[String] = None
)

object ScheduleConflictDetails:
  given JsonEncoder[ScheduleConflictDetails] = DeriveJsonEncoder.gen[ScheduleConflictDetails]
  given JsonDecoder[ScheduleConflictDetails] = DeriveJsonDecoder.gen[ScheduleConflictDetails]
  given Schema[ScheduleConflictDetails]      = Schema.derived[ScheduleConflictDetails]
