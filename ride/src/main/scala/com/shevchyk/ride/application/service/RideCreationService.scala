package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.RideRepository
import zio.*
import java.time.Instant

case class RideCreationEvent(ride: Ride)

trait RideCreationService:
  def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent]

class RideCreationServiceImpl(rideRepository: RideRepository) extends RideCreationService:

  def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent] =
    for {
      // Validate request
      _ <- validateCreateRideRequest(request)

      // Create ride entity
      ride           = Ride(
                         id = RideId.generate(),           // Generate UUID
                         clientId = request.clientId,
                         creatorId = request.clientId,     // For now, creator is the client
                         companyId = CompanyId.generate(), // Generate UUID for default company
                         pickupLocation = request.pickupLocation,
                         dropoffLocation = request.dropoffLocation,
                         scheduledTime = request.scheduledTime,
                         requestTime = Instant.now(),
                         notes = request.notes,
                         airportCode = request.airportCode,
                         flightNumber = request.flightNumber,
                         isAirportTransfer = request.isAirportTransfer
                       )

      // Persist to database
      persistedRide <- rideRepository
                         .create(ride)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield RideCreationEvent(persistedRide)

  private def validateCreateRideRequest(request: CreateRideRequest): IO[RideError, Unit] =
    for {
      _ <-
        ZIO.when(request.pickupLocation.address.trim.isEmpty)(
          ZIO.fail(RideError.ValidationError("Pickup location cannot be empty"))
        )
      _ <-
        ZIO.when(request.dropoffLocation.address.trim.isEmpty)(
          ZIO.fail(RideError.ValidationError("Dropoff location cannot be empty"))
        )
      _ <-
        ZIO.when(request.scheduledTime.exists(_.isBefore(Instant.now())))(
          ZIO.fail(RideError.ValidationError("Scheduled time cannot be in the past"))
        )
      _ <-
        ZIO.when(request.isAirportTransfer && request.airportCode.isEmpty)(
          ZIO.fail(RideError.ValidationError("Airport code is required for airport transfers"))
        )
    } yield ()

object RideCreationService:

  val layer: ZLayer[RideRepository, Nothing, RideCreationService] = ZLayer.fromFunction(RideCreationServiceImpl.apply)

  // Mock layer for testing
  val mock: ZLayer[Any, Nothing, RideCreationService] = ZLayer.succeed {
    new RideCreationService {
      def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent] =
        val ride = Ride(
          id = RideId.generate(),
          clientId = request.clientId,
          creatorId = request.clientId,
          companyId = CompanyId.generate(),
          pickupLocation = request.pickupLocation,
          dropoffLocation = request.dropoffLocation,
          scheduledTime = request.scheduledTime,
          requestTime = Instant.now(),
          notes = request.notes,
          airportCode = request.airportCode,
          flightNumber = request.flightNumber,
          isAirportTransfer = request.isAirportTransfer
        )
        ZIO.succeed(RideCreationEvent(ride))
    }
  }
