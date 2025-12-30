package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.repository.PersonRepository
import zio.*
import java.time.Instant

trait RideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def completeRide(rideId: RideId): IO[RideError, Ride]
  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]
  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride]

class RideServiceImpl(
    rideRepository: RideRepository,
    personRepository: PersonRepository
) extends RideService:

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepository
    .findById(rideId)
    .mapError(ex => RideError.DatabaseError(ex))
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for {
      _ <- validateCreateRideRequest(request)

      clientOpt <- personRepository
                     .findById(request.clientId)
                     .mapError(ex => RideError.DatabaseError(ex))
      _         <- ZIO
                     .fromOption(clientOpt)
                     .orElseFail(RideError.PersonNotFound(request.clientId))

      ride = RideService.buildRideFromRequest(request)

      persistedRide <- rideRepository
                         .create(ride)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield persistedRide

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.DriverNotFound(driverId))
          .when(!ride.canBeStarted)
          .unit

      driverOpt <- personRepository
                     .findById(driverId)
                     .mapError(ex => RideError.DatabaseError(ex))
      _         <- ZIO
                     .fromOption(driverOpt)
                     .orElseFail(RideError.DriverNotFound(driverId))

      updatedRide = ride.copy(
                      status = RideStatus.InProgress,
                      driverId = Some(driverId),
                      startTime = Some(Instant.now())
                    )

      persistedRide <- rideRepository
                         .update(updatedRide)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield persistedRide

  def completeRide(rideId: RideId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed))
          .when(!ride.canBeCompleted)
          .unit

      updatedRide = ride.copy(
                      status = RideStatus.Completed,
                      endTime = Some(Instant.now())
                    )

      persistedRide <- rideRepository
                         .update(updatedRide)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield persistedRide

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.status == RideStatus.Completed)
          .unit

      updatedRide = ride.copy(status = RideStatus.Cancelled)

      persistedRide <- rideRepository
                         .update(updatedRide)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield persistedRide

  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      updatedRide = ride.copy(
                      status = request.status,
                      notes = request.notes.orElse(ride.notes)
                    )

      persistedRide <- rideRepository
                         .update(updatedRide)
                         .mapError(ex => RideError.DatabaseError(ex))

    } yield persistedRide

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

object RideService:

  private[service] def buildRideFromRequest(request: CreateRideRequest): Ride = Ride(
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

  val layer: ZLayer[RideRepository & PersonRepository, Nothing, RideService] = ZLayer.fromFunction(
    RideServiceImpl.apply
  )
