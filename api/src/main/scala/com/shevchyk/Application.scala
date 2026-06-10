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
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
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
import com.shevchyk.billing.application.InvoiceService
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
import com.shevchyk.auth.infrastructure.http.AuthRoutes
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
import com.shevchyk.app.ReminderScheduler
import com.shevchyk.notification.repository.{
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository,
  FcmTokenRepository,
  PostgresFcmTokenRepository,
  PostgresNotificationRepository,
  SentReminderRepository
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

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler((_: Request) => ZIO.succeed(Response.text("Dispax Modular API - OK")))
  )

  // Development-only test-support endpoint (POST /api/dev/reset). Guarded by
  // Environment.isDevelopment inside the handler, so it is inert in production.
  private val devRoutes = DevRoutes.routes

  private val publicRoutes = healthRoutes ++ UserRoutes.routes ++ AuthRoutes.routes

  private val rideRoutes            = RideRoutes.authenticatedRoutes
  private val clientLocationRoutes  = RideRoutes.clientLocationRoutes
  private val driverRoutes          = DriverRoutes.authenticatedRoutes
  private val scheduleRoutes        = ScheduleRoutes.authenticatedRoutes
  private val userRoutes            = UserRoutes.authenticatedRoutes
  private val chatRoutes            = RideRoutes.chatRoutes
  private val expenseRoutes         = ExpenseRoutes.authenticatedRoutes
  private val rideTemplateRoutes    = RideTemplateRoutes.authenticatedRoutes
  private val notificationRoutes    = NotificationRoutes.authenticatedRoutes
  private val statsRoutes           = StatsRoutes.authenticatedRoutes
  private val exportRoutes          = ExportRoutes.authenticatedRoutes
  private val ratingRoutes          = RideRoutes.ratingRoutes
  private val auditRoutes           = AuditRoutes.authenticatedRoutes
  private val companySettingsRoutes = CompanySettingsRoutes.authenticatedRoutes
  private val geofenceRoutes        = GeofenceRoutes.authenticatedRoutes
  private val gdprRoutes            = GdprRoutes.authenticatedRoutes
  private val sessionRoutes         = SessionRoutes.authenticatedRoutes
  private val blacklistRoutes       = BlacklistRoutes.authenticatedRoutes
  private val emergencyRoutes       = EmergencyRoutes.authenticatedRoutes
  private val ridePoolRoutes        = RidePoolRoutes.authenticatedRoutes
  private val notifPrefRoutes       = NotificationPreferenceRoutes.authenticatedRoutes
  private val clientAddressRoutes   = ClientAddressRoutes.authenticatedRoutes
  private val clientCompanyRoutes   = ClientCompanyRoutes.authenticatedRoutes
  private val invoiceRoutes         = InvoiceRoutes.authenticatedRoutes
  private val billingCompanyRoutes  = BillingCompanyRoutes.authenticatedRoutes
  private val billingProfileRoutes  = BillingProfileRoutes.authenticatedRoutes

  private val wsRoutes = WebSocketRoutes.wsRoutes

  def run: ZIO[Any, Throwable, Nothing] = ZIO
    .serviceWithZIO[ServerConfig] { serverConfig =>
      PushNotificationListener.start *>
        ReminderScheduler.start *>
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
          (publicRoutes ++ devRoutes ++ rideRoutes ++ clientLocationRoutes ++ chatRoutes ++ expenseRoutes ++ driverRoutes ++ scheduleRoutes ++ userRoutes ++ rideTemplateRoutes ++ notificationRoutes ++ statsRoutes ++ exportRoutes ++ ratingRoutes ++ auditRoutes ++ companySettingsRoutes ++ geofenceRoutes ++ gdprRoutes ++ sessionRoutes ++ blacklistRoutes ++ emergencyRoutes ++ ridePoolRoutes ++ notifPrefRoutes ++ clientAddressRoutes ++ clientCompanyRoutes ++ invoiceRoutes ++ billingCompanyRoutes ++ billingProfileRoutes ++ wsRoutes)
            .handleErrorCauseZIO { cause =>
              ZIO
                .logErrorCause("Unhandled server error", cause)
                .as(
                  Response(Status.InternalServerError, body = Body.fromString("Internal server error"))
                )
            } @@ ensureUtf8Charset
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
      HereConfig.liveLayer,
      GeocodingService.layer,
      HereRoutingService.layer,
      Client.default,
      JwtConfig.live,
      JwtService.live,
      AuthService.live,
      RateLimiter.layer,
      // Transactor for the dev-only /dev/reset endpoint (DevRoutes).
      DatabaseConfig.liveTransactor
    )
