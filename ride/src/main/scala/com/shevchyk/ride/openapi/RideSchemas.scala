package com.shevchyk.ride.openapi

import com.shevchyk.core.domain.RideId
import com.shevchyk.ride.application.service.{LocationWithTimestamp, RideLocationsResponse}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.{DatevExportResponse, DatevCsvSection, DatevSummarySection}
import com.shevchyk.ride.infrastructure.http.{
  CancellationStatsEntry,
  ClientValueEntry,
  DriverPerformanceEntry,
  DriverRatingEntry,
  PayrollSummary,
  PeakHourEntry
}
import sttp.tapir.Schema

/**
 * Tapir [[Schema]] instances for the ride-module request/response bodies. The domain types already derive zio-json
 * codecs; here we add the matching schemas so the same case classes can be used directly as Tapir bodies and surface in
 * the OpenAPI document.
 */
object RideSchemas:

  // Core id wrapper missing a schema in core (PersonId/CompanyId already provide theirs).
  given Schema[RideId] = Schema.derived

  // Id wrappers
  given Schema[RideRatingId]    = Schema.derived
  given Schema[ExpenseId]       = Schema.derived
  given Schema[RideTemplateId]  = Schema.derived
  given Schema[ClientAddressId] = Schema.derived
  given Schema[ChatMessageId]   = Schema.derived

  // Enums
  given Schema[ExpenseCategory]   = Schema.derivedEnumeration.defaultStringBased
  given Schema[RecurrencePattern] = Schema.derivedEnumeration.defaultStringBased

  // Domain response bodies
  given Schema[ChatMessage]   = Schema.derived
  given Schema[RideRating]    = Schema.derived
  given Schema[Expense]       = Schema.derived
  given Schema[RideTemplate]  = Schema.derived
  given Schema[ClientAddress] = Schema.derived

  // Request bodies
  given Schema[CreateRatingRequest]        = Schema.derived
  given Schema[CreateExpenseRequest]       = Schema.derived
  given Schema[CreateRideTemplateRequest]  = Schema.derived
  given Schema[GenerateRidesRequest]       = Schema.derived
  given Schema[SaveClientAddressRequest]   = Schema.derived
  given Schema[UpdateClientAddressRequest] = Schema.derived

  // Location responses
  given Schema[LocationWithTimestamp] = Schema.derived
  given Schema[RideLocationsResponse] = Schema.derived

  // Export / stats responses
  given Schema[DatevCsvSection]        = Schema.derived
  given Schema[DatevSummarySection]    = Schema.derived
  given Schema[DatevExportResponse]    = Schema.derived
  given Schema[PayrollSummary]         = Schema.derived
  given Schema[PeakHourEntry]          = Schema.derived
  given Schema[ClientValueEntry]       = Schema.derived
  given Schema[DriverPerformanceEntry] = Schema.derived
  given Schema[DriverRatingEntry]      = Schema.derived
  given Schema[CancellationStatsEntry] = Schema.derived
