package com.shevchyk.ride.application

import zio.*

/**
 * Abstraction for obtaining driving time between two coordinates.
 *
 * Defined in the `ride` module so that `ride` never depends on `driver` (where the HERE Routing implementation lives).
 * The HERE-backed adapter is wired at the `api` DI layer via [[com.shevchyk.app.HereTravelTimeAdapter]].
 */
trait TravelTimeService:

  /**
   * Returns estimated driving time in minutes, or [[None]] when routing is unavailable (no API key, network error,
   * etc.). Callers must fall back to Haversine when [[None]] is returned — they must never block ride creation on a
   * missing travel-time result.
   */
  def travelMinutes(
      fromLat: Double,
      fromLng: Double,
      toLat: Double,
      toLng: Double
  ): Task[Option[Int]]
