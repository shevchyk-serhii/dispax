package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*

case class RideLifecycleService(
    rideRepo: RideRepository,
    driverRepo: DriverRepository
):

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, RideStatusChange] =
    for
      ride <- getRideById(rideId)
      _    <-
        ZIO
          .when(!ride.driverId.contains(driverId))(
            ZIO.fail(RideError.UnauthorizedAccess(driverId, rideId))
          )
          .unit

      startedRide <- ZIO
                       .fromEither(ride.startRide())
                       .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(startedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))
    yield RideStatusChange(ride.status, updatedRide.status, updatedRide, driverId)

  def completeRide(rideId: RideId, driverId: PersonId): IO[RideError, RideCompletion] =
    for
      ride <- getRideById(rideId)
      _    <-
        ZIO
          .when(!ride.driverId.contains(driverId))(
            ZIO.fail(RideError.UnauthorizedAccess(driverId, rideId))
          )
          .unit

      completedRide <- ZIO
                         .fromEither(ride.completeRide())
                         .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(completedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))

      _ <- driverRepo
             .updateStatus(driverId, DriverStatus.Available)
             .mapError(ErrorMapper.fromRepositoryError)
    yield RideCompletion(updatedRide, driverId)

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, RideCancellation] =
    for
      ride <- getRideById(rideId)

      _ <-
        ZIO.when(userId != ride.clientId && userRole != PersonRole.dispatcher)(
          ZIO.fail(RideError.UnauthorizedAccess(userId, rideId))
        )

      cancelledRide <- ZIO
                         .fromEither(ride.cancel())
                         .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(cancelledRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))
    yield RideCancellation(updatedRide, userId)

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepo
    .findById(rideId)
    .mapError(ErrorMapper.fromRepositoryError)
    .someOrFail(RideError.RideNotFound(rideId))

case class RideStatusChange(previousStatus: RideStatus, newStatus: RideStatus, ride: Ride, triggeredBy: PersonId)
case class RideCompletion(ride: Ride, completedBy: PersonId)
case class RideCancellation(ride: Ride, cancelledBy: PersonId)

object RideLifecycleService:

  val layer: ZLayer[RideRepository & DriverRepository, Nothing, RideLifecycleService] = ZLayer.fromFunction(
    RideLifecycleService.apply
  )
