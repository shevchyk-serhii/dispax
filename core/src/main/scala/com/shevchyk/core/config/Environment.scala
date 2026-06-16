package com.shevchyk.core.config

import zio.*

sealed trait Environment {
  def name: String
}

object Environment {
  case object Development extends Environment { val name = "development" }
  case object Production  extends Environment { val name = "production"  }
  case object Test        extends Environment { val name = "test"        }

  def current: Environment = {
    sys.env.get("APP_ENV").orElse(sys.props.get("app.env")) match {
      case Some("production") => Production
      case Some("test")       => Test
      case _                  => Development // Default to development
    }
  }

  def isDevelopment: Boolean = current == Development
  def isProduction: Boolean  = current == Production
  def isTest: Boolean        = current == Test

  /** Name of the HOCON override (`application-<env>.conf`) that matches the current environment. */
  def configResourceName: String = s"application-${current.name}.conf"

  /**
   * Make `APP_ENV` the single source of truth for HOCON selection: point Typesafe Config (which
   * `ConfigProvider.fromResourcePath()` reads) at `application-<env>.conf` unless an explicit
   * `-Dconfig.resource=...` was already supplied. Idempotent; safe to call before any config layer
   * is built. Returns whether the property was set by this call.
   */
  def ensureConfigResource(): Boolean =
    if sys.props.contains("config.resource") then false
    else {
      java.lang.System.setProperty("config.resource", configResourceName)
      true
    }

  val layer: ZLayer[Any, Nothing, Environment] = ZLayer.succeed(current)
}
