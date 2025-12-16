package com.shevchyk.config

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

  val layer: ZLayer[Any, Nothing, Environment] = ZLayer.succeed(current)
}
