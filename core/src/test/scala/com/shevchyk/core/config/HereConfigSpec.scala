package com.shevchyk.core.config

import zio.*
import zio.test.*

/**
 * Unit tests for the HERE config bootstrap: a missing or blank HERE_API_KEY must produce a loud startup warning (the
 * integration silently degrades to fallbacks otherwise), while a configured key must stay quiet.
 */
object HereConfigSpec extends ZIOSpecDefault:

  private def warnings: UIO[Chunk[String]] = ZTestLogger.logOutput.map(
    _.filter(_.logLevel == LogLevel.Warning).map(_.message())
  )

  def spec =
    suite("HereConfig.fromEnv")(
      test("missing HERE_API_KEY: empty key, loud warning logged") {
        for {
          config <- HereConfig.fromEnv(Map.empty)
          warns  <- warnings
        } yield assertTrue(
          config.apiKey == "",
          warns.exists(m => m.contains("HERE_API_KEY") && m.contains("DISABLED"))
        )
      },
      test("blank HERE_API_KEY: warning logged") {
        for {
          _     <- HereConfig.fromEnv(Map("HERE_API_KEY" -> "   "))
          warns <- warnings
        } yield assertTrue(warns.exists(_.contains("HERE_API_KEY")))
      },
      test("configured HERE_API_KEY: key is picked up and no warning is logged") {
        for {
          config <- HereConfig.fromEnv(Map("HERE_API_KEY" -> "real-key", "HERE_BASE_URL" -> "https://example.test"))
          warns  <- warnings
        } yield assertTrue(
          config.apiKey == "real-key",
          config.baseUrl == "https://example.test",
          !warns.exists(_.contains("HERE_API_KEY"))
        )
      }
    )
