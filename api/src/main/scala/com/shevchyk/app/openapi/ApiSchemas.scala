package com.shevchyk.app.openapi

import com.shevchyk.app.openapi.BlacklistApi.BlacklistEntryDto
import com.shevchyk.app.openapi.CompanySettingsApi.TariffDto
import com.shevchyk.app.openapi.EmergencyApi.EmergencyReassignmentDto
import com.shevchyk.app.openapi.GeofenceApi.GeofenceAlertDto
import com.shevchyk.app.openapi.RidePoolApi.{PoolDetailResponse, RidePoolDto, RidePoolMemberDto}
import com.shevchyk.app.openapi.UserApi.{
  AvatarUploadResponse,
  DailyStatsEntry,
  DriverStatsEntry,
  ReminderMinutesRequest,
  RideStatsResponse,
  SuccessResponse,
  UserStatsResponse
}
import com.shevchyk.core.domain.*
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import sttp.tapir.Schema

/**
 * Tapir [[Schema]] instances for the api-module endpoint bodies, collected in one place. The domain types already
 * derive zio-json codecs; here we add the matching schemas so the same case classes can be used directly as Tapir
 * bodies and surface in the OpenAPI document. Each `*Api` object brings these into scope with `import
 * ApiSchemas.given`.
 *
 * Schemas already provided elsewhere are intentionally absent: `PersonId`/`CompanyId`/`PersonRole`/... live in their
 * companions in `core.domain`, refined types in `core.domain.RefinedTypes`, and ride-module bodies in
 * `ride.openapi.RideSchemas` (not imported into the api module, so `RideId` is provided here).
 */
object ApiSchemas:

  // -- Id wrappers ----------------------------------------------------------
  given Schema[RideId]                   = Schema.derived
  given Schema[AuditLogId]               = Schema.derived
  given Schema[BlacklistEntryId]         = Schema.derived
  given Schema[EmergencyReassignmentId]  = Schema.derived
  given Schema[GdprConsentId]            = Schema.derived
  given Schema[GdprRequestId]            = Schema.derived
  given Schema[GeofenceId]               = Schema.derived
  given Schema[AppNotificationId]        = Schema.derived
  given Schema[NotificationPreferenceId] = Schema.derived
  given Schema[RidePoolId]               = Schema.derived
  given Schema[RidePoolMemberId]         = Schema.derived

  // -- Enums (string-based) -------------------------------------------------
  given Schema[AuditAction]        = Schema.derivedEnumeration[AuditAction].defaultStringBased
  given Schema[EmergencyReason]    = Schema.derivedEnumeration[EmergencyReason].defaultStringBased
  given Schema[ReassignmentStatus] = Schema.derivedEnumeration[ReassignmentStatus].defaultStringBased
  given Schema[ConsentType]        = Schema.derivedEnumeration[ConsentType].defaultStringBased
  given Schema[GdprRequestType]    = Schema.derivedEnumeration[GdprRequestType].defaultStringBased
  given Schema[GdprRequestStatus]  = Schema.derivedEnumeration[GdprRequestStatus].defaultStringBased
  given Schema[GeofenceType]       = Schema.derivedEnumeration[GeofenceType].defaultStringBased
  given Schema[PoolStatus]         = Schema.derivedEnumeration[PoolStatus].defaultStringBased
  given Schema[PoolMemberStatus]   = Schema.derivedEnumeration[PoolMemberStatus].defaultStringBased

  // -- Domain bodies --------------------------------------------------------
  given Schema[AuditLogEntry]          = Schema.derived
  given Schema[BlacklistEntry]         = Schema.derived
  given Schema[ClientCompany]          = Schema.derived
  given Schema[CompanySettings]        = Schema.derived
  given Schema[EmergencyReassignment]  = Schema.derived
  given Schema[GdprConsent]            = Schema.derived
  given Schema[GdprRequest]            = Schema.derived
  given Schema[GdprDataExport]         = Schema.derived
  given Schema[Geofence]               = Schema.derived
  given Schema[GeofenceAlert]          = Schema.derived
  given Schema[AppNotification]        = Schema.derived
  given Schema[NotificationPreference] = Schema.derived
  given Schema[RidePool]               = Schema.derived
  given Schema[RidePoolMember]         = Schema.derived
  given Schema[SessionDto]             = Schema.derived

  // -- Request / response bodies --------------------------------------------
  given Schema[CreateBlacklistRequest]              = Schema.derived
  given Schema[CreateClientCompanyRequest]          = Schema.derived
  given Schema[UpdateCompanySettingsRequest]        = Schema.derived
  given Schema[TariffDto]                           = Schema.derived
  given Schema[EmergencyReassignRequest]            = Schema.derived
  given Schema[UpdateConsentRequest]                = Schema.derived
  given Schema[CreateGeofenceRequest]               = Schema.derived
  given Schema[UnreadCountResponse]                 = Schema.derived
  given Schema[UpdateNotificationPreferenceRequest] = Schema.derived
  given Schema[CreatePoolRequest]                   = Schema.derived
  given Schema[AddToPoolRequest]                    = Schema.derived
  given Schema[RidePoolDto]                         = Schema.derived
  given Schema[RidePoolMemberDto]                   = Schema.derived
  given Schema[PoolDetailResponse]                  = Schema.derived
  given Schema[BlacklistEntryDto]                   = Schema.derived
  given Schema[EmergencyReassignmentDto]            = Schema.derived
  given Schema[GeofenceAlertDto]                    = Schema.derived

  // -- UserApi stats / response bodies --------------------------------------
  given Schema[RideStatsResponse]      = Schema.derived
  given Schema[DailyStatsEntry]        = Schema.derived
  given Schema[DriverStatsEntry]       = Schema.derived
  given Schema[UserStatsResponse]      = Schema.derived
  given Schema[ReminderMinutesRequest] = Schema.derived
  given Schema[SuccessResponse]        = Schema.derived
  given Schema[AvatarUploadResponse]   = Schema.derived
