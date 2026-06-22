package com.shevchyk.core.config

import zio.*
import zio.test.*

/**
 * Regression for the e2e/Cloud Run bug where the server ignored the `PORT` env var and always bound the config/default
 * port (8080), colliding with a running dev server. `liveLayer` must honour `PORT` when set, and fall back to the
 * config/default port otherwise.
 */
object ServerConfigSpec extends ZIOSpecDefault {

  private val defaultPort = ServerConfig().port

  def spec =
    suite("ServerConfig")(
      test("liveLayer overrides the port from the PORT env var") {
        for {
          _      <- TestSystem.putEnv("PORT", "8090")
          config <- ZIO.service[ServerConfig].provide(ServerConfig.liveLayer)
        } yield assertTrue(config.port == 8090)
      },
      test("liveLayer keeps the default port when PORT is unset") {
        for {
          config <- ZIO.service[ServerConfig].provide(ServerConfig.liveLayer)
        } yield assertTrue(config.port == defaultPort)
      },
      test("liveLayer keeps the default port when PORT is not a number") {
        for {
          _      <- TestSystem.putEnv("PORT", "not-a-port")
          config <- ZIO.service[ServerConfig].provide(ServerConfig.liveLayer)
        } yield assertTrue(config.port == defaultPort)
      },
      test("envPortLayer reads the port from the PORT env var") {
        for {
          _      <- TestSystem.putEnv("PORT", "9000")
          config <- ZIO.service[ServerConfig].provide(ServerConfig.envPortLayer)
        } yield assertTrue(config.port == 9000)
      }
    ) @@ TestAspect.sequential
}
