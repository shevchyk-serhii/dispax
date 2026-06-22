package com.shevchyk.core.config

import zio.*

/**
 * Global defaults for the automatic airport-departure pickup-time calculation.
 *
 * Both values are read from environment variables so they can be tuned per environment without redeploying. Company-
 * and client-level overrides (stored in the DB) take precedence over these defaults when present — see
 * PickupTimeService for the resolution hierarchy.
 *
 * Defaults (when env vars are absent):
 *   - AIRPORT_BUFFER_MINUTES=15 — extra slack added on top of check-in close time.
 *   - AIRPORT_CHECKIN_CLOSE_MINUTES=60 — minutes before departure that check-in closes.
 */
case class AirportPickupConfig(
    defaultBufferMinutes: Int,
    defaultCheckInCloseMinutes: Int
)

object AirportPickupConfig:

  val liveLayer: ZLayer[Any, Nothing, AirportPickupConfig] = ZLayer.succeed(
    AirportPickupConfig(
      defaultBufferMinutes = sys.env.get("AIRPORT_BUFFER_MINUTES").flatMap(_.toIntOption).getOrElse(15),
      defaultCheckInCloseMinutes = sys.env.get("AIRPORT_CHECKIN_CLOSE_MINUTES").flatMap(_.toIntOption).getOrElse(60)
    )
  )
