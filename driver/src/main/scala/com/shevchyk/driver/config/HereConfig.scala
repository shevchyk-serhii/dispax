package com.shevchyk.driver.config

import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*

case class HereConfig(
    apiKey: String,
    baseUrl: String = "https://router.hereapi.com"
)

object HereConfig:

  private val configDescriptor: Config[HereConfig] = deriveConfig[HereConfig].nested("here")

  val layer: ZLayer[Any, Throwable, HereConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  val defaultLayer: ZLayer[Any, Nothing, HereConfig] = ZLayer.succeed(
    HereConfig(apiKey = "")
  )

  val liveLayer: ZLayer[Any, Nothing, HereConfig] = layer.catchAll(_ => defaultLayer)
