package com.shevchyk.notification.domain

import com.shevchyk.core.domain.{PersonId, CompanyId}
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

// Serializes as a *flat* JSON string ("uuid"), not as an object {"value":"uuid"},
// matching the PersonId/CompanyId convention the clients expect. The default
// `derives JsonCodec` on a single-field case class would emit the object form,
// which crashed the Flutter notifications screen (it reads `id` as a plain String).
case class AppNotificationId(value: UUID)

object AppNotificationId:
  def generate(): AppNotificationId = AppNotificationId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[AppNotificationId] = JsonEncoder[String].contramap(_.value.toString)
  given JsonDecoder[AppNotificationId] = JsonDecoder[String].mapOrFail(s =>
    scala.util.Try(UUID.fromString(s)).toEither.left.map(_ => s"Invalid UUID: $s").map(AppNotificationId.apply)
  )

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
