package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{CompanyId, PersonId, WebSocketEvent}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, PushNotification}
import com.shevchyk.notification.repository.NotificationRepository
import zio.*
import zio.json.*

object PushNotificationListener:

  def start: ZIO[EventHub & FcmService & NotificationRepository & Scope, Nothing, Unit] =
    for
      eventHub   <- ZIO.service[EventHub]
      fcmService <- ZIO.service[FcmService]
      notifRepo  <- ZIO.service[NotificationRepository]
      dequeue    <- eventHub.subscribe
      _          <-
        dequeue.take
          .flatMap { event =>
            handleEvent(fcmService, notifRepo, event).catchAll(e =>
              ZIO.logWarning(s"Push notification error: ${Option(e.getMessage).getOrElse(e.toString)}")
            )
          }
          .forever
          .forkDaemon
    yield ()

  private def saveNotification(
      repo: NotificationRepository,
      personId: PersonId,
      companyId: CompanyId,
      title: String,
      body: String,
      notifType: String,
      data: Map[String, String]
  ): Task[Unit] =
    repo
      .save(
        AppNotification(
          id = AppNotificationId.generate(),
          personId = personId,
          companyId = companyId,
          title = title,
          body = body,
          notificationType = notifType,
          data = Some(data.toJson)
        )
      )
      .unit

  private def handleEvent(
      fcmService: FcmService,
      notifRepo: NotificationRepository,
      event: WebSocketEvent
  ): Task[Unit] =
    event match
      case WebSocketEvent.RideAssigned(rideId, driverId, companyId) =>
        val notification = PushNotification(
          title = "New Ride Assigned",
          body = "A new ride has been assigned to you.",
          data = Map("type" -> "ride_assigned", "rideId" -> rideId.toString)
        )
        fcmService.sendToUser(PersonId(driverId), notification) *>
          saveNotification(
            notifRepo,
            PersonId(driverId),
            CompanyId(companyId),
            notification.title,
            notification.body,
            "ride_assigned",
            notification.data
          )

      case WebSocketEvent.RideStatusChanged(rideId, newStatus, driverIdOpt, companyId) =>
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
            driverIdOpt match
              case Some(driverId) =>
                fcmService.sendToUser(PersonId(driverId), notif) *>
                  saveNotification(
                    notifRepo,
                    PersonId(driverId),
                    CompanyId(companyId),
                    notif.title,
                    notif.body,
                    "ride_status_changed",
                    notif.data
                  )
              case None           => ZIO.unit
          case None        => ZIO.unit

      case WebSocketEvent.RideCreated(_, _, _) =>
        // Dispatchers are notified via WebSocket. No individual push needed.
        ZIO.unit

      case _: WebSocketEvent.LocationUpdated =>
        // Location updates are real-time only, no push needed.
        ZIO.unit

      case _: WebSocketEvent.ChatMessageSent =>
        // Chat messages are delivered via WebSocket, no push needed.
        ZIO.unit

      case WebSocketEvent.GeofenceTriggered(geofenceId, geofenceName, driverId, alertType, lat, lng, companyId) =>
        val actionText   = if alertType == "entry" then "entered" else "exited"
        val notification = PushNotification(
          title = "Geofence Alert",
          body = s"Driver $actionText geofence: $geofenceName",
          data = Map(
            "type"         -> "geofence_triggered",
            "geofenceId"   -> geofenceId.toString,
            "geofenceName" -> geofenceName,
            "driverId"     -> driverId.toString,
            "alertType"    -> alertType
          )
        )
        // Send to dispatchers via the notification - they subscribe to company events
        // For now, we log it. In production, we'd query dispatchers for the company.
        ZIO.logInfo(s"Geofence alert: driver $driverId $actionText '$geofenceName'").unit

      case WebSocketEvent.DriverApproaching(rideId, driverId, distanceMeters, threshold, companyId) =>
        val notification = PushNotification(
          title = "Driver Approaching",
          body = s"Your driver is $threshold away.",
          data = Map(
            "type"           -> "driver_approaching",
            "rideId"         -> rideId.toString,
            "driverId"       -> driverId.toString,
            "distanceMeters" -> distanceMeters.toString,
            "threshold"      -> threshold
          )
        )
        // The client for this ride should receive the push notification
        // For now, we log it since we'd need to look up the client from the ride
        ZIO.logInfo(s"Driver approaching: ride $rideId, threshold $threshold, distance ${distanceMeters}m").unit
