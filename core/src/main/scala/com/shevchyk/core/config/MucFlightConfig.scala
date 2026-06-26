package com.shevchyk.core.config

import zio.*

/**
 * Configuration for the Munich Airport (MUC) flight-board scraper used by `MucFlightStatusProvider`.
 *
 * `enabled` lets deployments turn the scraper off (e.g. in tests or environments without outbound internet) without
 * removing the layer — when false, the provider short-circuits to `None`. `baseUrl` is overridable so a mock server can
 * be pointed at during integration testing.
 */
case class MucFlightConfig(
    enabled: Boolean = true,
    baseUrl: String = "https://www.munich-airport.de"
)

object MucFlightConfig:

  val liveLayer: ZLayer[Any, Nothing, MucFlightConfig] = ZLayer.succeed(
    MucFlightConfig(
      enabled = sys.env.getOrElse("MUC_FLIGHT_ENABLED", "true").toLowerCase != "false",
      baseUrl = sys.env.getOrElse("MUC_FLIGHT_BASE_URL", "https://www.munich-airport.de")
    )
  )
