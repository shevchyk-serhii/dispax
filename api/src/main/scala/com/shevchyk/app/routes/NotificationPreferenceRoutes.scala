package com.shevchyk.app.routes

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.NotificationPreferenceRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object NotificationPreferenceRoutes:

  val authenticatedRoutes: Routes[NotificationPreferenceRepository & JwtService, Response] = Routes(
    // GET /api/notification-preferences — get user's preferences
    Method.GET / "api" / "notification-preferences" -> RouteHelpers.authHandler("NotificationPreference") { (user, _) =>
      for {
        repo    <- ZIO.service[NotificationPreferenceRepository]
        prefOpt <- repo.findByPersonId(PersonId(user.userId))
        pref     = prefOpt.getOrElse(
                     NotificationPreference(
                       id = NotificationPreferenceId.generate(),
                       personId = PersonId(user.userId)
                     )
                   )
      } yield Response.json(pref.toJson)
    },

    // PUT /api/notification-preferences — update preferences
    Method.PUT / "api" / "notification-preferences" -> RouteHelpers.authHandler("NotificationPreference") {
      (user, request) =>
        for {
          bodyStr  <- request.body.asString
          req      <- ZIO
                        .fromEither(bodyStr.fromJson[UpdateNotificationPreferenceRequest])
                        .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          repo     <- ZIO.service[NotificationPreferenceRepository]
          existing <- repo.findByPersonId(PersonId(user.userId))
          current   = existing.getOrElse(
                        NotificationPreference(
                          id = NotificationPreferenceId.generate(),
                          personId = PersonId(user.userId)
                        )
                      )
          updated   = current.copy(
                        rideUpdates = req.rideUpdates.getOrElse(current.rideUpdates),
                        chatMessages = req.chatMessages.getOrElse(current.chatMessages),
                        driverApproaching = req.driverApproaching.getOrElse(current.driverApproaching),
                        geofenceAlerts = req.geofenceAlerts.getOrElse(current.geofenceAlerts),
                        poolUpdates = req.poolUpdates.getOrElse(current.poolUpdates),
                        emailNotifications = req.emailNotifications.getOrElse(current.emailNotifications),
                        smsNotifications = req.smsNotifications.getOrElse(current.smsNotifications),
                        quietHoursStart = req.quietHoursStart.orElse(current.quietHoursStart),
                        quietHoursEnd = req.quietHoursEnd.orElse(current.quietHoursEnd),
                        updatedAt = Instant.now()
                      )
          saved    <- repo.upsert(updated)
        } yield Response.json(saved.toJson)
    }
  )
