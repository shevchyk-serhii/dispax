package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*

trait RideStatusService:
  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride]

object RideStatusService:

  val layer: ZLayer[Any, Nothing, RideStatusService] = ZLayer.succeed {
    new RideStatusService {
      def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride] = ZIO.fail(
        RideError.RideNotFound(rideId)
      )
    }
  }
