package com.shevchyk.app

import com.shevchyk.driver.application.HereRoutingService
import com.shevchyk.ride.application.TravelTimeService
import zio.*

/**
 * Adapts [[HereRoutingService]] (which lives in the `driver` module) to the [[TravelTimeService]] trait defined in the
 * `ride` module. This adapter is the only place where the two modules are coupled, and that coupling is intentional —
 * it lives at the `api` DI layer, not inside either module.
 *
 * Error handling: any HERE error degrades gracefully to [[None]]. The caller ([[PickupTimeService]]) will fall back to
 * Haversine in that case so ride creation is never blocked.
 */
final class HereTravelTimeAdapter(here: HereRoutingService) extends TravelTimeService:

  def travelMinutes(
      fromLat: Double,
      fromLng: Double,
      toLat: Double,
      toLng: Double
  ): Task[Option[Int]] = here
    .getEtaMinutes(fromLat, fromLng, toLat, toLng)
    .catchAll(err =>
      ZIO.logWarning(s"HereTravelTimeAdapter: HERE routing error, falling back to Haversine: ${err.getMessage}") *>
        ZIO.succeed(None)
    )

object HereTravelTimeAdapter:

  val layer: ZLayer[HereRoutingService, Nothing, TravelTimeService] = ZLayer.fromFunction(HereTravelTimeAdapter(_))
