package com.shevchyk

import com.shevchyk.app.AppRoutes
import com.shevchyk.app.routes.SimpleRideRoutes
import com.shevchyk.service.{UserService, OrderService, RideService, AuthService, FlightService}
import com.shevchyk.application.service.RideApplicationService
import com.shevchyk.infrastructure.repository.*
import com.shevchyk.infrastructure.notification.LoggingNotificationService
import com.shevchyk.infrastructure.services.{MockLocationService, MockFlightInfoService}
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J
import java.net.InetSocketAddress

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  
  private val infrastructureLayer =
    InMemoryRideRepository.layer ++
      InMemoryDriverRepository.layer ++
      InMemoryPersonRepository.layer ++
      InMemoryTariffRepository.layer ++
      LoggingNotificationService.layer ++
      MockLocationService.layer ++
      MockFlightInfoService.layer

  private val applicationLayer = infrastructureLayer >>> RideApplicationService.layer

  
  private val allRoutes =
    AppRoutes.routes ++       
      SimpleRideRoutes.routes 

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server...") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🆕 /api/v2/rides - New Onion Architecture API") *>
      ZIO.logInfo("  📱 /api/rides - Legacy API (for compatibility)") *>
      ZIO.logInfo("  🔐 /api/auth - Authentication") *>
      ZIO.logInfo("  👥 /api/users - User management") *>
      ZIO.logInfo("🌐 Server running on http:
      Server.serve(allRoutes @@ Middleware.addHeaders(AppRoutes.corsHeaders)))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080)),
        
        UserService.live,
        OrderService.live,
        RideService.layer,
        AuthService.layer,
        FlightService.live,
        
        applicationLayer
      )
