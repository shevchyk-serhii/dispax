package com.shevchyk.app.routes

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import com.shevchyk.notification.repository.NotificationRepository
import zio.*
import zio.http.*
import zio.json.*

object NotificationRoutes:

  val authenticatedRoutes: Routes[NotificationRepository & JwtService, Response] = Routes(
    // GET /api/notifications — get user's notifications (paginated, filterable by type)
    Method.GET / "api" / "notifications" -> RouteHelpers.authHandler("Notification") { (user, request) =>
      val limit      = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(20).min(100).max(1)
      val offset     = request.url.queryParams.queryParam("offset").flatMap(_.toIntOption).getOrElse(0).max(0)
      val typeFilter = request.url.queryParams.queryParam("type")
      for {
        repo          <- ZIO.service[NotificationRepository]
        notifications <- repo.findByPersonId(PersonId(user.userId), limit, offset)
        filtered       =
          typeFilter match
            case Some(t) => notifications.filter(_.notificationType == t)
            case None    => notifications
      } yield Response.json(filtered.toJson)
    },

    // GET /api/notifications/unread-count — get unread count
    Method.GET / "api" / "notifications" / "unread-count" -> RouteHelpers.authHandler("Notification") { (user, _) =>
      for {
        repo  <- ZIO.service[NotificationRepository]
        count <- repo.countUnread(PersonId(user.userId))
      } yield Response.json(UnreadCountResponse(count).toJson)
    },

    // PUT /api/notifications/{id}/read — mark as read
    Method.PUT / "api" / "notifications" / string("id") / "read" -> RouteHelpers.authPathHandler("Notification") {
      (user, id: String, _) =>
        for {
          repo   <- ZIO.service[NotificationRepository]
          nId    <- UuidParser.parse(id).map(AppNotificationId(_))
          // Enforce ownership/tenant isolation: only the owning person can mark
          // their notification read; a foreign id resolves to NotFound.
          marked <- repo.markAsRead(nId, PersonId(user.userId))
        } yield if marked then Response(Status.NoContent) else Response.status(Status.NotFound)
    },

    // PUT /api/notifications/read-all — mark all as read
    Method.PUT / "api" / "notifications" / "read-all" -> RouteHelpers.authHandler("Notification") { (user, _) =>
      for {
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.markAllAsRead(PersonId(user.userId))
      } yield Response(Status.NoContent)
    },

    // DELETE /api/notifications/{id} — delete a notification
    Method.DELETE / "api" / "notifications" / string("id") -> RouteHelpers.authPathHandler("Notification") {
      (user, id: String, _) =>
        for {
          repo    <- ZIO.service[NotificationRepository]
          nId     <- UuidParser.parse(id).map(AppNotificationId(_))
          // Enforce ownership/tenant isolation: only the owning person can delete
          // their notification; a foreign id resolves to NotFound.
          deleted <- repo.delete(nId, PersonId(user.userId))
        } yield if deleted then Response(Status.NoContent) else Response.status(Status.NotFound)
    },

    // DELETE /api/notifications — delete all notifications for user
    Method.DELETE / "api" / "notifications" -> RouteHelpers.authHandler("Notification") { (user, _) =>
      for {
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.deleteAllForPerson(PersonId(user.userId))
      } yield Response(Status.NoContent)
    }
  )
