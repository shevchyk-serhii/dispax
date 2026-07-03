package com.shevchyk.core.config

import zio.*

case class HereConfig(
    apiKey: String,
    baseUrl: String = "https://router.hereapi.com"
)

object HereConfig:

  /**
   * Builds the config from the given environment, logging a LOUD startup warning when the key is missing or blank: HERE
   * routing and geocoding then silently degrade to their fallbacks (straight-line Haversine ETA, `None` geocoding),
   * which is easy to miss in production.
   *
   * Unlike `JwtConfig` (which fails startup in production on a missing JWT_SECRET), a missing HERE key does NOT fail
   * startup — the integration is optional by design and the app stays functional on the fallbacks; the warning makes
   * the degradation visible instead of silent.
   */
  def fromEnv(env: Map[String, String]): UIO[HereConfig] =
    val config = HereConfig(
      apiKey = env.getOrElse("HERE_API_KEY", ""),
      baseUrl = env.getOrElse("HERE_BASE_URL", "https://router.hereapi.com")
    )
    ZIO
      .logWarning(
        "HERE_API_KEY is not set or blank — HERE routing/geocoding is DISABLED. " +
          "ETAs fall back to straight-line estimates and address geocoding returns no coordinates. " +
          "Set HERE_API_KEY to enable the HERE integration."
      )
      .when(config.apiKey.isBlank)
      .as(config)

  val liveLayer: ZLayer[Any, Nothing, HereConfig] = ZLayer.fromZIO(fromEnv(sys.env))
