package com.shevchyk

import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.app.routes.UserRoutes
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J
import zio.json.*

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler(Response.text("🐙 Der Oktopus Modular API - OK"))
  )

  // Simple auth endpoint for testing
  private val authRoutes = Routes(
    Method.POST / "api" / "auth" / "login" -> handler { (req: Request) =>
      (for
        bodyStr     <- req.body.asString
        _           <- ZIO.logInfo(s"Login request: $bodyStr")
        // Simple mock response for frontend compatibility
        mockResponse =
          s"""{"person":{"id":1,"email":"test@example.com","name":"Test User","role":"CLIENT"},"token":"valid-token-1"}"""
        response    <- ZIO.succeed(Response.json(mockResponse))
      yield response).orElse(ZIO.succeed(Response.badRequest("Invalid request")))
    }
  )

  private val allRoutes = healthRoutes ++ RideRoutes.routes ++ UserRoutes.routes ++ authRoutes

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server (Mock Data)...") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🔍 /health - Health check") *>
      ZIO.logInfo("  🚗 /api/v2/health - Ride service health") *>
      ZIO.logInfo("  🔐 /api/auth/login - Simple login endpoint") *>
      ZIO.logInfo("  👥 /api/users - User management endpoints") *>
      ZIO.logInfo("  🚗 /api/rides - Rich ride data (Mock)") *>
      ZIO.logInfo("  ✈️ /api/flights/{airport}/arrivals|departures - Flight info") *>
      ZIO.logInfo("  ⏰ /api/airport/timing - Airport timing calculation") *>
      ZIO.logInfo("  📊 /api/stats/rides - Ride statistics") *>
      ZIO.logInfo("🏗️  Modules: core + auth + ride + driver + notification + mock repositories") *>
      ZIO.logInfo("🌐 Server running on http://localhost:8080") *>
      Server.serve(allRoutes))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080))
      )
