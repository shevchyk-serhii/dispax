package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*

trait SimpleRideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]

object SimpleRideService:

  val layer: ZLayer[Any, Nothing, SimpleRideService] = ZLayer.succeed {
    new SimpleRideService {
      def getRideById(rideId: RideId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))

      def createRide(request: CreateRideRequest): IO[RideError, Ride] =
        val ride = Ride(
          id = RideId(scala.util.Random.nextLong()),
          clientId = request.clientId,
          creatorId = request.clientId,
          companyId = CompanyId(1),
          pickupLocation = request.pickupLocation,
          dropoffLocation = request.dropoffLocation,
          scheduledTime = request.scheduledTime,
          notes = request.notes,
          airportCode = request.airportCode,
          flightNumber = request.flightNumber,
          isAirportTransfer = request.isAirportTransfer
        )
        ZIO.succeed(ride)
    }
  }
