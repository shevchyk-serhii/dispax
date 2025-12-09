package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*

case class RideFacade(
    rideCreationService: RideCreationService,
    driverAssignmentService: DriverAssignmentService,
    rideLifecycleService: RideLifecycleService,
    notificationOrchestrator: NotificationOrchestrator
):

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for
      createdRide <- rideCreationService.createRide(request)
      _           <- notificationOrchestrator.handleRideCreated(createdRide).fork
    yield createdRide.ride

  def assignDriverToRide(rideId: RideId, requesterId: PersonId): IO[RideError, Ride] =
    for
      assignment <- driverAssignmentService.assignDriverToRide(rideId, requesterId)
      _          <- notificationOrchestrator.handleDriverAssigned(assignment).fork
    yield assignment.ride

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for
      statusChange <- rideLifecycleService.startRide(rideId, driverId)
      _            <- notificationOrchestrator.handleRideStarted(statusChange).fork
    yield statusChange.ride

  def completeRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for
      completion <- rideLifecycleService.completeRide(rideId, driverId)
      _          <- notificationOrchestrator.handleRideCompleted(completion).fork
    yield completion.ride

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] =
    for
      cancellation <- rideLifecycleService.cancelRide(rideId, userId, userRole)
      _            <- notificationOrchestrator.handleRideCancelled(cancellation).fork
    yield cancellation.ride

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideLifecycleService.getRideById(rideId)

object RideFacade:

  val layer: ZLayer[
    RideCreationService & DriverAssignmentService & RideLifecycleService & NotificationOrchestrator,
    Nothing,
    RideFacade
  ] = ZLayer.fromFunction(RideFacade.apply)
