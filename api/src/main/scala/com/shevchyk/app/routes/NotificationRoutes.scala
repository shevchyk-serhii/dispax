package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import com.shevchyk.notification.repository.NotificationRepository
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

object NotificationRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("Notification")(ex)

  val authenticatedRoutes: Routes[NotificationRepository & JwtService, Response] = Routes(
    // GET /api/notifications — get user's notifications (paginated, filterable by type)
    Method.GET / "api" / "notifications"                         -> handler { (request: Request) =>
      (for {
        user          <- AuthMiddleware.authenticateRequest(request)
        limit          = request.url.queryParams.queryParam("limit").flatMap(_.toIntOption).getOrElse(20)
        offset         = request.url.queryParams.queryParam("offset").flatMap(_.toIntOption).getOrElse(0)
        typeFilter     = request.url.queryParams.queryParam("type")
        repo          <- ZIO.service[NotificationRepository]
        notifications <- repo.findByPersonId(PersonId(user.userId), limit, offset)
        filtered       =
          typeFilter match
            case Some(t) => notifications.filter(_.notificationType == t)
            case None    => notifications
      } yield Response.json(filtered.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // GET /api/notifications/unread-count — get unread count
    Method.GET / "api" / "notifications" / "unread-count"        -> handler { (request: Request) =>
      (for {
        user  <- AuthMiddleware.authenticateRequest(request)
        repo  <- ZIO.service[NotificationRepository]
        count <- repo.countUnread(PersonId(user.userId))
      } yield Response.json(UnreadCountResponse(count).toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // PUT /api/notifications/{id}/read — mark as read
    Method.PUT / "api" / "notifications" / string("id") / "read" -> handler { (id: String, request: Request) =>
      (for {
        user   <- AuthMiddleware.authenticateRequest(request)
        repo   <- ZIO.service[NotificationRepository]
        nId    <- UuidParser.parse(id).map(AppNotificationId(_))
        marked <- repo.markAsRead(nId)
      } yield if marked then Response(Status.NoContent) else Response.status(Status.NotFound)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // PUT /api/notifications/read-all — mark all as read
    Method.PUT / "api" / "notifications" / "read-all"            -> handler { (request: Request) =>
      (for {
        user <- AuthMiddleware.authenticateRequest(request)
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.markAllAsRead(PersonId(user.userId))
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // DELETE /api/notifications/{id} — delete a notification
    Method.DELETE / "api" / "notifications" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user <- AuthMiddleware.authenticateRequest(request)
        repo <- ZIO.service[NotificationRepository]
        nId  <- UuidParser.parse(id).map(AppNotificationId(_))
        _    <- repo.delete(nId)
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // DELETE /api/notifications — delete all notifications for user
    Method.DELETE / "api" / "notifications" -> handler { (request: Request) =>
      (for {
        user <- AuthMiddleware.authenticateRequest(request)
        repo <- ZIO.service[NotificationRepository]
        _    <- repo.deleteAllForPerson(PersonId(user.userId))
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
