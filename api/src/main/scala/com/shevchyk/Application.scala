package com.shevchyk

import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.ride.application.service.{RideService, ClientLocationService}
import com.shevchyk.ride.repository.{
  RideRepository,
  PostgresRideRepository,
  ClientLocationRepository,
  PostgresClientLocationRepository
}
import com.shevchyk.driver.application.DriverLocationService
import com.shevchyk.driver.infrastructure.http.DriverRoutes
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.schedule.infrastructure.http.ScheduleRoutes
import com.shevchyk.schedule.application.{ScheduleService => ScheduleSvc}
import com.shevchyk.schedule.repository.ScheduleDayRepository
import com.shevchyk.app.routes.{UserRoutes, WebSocketRoutes}
import com.shevchyk.repository.PersonRepository
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.infrastructure.http.AuthRoutes
import com.shevchyk.auth.repository.{TokenRepository, UserRepository}
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.EventHub
import com.shevchyk.notification.application.{FcmService, PushNotificationListener}
import com.shevchyk.notification.repository.InMemoryFcmTokenRepository
import com.shevchyk.database.DatabaseConfig
import com.shevchyk.config.ServerConfig
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler((_: Request) => ZIO.succeed(Response.text("🐙 Der Oktopus Modular API - OK")))
  )

  private val publicRoutes = healthRoutes ++ UserRoutes.routes ++ AuthRoutes.routes

  private val rideRoutes           = RideRoutes.authenticatedRoutes
  private val clientLocationRoutes = RideRoutes.clientLocationRoutes
  private val driverRoutes         = DriverRoutes.authenticatedRoutes
  private val scheduleRoutes       = ScheduleRoutes.authenticatedRoutes
  private val userRoutes           = UserRoutes.authenticatedRoutes
  private val wsRoutes             = WebSocketRoutes.wsRoutes

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
        ZIO.logInfo("🏗️  Modules: core + auth + ride + driver + schedule + notification + PostgreSQL repositories") *>
        ZIO.logInfo(s"🌐 Server running on http://${serverConfig.host}:${serverConfig.port}") *>
        Server.serve(
          (publicRoutes ++ rideRoutes ++ clientLocationRoutes ++ driverRoutes ++ scheduleRoutes ++ userRoutes ++ wsRoutes)
            .handleError(err => Response(Status.InternalServerError, body = Body.fromString(err.toString)))
        )
    }
    .provide(
      ZLayer.service[ServerConfig] >>> ZLayer.fromFunction((config: ServerConfig) =>
        Server.Config.default.binding(config.host, config.port)
      ) >>> Server.live,
      ServerConfig.liveLayer,
      PersonRepository.layer,
      UserRepository.layer,
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
      EventHub.layer,
      InMemoryFcmTokenRepository.layer,
      FcmService.layer,
      JwtConfig.live,
      JwtService.live,
      AuthService.live
    )
