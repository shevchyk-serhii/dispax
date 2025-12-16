package com.shevchyk.config

import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*

case class ServerConfig(
    host: String = "0.0.0.0",
    port: Int = 8080
)

object ServerConfig {

  // Configuration descriptor for ZIO Config
  private val configDescriptor: Config[ServerConfig] = deriveConfig[ServerConfig].nested("server")

  // Layer that loads configuration from application.conf
  val layer: ZLayer[Any, Throwable, ServerConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  // Fallback layer with default configuration
  val defaultLayer: ZLayer[Any, Nothing, ServerConfig] = ZLayer.succeed(
    ServerConfig()
  )

  // Live layer with fallback to defaults
  val liveLayer: ZLayer[Any, Throwable, ServerConfig] = layer.catchAll(_ => defaultLayer)
}
