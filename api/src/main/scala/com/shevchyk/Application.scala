package com.shevchyk

import com.shevchyk.ride.infrastructure.http.{RideRoutes, ExpenseRoutes, RideTemplateRoutes, StatsRoutes, ExportRoutes}
import com.shevchyk.ride.application.service.{RideService, ClientLocationService, ChatService, ClientAddressService}
import com.shevchyk.ride.repository.{
  RideRepository,
  PostgresRideRepository,
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
import com.shevchyk.driver.infrastructure.http.DriverRoutes
import com.shevchyk.core.config.HereConfig
import com.shevchyk.core.application.GeocodingService
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.schedule.infrastructure.http.ScheduleRoutes
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.repository.ScheduleDayRepository
import com.shevchyk.ride.infrastructure.http.ClientAddressRoutes
import com.shevchyk.billing.infrastructure.http.{
  InvoiceRoutes,
  ClientCompanyRoutes => BillingCompanyRoutes,
  BillingProfileRoutes
}
import com.shevchyk.billing.application.{InvoiceService, PaymentChecker}
import com.shevchyk.billing.repository.{
  InvoiceRepository,
  ClientCompanyRepository => BillingClientCompanyRepository,
  CompanyBillingProfileRepository
}
import com.shevchyk.app.routes.{
  UserRoutes,
  WebSocketRoutes,
  DevRoutes,
  AuditRoutes,
  CompanySettingsRoutes,
  GdprRoutes,
  SessionRoutes,
  BlacklistRoutes,
  EmergencyRoutes,
  RidePoolRoutes,
  NotificationPreferenceRoutes,
  ClientCompanyRoutes
}
import com.shevchyk.core.repository.{
  PersonRepository,
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
import com.shevchyk.app.routes.GeofenceRoutes
import com.shevchyk.notification.application.{FcmService, PushNotificationListener, LoggingEmailSmsService}
import com.shevchyk.app.{ReminderScheduler, InvoiceReminderScheduler, PredictiveEtaMonitor}
import com.shevchyk.notification.repository.{
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository,
  FcmTokenRepository,
  PostgresFcmTokenRepository,
  PostgresNotificationRepository,
  SentReminderRepository,
  EtaAlertRepository
}
import com.shevchyk.app.routes.NotificationRoutes
import com.shevchyk.core.application.EmailSmsService
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.config.ServerConfig
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

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

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler((_: Request) => ZIO.succeed(Response.text("Dispax Modular API - OK")))
  )

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
        ZIO.logInfo("  🔍 /health - Health check") *>
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
      TokenRepository.layer,
      RideRepository.layer,
      RideService.layer,
      DriverLocationRepository.layer,
      DriverLocationService.layer,
      DriverLocationService.providerLayer,
      ScheduleDayRepository.layer,
      ScheduleSvc.layer,
      ClientLocationRepository.layer,
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
