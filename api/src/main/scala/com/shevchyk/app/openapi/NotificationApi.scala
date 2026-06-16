package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import com.shevchyk.notification.repository.NotificationRepository
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the in-app notification endpoints. Replaces the hand-written zio-http
 * handlers in `NotificationRoutes` while preserving paths, query params, type filtering, status codes and error
 * mapping. These endpoints scope to the authenticated user (`PersonId(user.userId)`); no extra role check is performed.
 */
object NotificationApi:

  import AppSecure.*
  import ApiSchemas.given

  private val notificationTag = "Notification"

  type NotificationEnv = JwtService & NotificationRepository

  // -- Endpoint descriptions ------------------------------------------------

  val unreadCountEndpoint = secureEndpoint.get
    .in("api" / "notifications" / "unread-count")
    .out(jsonBody[UnreadCountResponse])
    .tag(notificationTag)
    .summary("Get the unread notification count")

  val markAsReadEndpoint = secureEndpoint.put
    .in("api" / "notifications" / path[String]("id") / "read")
    .out(statusCode)
    .tag(notificationTag)
    .summary("Mark a notification as read")

  val markAllReadEndpoint = secureEndpoint.put
    .in("api" / "notifications" / "read-all")
    .out(statusCode(StatusCode.NoContent))
    .tag(notificationTag)
    .summary("Mark all notifications as read")

  val listEndpoint = secureEndpoint.get
    .in("api" / "notifications")
    .in(query[Option[Int]]("limit"))
    .in(query[Option[Int]]("offset"))
    .in(query[Option[String]]("type"))
    .out(jsonBody[List[AppNotification]])
    .tag(notificationTag)
    .summary("List the user's notifications (paginated, filterable by type)")

  val deleteEndpoint = secureEndpoint.delete
    .in("api" / "notifications" / path[String]("id"))
    .out(statusCode)
    .tag(notificationTag)
    .summary("Delete a notification")

  val deleteAllEndpoint = secureEndpoint.delete
    .in("api" / "notifications")
    .out(statusCode(StatusCode.NoContent))
    .tag(notificationTag)
    .summary("Delete all notifications for the user")

  val endpoints = List(
    unreadCountEndpoint,
    markAsReadEndpoint,
    markAllReadEndpoint,
    listEndpoint,
    deleteEndpoint,
    deleteAllEndpoint
  )

  // -- Server logic ---------------------------------------------------------

  private val listServer: ZServerEndpoint[NotificationEnv, Any] = listEndpoint.serverLogic[NotificationEnv] { user =>
    { case (limitOpt, offsetOpt, typeFilter) =>
      val limit  = limitOpt.getOrElse(20).min(100).max(1)
      val offset = offsetOpt.getOrElse(0).max(0)
      for {
        repo          <- ZIO.service[NotificationRepository]
        notifications <- repo.findByPersonId(PersonId(user.userId), limit, offset).mapError(internal)
        filtered       =
          typeFilter match
            case Some(t) => notifications.filter(_.notificationType == t)
            case None    => notifications
      } yield filtered
    }
  }

  private val unreadCountServer: ZServerEndpoint[NotificationEnv, Any] = unreadCountEndpoint
    .serverLogic[NotificationEnv] { user => _ =>
      for {
        repo  <- ZIO.service[NotificationRepository]
        count <- repo.countUnread(PersonId(user.userId)).mapError(internal)
      } yield UnreadCountResponse(count)
    }

  private val markAsReadServer: ZServerEndpoint[NotificationEnv, Any] = markAsReadEndpoint
    .serverLogic[NotificationEnv] { user => id =>
      for {
        repo   <- ZIO.service[NotificationRepository]
        nId    <- parseUuid(id).map(AppNotificationId(_))
        marked <- repo.markAsRead(nId, PersonId(user.userId)).mapError(internal)
      } yield if marked then StatusCode.NoContent else StatusCode.NotFound
    }

  private val markAllReadServer: ZServerEndpoint[NotificationEnv, Any] = markAllReadEndpoint
    .serverLogic[NotificationEnv] { user => _ =>
      (for {
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.markAllAsRead(PersonId(user.userId)).mapError(internal)
      } yield ()).unit
    }

  private val deleteServer: ZServerEndpoint[NotificationEnv, Any] = deleteEndpoint.serverLogic[NotificationEnv] {
    user => id =>
      for {
        repo    <- ZIO.service[NotificationRepository]
        nId     <- parseUuid(id).map(AppNotificationId(_))
        deleted <- repo.delete(nId, PersonId(user.userId)).mapError(internal)
      } yield if deleted then StatusCode.NoContent else StatusCode.NotFound
  }

  private val deleteAllServer: ZServerEndpoint[NotificationEnv, Any] = deleteAllEndpoint.serverLogic[NotificationEnv] {
    user => _ =>
      (for {
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.deleteAllForPerson(PersonId(user.userId)).mapError(internal)
      } yield ()).unit
  }

  // Static sub-paths (/unread-count, /read-all, /{id}/read) precede the bare /{id} matcher.
  val serverEndpoints: List[ZServerEndpoint[NotificationEnv, Any]] = List(
    unreadCountServer,
    markAllReadServer,
    markAsReadServer,
    listServer,
    deleteServer,
    deleteAllServer
  )
