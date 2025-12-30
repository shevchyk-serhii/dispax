package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.repository.PersonRepository
import zio.*
import java.time.Instant

case class RideCreationEvent(ride: Ride)

trait RideCreationService:
  def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent]

class RideCreationServiceImpl(rideRepository: RideRepository, personRepository: PersonRepository)
    extends RideCreationService:

  def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent] =
    for {
      _ <- validateCreateRideRequest(request)

      clientOpt <- personRepository
                     .findById(request.clientId)
                     .mapError(ex => RideError.DatabaseError(ex))
      _         <- ZIO
                     .fromOption(clientOpt)
                     .orElseFail(RideError.PersonNotFound(request.clientId))

      ride = Ride(
               id = RideId.generate(),
               clientId = request.clientId,
               creatorId = request.clientId,  // For now, creator is the client
               companyId = request.companyId, // Use companyId from request (extracted from JWT)
               pickupLocation = request.pickupLocation,
               dropoffLocation = request.dropoffLocation,
               scheduledTime = request.scheduledTime,
               requestTime = Instant.now(),
               notes = request.notes,
               airportCode = request.airportCode,
               flightNumber = request.flightNumber,
               isAirportTransfer = request.isAirportTransfer
             )

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

  val layer: ZLayer[RideRepository & PersonRepository, Nothing, RideCreationService] = ZLayer.fromFunction(
    RideCreationServiceImpl.apply
  )

  val mock: ZLayer[Any, Nothing, RideCreationService] = ZLayer.succeed {
    new RideCreationService {
      def createRide(request: CreateRideRequest): IO[RideError, RideCreationEvent] =
        val ride = Ride(
          id = RideId.generate(),
          clientId = request.clientId,
          creatorId = request.clientId,
          companyId = request.companyId,
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
