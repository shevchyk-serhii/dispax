package com.shevchyk.notification.domain

import com.shevchyk.core.domain.PersonId
import zio.json.*
import java.time.Instant

case class FcmToken(
    personId: PersonId,
    token: String,
    platform: String,
    createdAt: Instant
)

case class RegisterFcmTokenRequest(
    token: String,
    platform: String
) derives JsonDecoder

case class PushNotification(
    title: String,
    body: String,
    data: Map[String, String] = Map.empty
)
