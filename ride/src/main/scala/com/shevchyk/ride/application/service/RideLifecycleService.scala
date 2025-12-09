package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*

case class RideStatusChange(ride: Ride)
case class RideCompletion(ride: Ride)
case class RideCancellation(ride: Ride)

trait RideLifecycleService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, RideStatusChange]
  def completeRide(rideId: RideId, driverId: PersonId): IO[RideError, RideCompletion]
  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, RideCancellation]

object RideLifecycleService:

  val layer: ZLayer[Any, Nothing, RideLifecycleService] = ZLayer.succeed {
    new RideLifecycleService {
      def getRideById(rideId: RideId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))

      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, RideStatusChange] = ZIO.fail(
        RideError.RideNotFound(rideId)
      )

      def completeRide(rideId: RideId, driverId: PersonId): IO[RideError, RideCompletion] = ZIO.fail(
        RideError.RideNotFound(rideId)
      )

      def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, RideCancellation] = ZIO
        .fail(RideError.RideNotFound(rideId))
    }
  }
