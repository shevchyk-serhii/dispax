package com.shevchyk

import com.shevchyk.ride.infrastructure.http.{
  RideRoutes,
  MockRideRoutes,
  ExpenseRoutes,
  RideTemplateRoutes,
  StatsRoutes,
  ExportRoutes
}
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
import com.shevchyk.driver.application.DriverLocationService
import com.shevchyk.driver.infrastructure.http.DriverRoutes
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.schedule.infrastructure.http.ScheduleRoutes
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.repository.ScheduleDayRepository
import com.shevchyk.ride.infrastructure.http.ClientAddressRoutes
import com.shevchyk.app.routes.{
  UserRoutes,
  WebSocketRoutes,
  AuditRoutes,
  CompanySettingsRoutes,
  GdprRoutes,
  SessionRoutes,
  BlacklistRoutes,
  EmergencyRoutes,
  RidePoolRoutes,
  NotificationPreferenceRoutes
}
import com.shevchyk.core.repository.{PersonRepository, CompanySettingsRepository, PostgresCompanySettingsRepository}
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
import com.shevchyk.notification.repository.{
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository,
  FcmTokenRepository,
  PostgresFcmTokenRepository,
  PostgresNotificationRepository
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

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler((_: Request) => ZIO.succeed(Response.text("🐙 Der Oktopus Modular API - OK")))
  )

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

  private val mockRoutes =
    if sys.env.getOrElse("ENABLE_MOCK_ROUTES", "false") == "true" then MockRideRoutes.routes else Routes.empty
  private val wsRoutes   = WebSocketRoutes.wsRoutes

  def run: ZIO[Any, Throwable, Nothing] = ZIO
    .serviceWithZIO[ServerConfig] { serverConfig =>
      ZIO.scoped(PushNotificationListener.start).forkDaemon *>
        ZIO.logInfo("🐙 Starting Der Oktopus API Server (PostgreSQL)...") *>
        ZIO.logInfo("📋 Available APIs:") *>
        ZIO.logInfo("  🔍 /health - Health check") *>
        ZIO.logInfo("  🚗 /api/v2/health - Ride service health") *>
        ZIO.logInfo("  🔐 /api/auth/login - Simple login endpoint") *>
        ZIO.logInfo("  👥 /api/users - User management endpoints") *>
        ZIO.logInfo("  🚗 /api/rides - Rich ride data (PostgreSQL)") *>
        ZIO.logInfo("  ✈️ /api/flights/{airport}/arrivals|departures - Flight info") *>
        ZIO.logInfo("  ⏰ /api/airport/timing - Airport timing calculation") *>
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
          (publicRoutes ++ mockRoutes ++ rideRoutes ++ clientLocationRoutes ++ chatRoutes ++ expenseRoutes ++ driverRoutes ++ scheduleRoutes ++ userRoutes ++ rideTemplateRoutes ++ notificationRoutes ++ statsRoutes ++ exportRoutes ++ ratingRoutes ++ auditRoutes ++ companySettingsRoutes ++ geofenceRoutes ++ gdprRoutes ++ sessionRoutes ++ blacklistRoutes ++ emergencyRoutes ++ ridePoolRoutes ++ notifPrefRoutes ++ clientAddressRoutes ++ wsRoutes)
            .handleErrorCauseZIO { cause =>
              ZIO
                .logErrorCause("Unhandled server error", cause)
                .as(
                  Response(Status.InternalServerError, body = Body.fromString("Internal server error"))
                )
            }
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
      JwtConfig.live,
      JwtService.live,
      AuthService.live,
      RateLimiter.layer
    )
