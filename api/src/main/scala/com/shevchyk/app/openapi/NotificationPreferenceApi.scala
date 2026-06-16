package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.NotificationPreferenceRepository
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.Instant

/**
 * Tapir descriptions and server logic for the notification-preference endpoints. Replaces the hand-written zio-http
 * handlers in `NotificationPreferenceRoutes` while preserving paths, default-preference behaviour, upsert semantics and
 * error mapping. Preferences are scoped to the authenticated user.
 */
object NotificationPreferenceApi:

  import AppSecure.*
  import ApiSchemas.given

  private val preferenceTag = "NotificationPreference"

  type NotificationPreferenceEnv = JwtService & NotificationPreferenceRepository

  // -- Endpoint descriptions ------------------------------------------------

  val getEndpoint = secureEndpoint.get
    .in("api" / "notification-preferences")
    .out(jsonBody[NotificationPreference])
    .tag(preferenceTag)
    .summary("Get the user's notification preferences")

  val updateEndpoint = secureEndpoint.put
    .in("api" / "notification-preferences")
    .in(jsonBody[UpdateNotificationPreferenceRequest])
    .out(jsonBody[NotificationPreference])
    .tag(preferenceTag)
    .summary("Update the user's notification preferences")

  val endpoints = List(getEndpoint, updateEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val getServer: ZServerEndpoint[NotificationPreferenceEnv, Any] = getEndpoint
    .serverLogic[NotificationPreferenceEnv] { user => _ =>
      for {
        repo    <- ZIO.service[NotificationPreferenceRepository]
        prefOpt <- repo.findByPersonId(PersonId(user.userId)).mapError(internal)
        pref     = prefOpt.getOrElse(
                     NotificationPreference(
                       id = NotificationPreferenceId.generate(),
                       personId = PersonId(user.userId)
                     )
                   )
      } yield pref
    }

  private val updateServer: ZServerEndpoint[NotificationPreferenceEnv, Any] = updateEndpoint
    .serverLogic[NotificationPreferenceEnv] { user => req =>
      for {
        repo     <- ZIO.service[NotificationPreferenceRepository]
        existing <- repo.findByPersonId(PersonId(user.userId)).mapError(internal)
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
        saved    <- repo.upsert(updated).mapError(internal)
      } yield saved
    }

  val serverEndpoints: List[ZServerEndpoint[NotificationPreferenceEnv, Any]] = List(
    getServer,
    updateServer
  )
