package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{PersonId, WebSocketEvent}
import com.shevchyk.notification.domain.PushNotification
import zio.*

object PushNotificationListener:

  def start: ZIO[EventHub & FcmService & Scope, Nothing, Unit] =
    for
      eventHub   <- ZIO.service[EventHub]
      fcmService <- ZIO.service[FcmService]
      dequeue    <- eventHub.subscribe
      _          <-
        dequeue.take
          .flatMap { event =>
            handleEvent(fcmService, event).catchAll(e => ZIO.logWarning(s"Push notification error: ${e.getMessage}"))
          }
          .forever
          .forkDaemon
    yield ()

  private def handleEvent(fcmService: FcmService, event: WebSocketEvent): Task[Unit] =
    event match
      case WebSocketEvent.RideAssigned(rideId, driverId, _) =>
        fcmService.sendToUser(
          PersonId(driverId),
          PushNotification(
            title = "New Ride Assigned",
            body = "A new ride has been assigned to you.",
            data = Map("type" -> "ride_assigned", "rideId" -> rideId.toString)
          )
        )

      case WebSocketEvent.RideStatusChanged(rideId, newStatus, driverIdOpt, _) =>
        val notification =
          newStatus match
            case "InProgress" =>
              Some(
                PushNotification(
                  title = "Ride Started",
                  body = "Your ride is now in progress.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                )
              )
            case "Completed"  =>
              Some(
                PushNotification(
                  title = "Ride Completed",
                  body = "Your ride has been completed.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                )
              )
            case _            => None

        notification match
          case Some(notif) =>
            // For status changes, ideally we'd notify the client, but we don't have clientId in the event.
            // Notify driver if present
            driverIdOpt match
              case Some(driverId) => fcmService.sendToUser(PersonId(driverId), notif)
              case None           => ZIO.unit
          case None        => ZIO.unit

      case WebSocketEvent.RideCreated(_, _, _) =>
        // Dispatchers are notified via WebSocket. No individual push needed.
        ZIO.unit

      case _: WebSocketEvent.LocationUpdated =>
        // Location updates are real-time only, no push needed.
        ZIO.unit
