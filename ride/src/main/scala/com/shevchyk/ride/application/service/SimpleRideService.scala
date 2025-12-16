package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.RideRepository
import zio.*

trait SimpleRideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]

class SimpleRideServiceImpl(
    rideRepository: RideRepository,
    rideCreationService: RideCreationService
) extends SimpleRideService:

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepository
    .findById(rideId)
    .mapError(ex => RideError.DatabaseError(ex.getCause))
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def createRide(request: CreateRideRequest): IO[RideError, Ride] = rideCreationService
    .createRide(request)
    .map(_.ride)

object SimpleRideService:

  val layer: ZLayer[RideRepository & RideCreationService, Nothing, SimpleRideService] = ZLayer.fromFunction(
    SimpleRideServiceImpl.apply
  )

  // Mock layer for testing
  val mock: ZLayer[Any, Nothing, SimpleRideService] = ZLayer.succeed {
    new SimpleRideService {
      def getRideById(rideId: RideId): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))

      def createRide(request: CreateRideRequest): IO[RideError, Ride] =
        val ride = Ride(
          id = RideId.generate(),
          clientId = request.clientId,
          creatorId = request.clientId,
          companyId = CompanyId.generate(),
          pickupLocation = request.pickupLocation,
          dropoffLocation = request.dropoffLocation,
          scheduledTime = request.scheduledTime,
          requestTime = java.time.Instant.now(),
          notes = request.notes,
          airportCode = request.airportCode,
          flightNumber = request.flightNumber,
          isAirportTransfer = request.isAirportTransfer
        )
        ZIO.succeed(ride)
    }
  }
