package com.shevchyk.app.openapi

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.openapi.AuthApi
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.application.InvoiceService
import com.shevchyk.billing.openapi.{BillingClientCompanyApi, BillingProfileApi, InvoiceApi}
import com.shevchyk.billing.repository.{
  ClientCompanyRepository => BillingClientCompanyRepository,
  CompanyBillingProfileRepository,
  InvoiceRepository
}
import com.shevchyk.core.application.{AuditService, AvatarService, EventHub, GeocodingService, GeofenceService}
import com.shevchyk.core.repository.{
  BlacklistRepository,
  ClientCompanyRepository,
  CompanyRepository,
  CompanySettingsRepository,
  EmergencyReassignmentRepository,
  GdprRepository,
  GeofenceRepository,
  NotificationPreferenceRepository,
  PersonRepository,
  RidePoolRepository,
  SessionRepository
}
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
import com.shevchyk.driver.openapi.DriverApi
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.repository.NotificationRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  AirportConfigService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideService
}
import com.shevchyk.ride.openapi.{ClientAddressApi, ExpenseApi, ExportApi, RideApi, RideTemplateApi, StatsApi}
import com.shevchyk.ride.repository.{
  ClientLocationRepository,
  ExpenseRepository,
  RideRatingRepository,
  RideRepository,
  RideTemplateRepository
}
import com.shevchyk.schedule.application.ScheduleService
import com.shevchyk.schedule.openapi.ScheduleApi
import sttp.tapir.AnyEndpoint
import sttp.tapir.server.ServerEndpoint
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import sttp.tapir.swagger.bundle.SwaggerInterpreter
import sttp.tapir.ztapir.*
import zio.Task
import zio.http.{Response, Routes}

/**
 * Central assembly of the Tapir-described API.
 *
 * Every module contributes its endpoint *descriptions* (used to render OpenAPI/Swagger UI) and its *server endpoints*
 * (the running logic). Both are interpreted here into zio-http [[Routes]] and mounted by `Application`. Swagger UI is
 * served at `/docs` and reflects exactly the endpoints below — there is a single source of truth.
 */
object OpenApiServer:

  /**
   * The combined environment of every server endpoint. Because `ZServerEndpoint` is contravariant in its environment,
   * the intersection of all module environments is a subtype of each, so every module's endpoints can be collected into
   * one list typed at [[ApiEnv]]. All of these layers are provided in `Application`.
   */
  type ApiEnv =
    JwtService & AuthService & RateLimiter & PersonRepository & AvatarService & FcmService & RideService &
      ScheduleService & InvoiceService & InvoiceRepository & ClientCompanyRepository & BillingClientCompanyRepository &
      CompanyBillingProfileRepository & GdprRepository & RideRepository & ExpenseRepository & NotificationRepository &
      AuditService & SessionRepository & TokenRepository & NotificationPreferenceRepository & BlacklistRepository &
      CompanySettingsRepository & GeofenceRepository & GeofenceService & RidePoolRepository & EventHub &
      EmergencyReassignmentRepository & RideRatingRepository & ClientAddressService & ClientLocationService &
      AirportCheckpointService & AirportConfigService & ChatService & RideTemplateRepository & DriverLocationService &
      HereRoutingService & GeocodingService & ClientLocationRepository & CompanyRepository

  // `ZServerEndpoint`'s environment is invariant, so module lists cannot be merged
  // into one typed list. But `zio.http.Routes` is contravariant in its environment, so
  // interpreting each module separately and combining with `++` narrows the combined
  // environment to the intersection of all module environments — exactly [[ApiEnv]].
  private def http[R](es: List[ZServerEndpoint[R, Any]]): Routes[R, Response] = ZioHttpInterpreter().toHttp(es)

  /**
   * All endpoint descriptions for the OpenAPI document, derived from the served endpoints.
   */
  private val allEndpoints: List[AnyEndpoint] =
    AuthApi.serverEndpoints.map(_.endpoint) :::
      UserApi.serverEndpoints.map(_.endpoint) :::
      RideApi.serverEndpoints.map(_.endpoint) :::
      ExpenseApi.serverEndpoints.map(_.endpoint) :::
      ExportApi.serverEndpoints.map(_.endpoint) :::
      RideTemplateApi.serverEndpoints.map(_.endpoint) :::
      StatsApi.serverEndpoints.map(_.endpoint) :::
      ClientAddressApi.serverEndpoints.map(_.endpoint) :::
      DriverApi.serverEndpoints.map(_.endpoint) :::
      ScheduleApi.serverEndpoints.map(_.endpoint) :::
      InvoiceApi.serverEndpoints.map(_.endpoint) :::
      BillingClientCompanyApi.serverEndpoints.map(_.endpoint) :::
      BillingProfileApi.serverEndpoints.map(_.endpoint) :::
      AuditApi.serverEndpoints.map(_.endpoint) :::
      GdprApi.serverEndpoints.map(_.endpoint) :::
      SessionApi.serverEndpoints.map(_.endpoint) :::
      BlacklistApi.serverEndpoints.map(_.endpoint) :::
      EmergencyApi.serverEndpoints.map(_.endpoint) :::
      CompanySettingsApi.serverEndpoints.map(_.endpoint) :::
      GeofenceApi.serverEndpoints.map(_.endpoint) :::
      NotificationApi.serverEndpoints.map(_.endpoint) :::
      NotificationPreferenceApi.serverEndpoints.map(_.endpoint) :::
      RidePoolApi.serverEndpoints.map(_.endpoint) :::
      ClientCompanyApi.serverEndpoints.map(_.endpoint) :::
      SuperAdminApi.serverEndpoints.map(_.endpoint) :::
      SuperAdminAirportApi.serverEndpoints.map(_.endpoint)

  /**
   * Swagger UI + the generated OpenAPI document, served under `/docs`.
   */
  private val swaggerEndpoints: List[ServerEndpoint[Any, Task]] = SwaggerInterpreter()
    .fromEndpoints[Task](allEndpoints, "Dispax API", "0.1.0")

  /**
   * zio-http routes that serve the documented API and the Swagger UI.
   */
  val routes: Routes[ApiEnv, Response] =
    http(AuthApi.serverEndpoints) ++
      http(UserApi.serverEndpoints) ++
      http(RideApi.serverEndpoints) ++
      http(ExpenseApi.serverEndpoints) ++
      http(ExportApi.serverEndpoints) ++
      http(RideTemplateApi.serverEndpoints) ++
      http(StatsApi.serverEndpoints) ++
      http(ClientAddressApi.serverEndpoints) ++
      http(DriverApi.serverEndpoints) ++
      http(ScheduleApi.serverEndpoints) ++
      http(InvoiceApi.serverEndpoints) ++
      http(BillingClientCompanyApi.serverEndpoints) ++
      http(BillingProfileApi.serverEndpoints) ++
      http(AuditApi.serverEndpoints) ++
      http(GdprApi.serverEndpoints) ++
      http(SessionApi.serverEndpoints) ++
      http(BlacklistApi.serverEndpoints) ++
      http(EmergencyApi.serverEndpoints) ++
      http(CompanySettingsApi.serverEndpoints) ++
      http(GeofenceApi.serverEndpoints) ++
      http(NotificationApi.serverEndpoints) ++
      http(NotificationPreferenceApi.serverEndpoints) ++
      http(RidePoolApi.serverEndpoints) ++
      http(ClientCompanyApi.serverEndpoints) ++
      http(SuperAdminApi.serverEndpoints) ++
      http(SuperAdminAirportApi.serverEndpoints) ++
      http(swaggerEndpoints)
