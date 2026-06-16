package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class NotificationPreferenceId(value: UUID) derives JsonCodec

object NotificationPreferenceId:
  def generate(): NotificationPreferenceId = NotificationPreferenceId(UuidCreator.getTimeOrderedEpoch())

final case class NotificationPreference(
    id: NotificationPreferenceId,
    personId: PersonId,
    rideUpdates: Boolean = true,
    chatMessages: Boolean = true,
    driverApproaching: Boolean = true,
    geofenceAlerts: Boolean = true,
    poolUpdates: Boolean = true,
    emailNotifications: Boolean = false,
    smsNotifications: Boolean = false,
    quietHoursStart: Option[String] = None,
    quietHoursEnd: Option[String] = None,
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class UpdateNotificationPreferenceRequest(
    rideUpdates: Option[Boolean] = None,
    chatMessages: Option[Boolean] = None,
    driverApproaching: Option[Boolean] = None,
    geofenceAlerts: Option[Boolean] = None,
    poolUpdates: Option[Boolean] = None,
    emailNotifications: Option[Boolean] = None,
    smsNotifications: Option[Boolean] = None,
    quietHoursStart: Option[String] = None,
    quietHoursEnd: Option[String] = None
) derives JsonCodec:

  /** Apply the patch onto existing preferences. Toggles default to their
    * current value; the optional quiet-hours fields keep the current value when
    * unset (never cleared); `updatedAt` is refreshed.
    */
  def applyTo(current: NotificationPreference): NotificationPreference =
    current.copy(
      rideUpdates = rideUpdates.getOrElse(current.rideUpdates),
      chatMessages = chatMessages.getOrElse(current.chatMessages),
      driverApproaching = driverApproaching.getOrElse(current.driverApproaching),
      geofenceAlerts = geofenceAlerts.getOrElse(current.geofenceAlerts),
      poolUpdates = poolUpdates.getOrElse(current.poolUpdates),
      emailNotifications = emailNotifications.getOrElse(current.emailNotifications),
      smsNotifications = smsNotifications.getOrElse(current.smsNotifications),
      quietHoursStart = quietHoursStart.orElse(current.quietHoursStart),
      quietHoursEnd = quietHoursEnd.orElse(current.quietHoursEnd),
      updatedAt = Instant.now()
    )
