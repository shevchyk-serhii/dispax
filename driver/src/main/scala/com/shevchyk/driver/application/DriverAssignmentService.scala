package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*

case class DriverAssignment(ride: Ride, driver: Person)

trait DriverAssignmentService:
  def assignDriverToRide(rideId: RideId, requesterId: PersonId): IO[RideError, DriverAssignment]

object DriverAssignmentService:

  val layer: ZLayer[Any, Nothing, DriverAssignmentService] = ZLayer.succeed {
    new DriverAssignmentService {
      def assignDriverToRide(rideId: RideId, requesterId: PersonId): IO[RideError, DriverAssignment] = ZIO.fail(
        RideError.RideNotFound(rideId)
      )
    }
  }
