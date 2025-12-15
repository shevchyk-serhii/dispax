package com.shevchyk

import com.shevchyk.ride.infrastructure.http.RideRoutes
import com.shevchyk.app.routes.UserRoutes
import com.shevchyk.repository.PersonRepository
import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.infrastructure.http.AuthRoutes
import com.shevchyk.auth.repository.{TokenRepository, UserRepository}
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  private val healthRoutes = Routes(
    Method.GET / "health" -> handler((_: Request) => ZIO.succeed(Response.text("🐙 Der Oktopus Modular API - OK")))
  )

  private val allRoutes = healthRoutes ++ RideRoutes.routes ++ UserRoutes.routes ++ AuthRoutes.routes

  def run: ZIO[Any, Throwable, Nothing] =
    (ZIO.logInfo("🐙 Starting Der Oktopus API Server (PostgreSQL)...") *>
      ZIO.logInfo("📋 Available APIs:") *>
      ZIO.logInfo("  🔍 /health - Health check") *>
      ZIO.logInfo("  🚗 /api/v2/health - Ride service health") *>
      ZIO.logInfo("  🔐 /api/auth/login - Simple login endpoint") *>
      ZIO.logInfo("  👥 /api/users - User management endpoints") *>
      ZIO.logInfo("  🚗 /api/rides - Rich ride data (Mock)") *>
      ZIO.logInfo("  ✈️ /api/flights/{airport}/arrivals|departures - Flight info") *>
      ZIO.logInfo("  ⏰ /api/airport/timing - Airport timing calculation") *>
      ZIO.logInfo("  📊 /api/stats/rides - Ride statistics") *>
      ZIO.logInfo("🏗️  Modules: core + auth + ride + driver + notification + PostgreSQL repositories") *>
      ZIO.logInfo("🌐 Server running on http://localhost:8080") *>
      Server.serve(
        allRoutes.handleError(err => Response(Status.InternalServerError, body = Body.fromString(err.toString)))
      ))
      .provide(
        Server.defaultWith(_.binding("0.0.0.0", 8080)),
        PersonRepository.layer,
        UserRepository.layer,
        TokenRepository.layer,
        JwtConfig.development, // Use development config for now
        JwtService.live,
        AuthService.live
      )
