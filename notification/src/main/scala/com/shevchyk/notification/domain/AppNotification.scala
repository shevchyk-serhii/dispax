package com.shevchyk.notification.domain

import com.shevchyk.core.domain.{PersonId, CompanyId}
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class AppNotificationId(value: UUID) derives JsonCodec

object AppNotificationId:
  def generate(): AppNotificationId = AppNotificationId(UuidCreator.getTimeOrderedEpoch())

final case class AppNotification(
    id: AppNotificationId,
    personId: PersonId,
    companyId: CompanyId,
    title: String,
    body: String,
    notificationType: String,
    data: Option[String] = None,
    isRead: Boolean = false,
    createdAt: Instant = Instant.now()
) derives JsonCodec

final case class UnreadCountResponse(
    count: Int
) derives JsonCodec
