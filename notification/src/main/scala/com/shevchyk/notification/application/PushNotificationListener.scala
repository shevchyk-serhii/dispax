package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{CompanyId, PersonId, RideId, WebSocketEvent}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, PushNotification}
import com.shevchyk.notification.repository.{CheckpointNotificationRepository, NotificationRepository}
import zio.*
import zio.json.*

object PushNotificationListener:

  def start: ZIO[EventHub & FcmService & NotificationRepository & CheckpointNotificationRepository, Nothing, Unit] =
    for
      eventHub       <- ZIO.service[EventHub]
      fcmService     <- ZIO.service[FcmService]
      notifRepo      <- ZIO.service[NotificationRepository]
      checkpointRepo <- ZIO.service[CheckpointNotificationRepository]
      // The Hub subscription is a scoped resource: it stays open only while its
      // Scope is open. We keep the Scope open for the whole lifetime of the
      // daemon fiber (ZIO.scoped wraps the forever-loop) instead of closing it
      // the moment `start` returns — otherwise the subscription is released
      // immediately and the listener never receives any events.
      //
      // `subscribed` is completed once the Hub subscription is registered, and
      // `start` waits on it before returning. This guarantees that any event
      // published after `start` completes will be delivered to this listener
      // (a Hub only fans out to subscribers present at publish time).
      subscribed     <- Promise.make[Nothing, Unit]
      _              <-
        ZIO
          .scoped(
            eventHub.subscribe.flatMap { dequeue =>
              subscribed.succeed(()) *>
                dequeue.take.flatMap { event =>
                  handleEvent(fcmService, notifRepo, checkpointRepo, event).catchAll(e =>
                    ZIO.logWarning(s"Push notification error: ${Option(e.getMessage).getOrElse(e.toString)}")
                  )
                }.forever
            }
          )
          .forkDaemon
      _              <- subscribed.await
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

  /**
   * Sends a push to the user and persists it to their in-app inbox.
   */
  private def notifyUser(
      fcmService: FcmService,
      repo: NotificationRepository,
      personId: PersonId,
      companyId: CompanyId,
      notification: PushNotification,
      notifType: String
  ): Task[Unit] =
    fcmService.sendToUser(personId, notification) *>
      saveNotification(
        repo,
        personId,
        companyId,
        notification.title,
        notification.body,
        notifType,
        notification.data
      )

  private def handleEvent(
      fcmService: FcmService,
      notifRepo: NotificationRepository,
      checkpointRepo: CheckpointNotificationRepository,
      event: WebSocketEvent
  ): Task[Unit] =
    event match
      case WebSocketEvent.RideAssigned(rideId, driverId, clientId, companyId) =>
        // Notify the assigned driver…
        val driverNotif = PushNotification(
          title = "New Ride Assigned",
          body = "A new ride has been assigned to you.",
          data = Map("type" -> "ride_assigned", "rideId" -> rideId.toString)
        )
        // …and the client whose ride it is.
        val clientNotif = PushNotification(
          title = "Driver Assigned",
          body = "A driver has been assigned to your ride.",
          data = Map("type" -> "ride_assigned", "rideId" -> rideId.toString)
        )
        notifyUser(fcmService, notifRepo, PersonId(driverId), CompanyId(companyId), driverNotif, "ride_assigned") *>
          notifyUser(fcmService, notifRepo, PersonId(clientId), CompanyId(companyId), clientNotif, "ride_assigned")

      case WebSocketEvent.RideStatusChanged(rideId, newStatus, driverIdOpt, clientId, companyId) =>
        // (driverNotif, clientNotif) per status; None means no notification.
        val notifications: Option[(PushNotification, PushNotification)] =
          newStatus match
            case "InProgress" =>
              Some(
                PushNotification(
                  title = "Ride Started",
                  body = "Your ride is now in progress.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                ),
                PushNotification(
                  title = "Ride Started",
                  body = "Your driver has started the ride.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                )
              )
            case "Completed"  =>
              Some(
                PushNotification(
                  title = "Ride Completed",
                  body = "Your ride has been completed.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                ),
                PushNotification(
                  title = "Ride Completed",
                  body = "Your ride has been completed.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                )
              )
            case "Cancelled"  =>
              Some(
                PushNotification(
                  title = "Ride Cancelled",
                  body = "A ride assigned to you has been cancelled.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                ),
                PushNotification(
                  title = "Ride Cancelled",
                  body = "Your ride has been cancelled.",
                  data = Map("type" -> "ride_status_changed", "rideId" -> rideId.toString, "status" -> newStatus)
                )
              )
            case _            => None

        notifications match
          case Some((driverNotif, clientNotif)) =>
            // Driver only when one is assigned; the client is always notified.
            val notifyDriver =
              driverIdOpt match
                case Some(driverId) =>
                  notifyUser(
                    fcmService,
                    notifRepo,
                    PersonId(driverId),
                    CompanyId(companyId),
                    driverNotif,
                    "ride_status_changed"
                  )
                case None           => ZIO.unit
            notifyDriver *>
              notifyUser(
                fcmService,
                notifRepo,
                PersonId(clientId),
                CompanyId(companyId),
                clientNotif,
                "ride_status_changed"
              )
          case None                             => ZIO.unit

      case WebSocketEvent.RideCreated(rideId, clientId, companyId) =>
        // Dispatchers are notified via WebSocket. Send the client a booking
        // confirmation for their own inbox.
        val clientNotif = PushNotification(
          title = "Ride Booked",
          body = "Your ride request has been received.",
          data = Map("type" -> "ride_created", "rideId" -> rideId.toString)
        )
        notifyUser(fcmService, notifRepo, PersonId(clientId), CompanyId(companyId), clientNotif, "ride_created")

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

      case WebSocketEvent.DriverApproaching(rideId, driverId, clientId, distanceMeters, threshold, companyId) =>
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
        // The client for this ride receives the proximity notification.
        notifyUser(fcmService, notifRepo, PersonId(clientId), CompanyId(companyId), notification, "driver_approaching")

      case WebSocketEvent.AirportCheckpointReached(
            rideId,
            driverId,
            clientId,
            checkpointType,
            checkpointName,
            companyId
          ) =>
        for
          alreadySent <- checkpointRepo.isAlreadySent(RideId(rideId), PersonId(driverId), checkpointType)
          _           <-
            ZIO.unless(alreadySent) {
              val notification = PushNotification(
                title = s"Client at $checkpointName",
                body = s"Your client has reached $checkpointName.",
                data = Map(
                  "type"           -> "airport_checkpoint",
                  "rideId"         -> rideId.toString,
                  "checkpointType" -> checkpointType,
                  "checkpointName" -> checkpointName
                )
              )
              notifyUser(
                fcmService,
                notifRepo,
                PersonId(driverId),
                CompanyId(companyId),
                notification,
                "airport_checkpoint"
              ) *>
                checkpointRepo.markSent(RideId(rideId), PersonId(driverId), checkpointType)
            }
        yield ()
