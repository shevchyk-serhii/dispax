package com.shevchyk

import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.ride.application.service.{RideFacade, SimpleRideService}
import com.shevchyk.driver.application.DriverAssignmentService
import com.shevchyk.notification.application.NotificationOrchestrator
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler(Response.text("🐙 Der Oktopus Modular API - OK"))
  )

  private val allRoutes = healthRoutes ++ RideRoutes.routes

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server (Modular Architecture)...") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🔍 /health - Health check") *>
      ZIO.logInfo("  🚗 /api/v2/health - Ride service health") *>
      ZIO.logInfo("🏗️  Modules: core + auth + ride + driver + notification") *>
      ZIO.logInfo("🌐 Server running on http://localhost:8080") *>
      Server.serve(allRoutes))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080))
      )
