package com.shevchyk

import com.shevchyk.app.AppRoutes
import com.shevchyk.app.routes.{SimpleRideRoutes, AdminRoutes}
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
import com.shevchyk.infrastructure.testdata.{TestDataSeeder, TestDataInitializer, TestDataConfig}
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

  private val serviceLayer =
    infrastructureLayer >>>
      (RideCreationService.layer ++
        DriverAssignmentService.layer ++
        RideLifecycleService.layer ++
        NotificationOrchestrator.layer ++
        TestDataSeeder.layer) >>>
      RideFacade.layer

  private val applicationLayer = serviceLayer ++ TestDataInitializer.autoSeedLayer

  private val coreRoutes =
    AppRoutes.routes ++
      SimpleRideRoutes.routes

  private def autoSeedData: ZIO[TestDataSeeder, Throwable, Unit] =
    TestDataInitializer.getEnvironment match
      case TestDataInitializer.Environment.Dev  =>
        for
          _      <- ZIO.logInfo("🧪 Dev environment detected - auto-seeding development test data...")
          seeder <- ZIO.service[TestDataSeeder]
          _      <- seeder.seedTestData(TestDataConfig.default)
          _      <- ZIO.logInfo("✅ Development test data auto-seeded successfully!")
        yield ()
      case TestDataInitializer.Environment.Int  =>
        for
          _      <- ZIO.logInfo("🧪 Int environment detected - auto-seeding integration test data...")
          seeder <- ZIO.service[TestDataSeeder]
          _      <- seeder.seedTestData(TestDataConfig.small)
          _      <- ZIO.logInfo("✅ Integration test data auto-seeded successfully!")
        yield ()
      case TestDataInitializer.Environment.Prod => ZIO.logInfo("🏭 Production environment - test data not auto-seeded.")

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
      Server.serve(coreRoutes @@ Middleware.addHeaders(AppRoutes.corsHeaders)))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080)),
        serviceLayer
      )
