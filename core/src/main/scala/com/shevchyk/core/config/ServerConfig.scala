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

  /**
   * Overrides [config]'s port with the `PORT` env var when it is set. Cloud Run and the e2e test backend (`PORT=8090
   * sbt run`) both bind via `PORT`; without this override the env var is ignored and the server always binds the
   * config/default port (8080), colliding with a running dev server.
   */
  private def withEnvPort(config: ServerConfig): ZIO[Any, Nothing, ServerConfig] = System
    .env("PORT")
    .orElseSucceed(None)
    .map(envPort => envPort.flatMap(_.toIntOption).fold(config)(p => config.copy(port = p)))

  /**
   * Resolves the base config from the resource path, falling back to the default on any failure — including config
   * parsing *defects* (e.g. an unresolved `${...}` substitution), which `catchAll` alone would let escape.
   */
  private val baseConfig: ZIO[Any, Nothing, ServerConfig] = ZIO
    .suspendSucceed(read(configDescriptor.from(ConfigProvider.fromResourcePath())))
    .catchAllCause(_ => ZIO.succeed(ServerConfig()))

  val liveLayer: ZLayer[Any, Nothing, ServerConfig] = ZLayer.fromZIO(baseConfig.flatMap(withEnvPort))
}
