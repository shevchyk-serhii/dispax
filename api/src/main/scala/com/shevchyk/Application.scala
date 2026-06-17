package com.shevchyk

import com.shevchyk.ride.application.service.{
  RideService,
  ClientLocationService,
  AirportCheckpointService,
  AirportConfigService,
  ChatService,
  ClientAddressService
}
import com.shevchyk.ride.repository.{
  RideRepository,
  PostgresRideRepository,
  AirportConfigRepository,
  ClientLocationRepository,
  PostgresClientLocationRepository,
  ClientAddressRepository,
  PostgresClientAddressRepository,
  ChatMessageRepository,
  ExpenseRepository,
  RideTemplateRepository,
  RideRatingRepository,
  PostgresExpenseRepository,
  PostgresRideRatingRepository,
  PostgresRideTemplateRepository
}
import com.shevchyk.driver.application.{DriverLocationService, EtaService, HereRoutingService}
import com.shevchyk.core.config.HereConfig
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.repository.ScheduleDayRepository
import com.shevchyk.billing.application.{InvoiceService, PaymentChecker}
import com.shevchyk.billing.repository.{
  InvoiceRepository,
  ClientCompanyRepository => BillingClientCompanyRepository,
  CompanyBillingProfileRepository
}
import com.shevchyk.app.routes.{WebSocketRoutes, DevRoutes, HealthRoutes}
import com.shevchyk.core.repository.{
  PersonRepository,
  CompanyRepository,
  CompanySettingsRepository,
  PostgresCompanySettingsRepository,
  ClientCompanyRepository,
  PostgresClientCompanyRepository
}
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{EventHub, AuditService, PostgresAuditService, GeofenceService}
import com.shevchyk.core.repository.{
  GeofenceRepository,
  GdprRepository,
  SessionRepository,
  BlacklistRepository,
  EmergencyReassignmentRepository,
  RidePoolRepository,
  NotificationPreferenceRepository,
  PostgresGeofenceRepository,
  PostgresGdprRepository,
  PostgresSessionRepository,
  PostgresBlacklistRepository,
  PostgresEmergencyReassignmentRepository,
  PostgresRidePoolRepository,
  PostgresNotificationPreferenceRepository
}
import com.shevchyk.notification.application.{FcmService, PushNotificationListener, LoggingEmailSmsService}
import com.shevchyk.app.{ReminderScheduler, InvoiceReminderScheduler, PredictiveEtaMonitor, SentryInit}
import com.shevchyk.notification.repository.{
  CheckpointNotificationRepository,
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository,
  FcmTokenRepository,
  PostgresFcmTokenRepository,
  PostgresNotificationRepository,
  SentReminderRepository,
  EtaAlertRepository
}
import com.shevchyk.core.application.EmailSmsService
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.config.{Environment, ServerConfig}
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  // `APP_ENV` is the single source of truth for environment selection. Before any config layer is
  // built, point Typesafe Config at the matching `application-<env>.conf` (unless an explicit
  // `-Dconfig.resource=...` was passed). This makes `make dev`, IntelliJ and Cloud Run all behave
  // the same — driven by APP_ENV alone, no `-Dconfig.resource` flag required.
  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] =
    ZLayer(ZIO.succeed(Environment.ensureConfigResource())).unit >>>
      ZLayer(ZIO.succeed(SentryInit.init())).unit >>>
      (Runtime.removeDefaultLoggers >>> SLF4J.slf4j)

  // Ensure every response declares UTF-8 in its Content-Type. Without an explicit
  // charset, HTTP clients (e.g. Dart's `http` package via `response.body`) decode
  // application/json as ISO-8859-1, turning "München" into "MÃ¼nchen". We attach
  // charset=utf-8 to JSON and text responses that don't already specify one.
  private val ensureUtf8Charset: Middleware[Any] = Middleware.updateResponse { response =>
    response.header(Header.ContentType) match
      case Some(ct)
          if ct.charset.isEmpty &&
            (ct.mediaType.mainType == "application" && ct.mediaType.subType == "json" ||
              ct.mediaType.mainType == "text") =>
        // removeHeader first: addHeader alone would append a second Content-Type,
        // and clients read the first (still charset-less) one.
        response
          .removeHeader(Header.ContentType)
          .addHeader(Header.ContentType(ct.mediaType, charset = Some(java.nio.charset.StandardCharsets.UTF_8)))
      case _ => response
  }

  // Allow the Flutter web client (a browser, unlike the mobile apps) to call the
  // API across origins. Without this, the browser blocks every request after a
  // failed CORS preflight ("Failed to fetch"). The default config reflects the
  // request's Origin back in Access-Control-Allow-Origin, allows all methods and
  // headers (the client sends Content-Type and Authorization), and answers
  // OPTIONS preflights. Auth is via Bearer token in a header (not cookies), so
  // origin-reflection is safe here.
  private val corsMiddleware: Middleware[Any] = Middleware.cors

  // Liveness (GET /health) + readiness (GET /health/ready, checks the DB). Defined
  // in HealthRoutes; readiness needs the Transactor[Task] already in the environment.
  private val healthRoutes = HealthRoutes.routes

  // Development-only test-support endpoint (POST /api/dev/reset). Guarded by
  // Environment.isDevelopment inside the handler, so it is inert in production.
  private val devRoutes = DevRoutes.routes

  // All public and authenticated REST endpoints (auth, users, rides, drivers,
  // schedules, billing, audit, gdpr, sessions, blacklist, emergency, pools,
  // geofences, notifications, client-companies, …) are now described and served
  // by Tapir via OpenApiServer, which also exposes Swagger UI at /docs. Only the
  // health check, the dev-only reset endpoint and the WebSocket upgrade remain as
  // hand-written zio-http routes (WebSocket is not expressible in OpenAPI).
  private val publicRoutes = healthRoutes

  private val openApiRoutes = com.shevchyk.app.openapi.OpenApiServer.routes

  private val wsRoutes = WebSocketRoutes.wsRoutes

  def run: ZIO[Any, Throwable, Nothing] = ZIO
    .serviceWithZIO[ServerConfig] { serverConfig =>
      PushNotificationListener.start *>
        ReminderScheduler.start *>
        InvoiceReminderScheduler.start *>
        PredictiveEtaMonitor.start *>
        ZIO.logInfo("Starting Dispax API Server (PostgreSQL)...") *>
        ZIO.logInfo("📋 Available APIs:") *>
        ZIO.logInfo("  🔍 /health - Liveness check") *>
        ZIO.logInfo("  🩺 /health/ready - Readiness check (DB)") *>
        ZIO.logInfo("  🔐 /api/auth/login - Simple login endpoint") *>
        ZIO.logInfo("  👥 /api/users - User management endpoints") *>
        ZIO.logInfo("  🚗 /api/rides - Rich ride data (PostgreSQL)") *>
        ZIO.logInfo("  📊 /api/stats/rides - Ride statistics") *>
        ZIO.logInfo("  📅 /api/schedules - Schedule management") *>
        ZIO.logInfo("  🔌 /api/ws - WebSocket real-time updates") *>
        ZIO.logInfo("  📝 /api/audit - Audit log") *>
        ZIO.logInfo("  ⚙️ /api/company/settings - Company settings") *>
        ZIO.logInfo("  ⭐ /api/rides/{id}/rate - Ride ratings") *>
        ZIO.logInfo("  🔒 /api/gdpr - GDPR data management") *>
        ZIO.logInfo("  📱 /api/sessions - Session management") *>
        ZIO.logInfo("  🚫 /api/blacklist - Client/driver blacklist") *>
        ZIO.logInfo("  🚨 /api/emergency - Emergency reassignment") *>
        ZIO.logInfo("  🚐 /api/pools - Ride pooling/sharing") *>
        ZIO.logInfo("  🔔 /api/notification-preferences - Notification preferences") *>
        ZIO.logInfo("🏗️  Modules: core + auth + ride + driver + schedule + notification + PostgreSQL repositories") *>
        ZIO.logInfo(s"🌐 Server running on http://${serverConfig.host}:${serverConfig.port}") *>
        Server.serve(
          (publicRoutes ++ openApiRoutes ++ devRoutes ++ wsRoutes)
            .handleErrorCauseZIO { cause =>
              ZIO
                .logErrorCause("Unhandled server error", cause)
                // Report the underlying defect explicitly so Sentry groups by the real
                // stack trace, not just the log message. The error channel here is a
                // Response (handled failures), so only unexpected defects carry a
                // Throwable — those are exactly what we want in Sentry. No-op when
                // SENTRY_DSN is unset; logErrorCause above still covers breadcrumbs.
                .zipLeft(ZIO.foreachDiscard(cause.dieOption)(t => ZIO.succeed(SentryInit.capture(t))))
                .as(
                  Response(Status.InternalServerError, body = Body.fromString("Internal server error"))
                )
            } @@ ensureUtf8Charset @@ corsMiddleware
        )
    }
    .provide(
      ZLayer.service[ServerConfig] >>> ZLayer.fromFunction((config: ServerConfig) =>
        Server.Config.default.binding(config.host, config.port)
      ) >>> Server.live,
      ServerConfig.liveLayer,
      PersonRepository.layer,
      CompanyRepository.layer,
      TokenRepository.layer,
      RideRepository.layer,
      RideService.layer,
      DriverLocationRepository.layer,
      DriverLocationService.layer,
      DriverLocationService.providerLayer,
      ScheduleDayRepository.layer,
      ScheduleSvc.layer,
      ClientLocationRepository.layer,
      AirportConfigRepository.layer,
      AirportConfigService.layer,
      AirportCheckpointService.layer,
      ClientLocationService.layer,
      ChatMessageRepository.layer,
      ChatService.layer,
      ExpenseRepository.layer,
      EventHub.layer,
      GeofenceRepository.layer,
      GeofenceService.layer,
      FcmTokenRepository.layer,
      FcmService.layer,
      SentReminderRepository.layer,
      EtaAlertRepository.layer,
      CheckpointNotificationRepository.layer,
      NotificationRepository.layer,
      LoggingEmailSmsService.layer,
      RideTemplateRepository.layer,
      RideRatingRepository.layer,
      AuditService.layer,
      CompanySettingsRepository.layer,
      GdprRepository.layer,
      SessionRepository.layer,
      BlacklistRepository.layer,
      EmergencyReassignmentRepository.layer,
      RidePoolRepository.layer,
      NotificationPreferenceRepository.layer,
      ClientAddressRepository.layer,
      ClientAddressService.layer,
      ClientCompanyRepository.layer,
      InvoiceRepository.layer,
      BillingClientCompanyRepository.layer,
      CompanyBillingProfileRepository.layer,
      InvoiceService.layer,
      PaymentChecker.mockLayer,
      HereConfig.liveLayer,
      GeocodingService.layer,
      HereRoutingService.layer,
      EtaService.layer,
      Client.default,
      JwtConfig.live,
      JwtService.live,
      AuthService.live,
      RateLimiter.layer,
      // Transactor for the dev-only /dev/reset endpoint (DevRoutes).
      DatabaseConfig.liveTransactor
    )
