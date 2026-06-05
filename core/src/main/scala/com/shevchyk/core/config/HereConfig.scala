package com.shevchyk.core.config

import zio.*

case class HereConfig(
    apiKey: String,
    baseUrl: String = "https://router.hereapi.com"
)

object HereConfig:

  val liveLayer: ZLayer[Any, Nothing, HereConfig] = ZLayer.succeed(
    HereConfig(
      apiKey = sys.env.getOrElse("HERE_API_KEY", ""),
      baseUrl = sys.env.getOrElse("HERE_BASE_URL", "https://router.hereapi.com")
    )
  )
