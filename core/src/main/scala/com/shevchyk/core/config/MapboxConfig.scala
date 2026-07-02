package com.shevchyk.core.config

import zio.*

/**
 * Mapbox access token used by the server-rendered public guest tracking page (Mapbox GL JS). This is a separate, public
 * (pk.*) token embedded into the HTML the browser loads — NOT a secret. Empty when unset; the page degrades to a no-map
 * fallback in that case.
 */
case class MapboxConfig(accessToken: String)

object MapboxConfig:

  val liveLayer: ZLayer[Any, Nothing, MapboxConfig] = ZLayer.succeed(
    MapboxConfig(accessToken = sys.env.getOrElse("MAPBOX_ACCESS_TOKEN", ""))
  )
