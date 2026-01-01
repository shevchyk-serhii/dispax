package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
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
    .mapDatabaseError
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for {
      ride          <- ZIO.succeed(RideMapper.fromRequest(request))
      persistedRide <- rideRepository.create(ride).mapDatabaseError
    } yield persistedRide

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.DriverNotFound(driverId))
          .when(!ride.canBeStarted)
          .unit

      driverOpt <-
        personRepository
          .findById(driverId)
          .mapDatabaseError
      _         <- ZIO
                     .fromOption(driverOpt)
                     .orElseFail(RideError.DriverNotFound(driverId))

      updatedRide = ride.copy(
                      status = RideStatus.InProgress,
                      driverId = Some(driverId),
                      startTime = Some(Instant.now())
                    )

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

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

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

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

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

    } yield persistedRide

  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      updatedRide = ride.copy(
                      status = request.status,
                      notes = request.notes.orElse(ride.notes)
                    )

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

    } yield persistedRide

object RideService:

  val layer: ZLayer[RideRepository & PersonRepository, Nothing, RideService] = ZLayer.fromFunction(
    RideServiceImpl.apply
  )
