package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.NotificationService
import zio.*

case class NotificationOrchestrator(notificationService: NotificationService):

  def handleRideCreated(createdRide: CreatedRide): IO[Nothing, Unit] =
    notificationService.notifyClient(createdRide.client.id, "Ride created", Some(createdRide.ride.id)).ignore

  def handleDriverAssigned(assignment: AssignmentResult): IO[Nothing, Unit] =
    for
      _ <-
        notificationService.notifyDriver(assignment.assignedDriver.id, "Ride assigned", Some(assignment.ride.id)).ignore
      _ <-
        notificationService.notifyClient(assignment.ride.clientId, "Driver assigned", Some(assignment.ride.id)).ignore
    yield ()

  def handleRideStarted(statusChange: RideStatusChange): IO[Nothing, Unit] =
    notificationService.notifyClient(statusChange.ride.clientId, "Ride started", Some(statusChange.ride.id)).ignore

  def handleRideCompleted(completion: RideCompletion): IO[Nothing, Unit] =
    notificationService.notifyClient(completion.ride.clientId, "Ride completed", Some(completion.ride.id)).ignore

  def handleRideCancelled(cancellation: RideCancellation): IO[Nothing, Unit] =
    notificationService.notifyClient(cancellation.ride.clientId, "Ride cancelled", Some(cancellation.ride.id)).ignore

object NotificationOrchestrator:

  val layer: ZLayer[NotificationService, Nothing, NotificationOrchestrator] = ZLayer.fromFunction(
    NotificationOrchestrator.apply
  )
