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

  private val configDescriptor: Config[ServerConfig] = deriveConfig[ServerConfig].nested("server")

  val layer: ZLayer[Any, Throwable, ServerConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  val defaultLayer: ZLayer[Any, Nothing, ServerConfig] = ZLayer.succeed(
    ServerConfig()
  )

  val liveLayer: ZLayer[Any, Throwable, ServerConfig] = layer.catchAll(_ => defaultLayer)
}
