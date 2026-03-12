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
) derives JsonCodec
