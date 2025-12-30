package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.RideRepository
import zio.*

case class RideFacade(rideService: RideService, rideRepository: RideRepository):

  def createRide(request: CreateRideRequest): IO[RideError, Ride] = rideService.createRide(request)

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideService.getRideById(rideId)

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] = rideRepository
    .findByClientId(userId)
    .orElse(rideRepository.findByDriverId(userId))
    .mapError(ex => RideError.DatabaseError(ex))

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] = rideService.startRide(rideId, driverId)

  def completeRide(rideId: RideId): IO[RideError, Ride] = rideService.completeRide(rideId)

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] = rideService.cancelRide(
    rideId,
    userId,
    userRole
  )

  def updateRideStatus(rideId: RideId, status: RideStatus, notes: Option[String]): IO[RideError, Ride] = rideService
    .updateRideStatus(rideId, UpdateRideStatusRequest(status, notes))

object RideFacade:
  val layer: ZLayer[RideService & RideRepository, Nothing, RideFacade] = ZLayer.fromFunction(RideFacade.apply)
