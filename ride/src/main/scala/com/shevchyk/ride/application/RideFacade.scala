package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.*
import com.shevchyk.ride.repository.RideRepository
import zio.*

case class RideFacade(
    rideService: SimpleRideService,
    rideRepository: RideRepository
):

  def createRide(request: CreateRideRequest): IO[RideError, Ride] = rideService.createRide(request)

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideService.getRideById(rideId)

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] = rideRepository
    .findByClientId(userId)
    .orElse(rideRepository.findByDriverId(userId))
    .mapError(ex => RideError.DatabaseError(ex.getCause))

  def updateRideStatus(rideId: RideId, status: RideStatus, notes: Option[String]): IO[RideError, Ride] =
    for {
      maybeRide <- rideRepository.findById(rideId).mapError(ex => RideError.DatabaseError(ex.getCause))
      ride      <- ZIO.fromOption(maybeRide).orElseFail(RideError.RideNotFound(rideId))

      _ <-
        status match {
          case RideStatus.Assigned if ride.status != RideStatus.Requested   =>
            ZIO.fail(RideError.InvalidStatusTransition(ride.status, status))
          case RideStatus.InProgress if ride.status != RideStatus.Assigned  =>
            ZIO.fail(RideError.InvalidStatusTransition(ride.status, status))
          case RideStatus.Completed if ride.status != RideStatus.InProgress =>
            ZIO.fail(RideError.InvalidStatusTransition(ride.status, status))
          case _                                                            => ZIO.unit
        }

      updatedRide = ride.copy(
                      status = status,
                      notes = notes.orElse(ride.notes),
                      startTime =
                        if (status == RideStatus.InProgress)
                          Some(java.time.Instant.now())
                        else
                          ride.startTime,
                      endTime =
                        if (status == RideStatus.Completed)
                          Some(java.time.Instant.now())
                        else
                          ride.endTime
                    )

      result <- rideRepository.update(updatedRide).mapError(ex => RideError.DatabaseError(ex.getCause))
    } yield result

object RideFacade:
  val layer: ZLayer[SimpleRideService & RideRepository, Nothing, RideFacade] = ZLayer.fromFunction(RideFacade.apply)
