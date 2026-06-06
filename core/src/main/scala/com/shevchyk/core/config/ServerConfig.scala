package com.shevchyk.core.config

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

  /**
   * Reads the port from the `PORT` env var (falling back to the default), keeping the default host. Used by the test
   * server so it can bind to a non-default port (e.g. to run alongside a dev server on 8080).
   */
  val envPortLayer: ZLayer[Any, Nothing, ServerConfig] = ZLayer.fromZIO(
    System
      .env("PORT")
      .orElseSucceed(None)
      .map(envPort => ServerConfig(port = envPort.flatMap(_.toIntOption).getOrElse(ServerConfig().port)))
  )

  val liveLayer: ZLayer[Any, Throwable, ServerConfig] = layer.catchAll(_ => defaultLayer)
}
