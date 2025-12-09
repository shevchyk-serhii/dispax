package com.shevchyk

import com.shevchyk.app.AppRoutes
import com.shevchyk.app.routes.SimpleRideRoutes
import com.shevchyk.application.service.{
  RideFacade,
  RideCreationService,
  DriverAssignmentService,
  RideLifecycleService,
  NotificationOrchestrator
}
import com.shevchyk.infrastructure.repository.*
import com.shevchyk.infrastructure.repository.postgres.RepositoryLayers
import com.shevchyk.infrastructure.database.{DatabaseConfig, DatabaseService}
import com.shevchyk.infrastructure.notification.LoggingNotificationService
import com.shevchyk.infrastructure.services.{StubLocationService, StubFlightInfoService}
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private val inMemoryInfrastructureLayer =
    InMemoryRideRepository.layer ++
      InMemoryDriverRepository.layer ++
      InMemoryPersonRepository.layer ++
      InMemoryTariffRepository.layer ++
      LoggingNotificationService.layer ++
      StubLocationService.layer ++
      StubFlightInfoService.layer

  private val postgresInfrastructureLayer =
    DatabaseConfig.layer >>>
      DatabaseService.live >>>
      RepositoryLayers.all ++
      LoggingNotificationService.layer ++
      StubLocationService.layer ++
      StubFlightInfoService.layer

  private val usePostgres = sys.env.get("USE_POSTGRES").contains("true")

  private val infrastructureLayer =
    if (usePostgres)
      postgresInfrastructureLayer
    else
      inMemoryInfrastructureLayer

  private val applicationLayer =
    infrastructureLayer >>>
      (RideCreationService.layer ++
        DriverAssignmentService.layer ++
        RideLifecycleService.layer ++
        NotificationOrchestrator.layer) >>>
      RideFacade.layer

  private val allRoutes =
    AppRoutes.routes ++
      SimpleRideRoutes.routes

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server...") *>
      ZIO.logInfo(s"🗃️  Database: ${
          if (usePostgres)
            "PostgreSQL"
          else
            "In-Memory"
        }") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🆕 /api/v2/rides - New Onion Architecture API") *>
      ZIO.logInfo("  📱 /api/rides - Legacy API (for compatibility)") *>
      ZIO.logInfo("  🔐 /api/auth - Authentication") *>
      ZIO.logInfo("  👥 /api/users - User management") *>
      ZIO.logInfo("🌐 Server running on http://localhost:8080") *>
      Server.serve(allRoutes @@ Middleware.addHeaders(AppRoutes.corsHeaders)))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080)),
        applicationLayer
      )
