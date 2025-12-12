package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.*
import zio.*

case class RideFacade(
    rideService: SimpleRideService
):

  def createRide(request: CreateRideRequest): IO[RideError, Ride] = rideService.createRide(request)

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideService.getRideById(rideId)

object RideFacade:
  val layer: ZLayer[SimpleRideService, Nothing, RideFacade] = ZLayer.fromFunction(RideFacade.apply)
