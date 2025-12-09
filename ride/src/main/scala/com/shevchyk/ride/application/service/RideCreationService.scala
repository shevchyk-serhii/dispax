package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*

case class RideCreationEvent(ride: Ride)

trait RideCreationService:
  def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent]

object RideCreationService:

  val layer: ZLayer[Any, Nothing, RideCreationService] = ZLayer.succeed {
    new RideCreationService {
      def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent] =
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
        ZIO.succeed(RideCreationEvent(ride))
    }
  }
