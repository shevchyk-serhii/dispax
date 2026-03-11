package com.shevchyk.notification.application

import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.PushNotification
import zio.*

trait NotificationOrchestrator:
  def sendNotification(message: String): UIO[Unit]
  def sendPushToUser(personId: PersonId, notification: PushNotification): UIO[Unit]

object NotificationOrchestrator:

  val layer: ZLayer[FcmService, Nothing, NotificationOrchestrator] = ZLayer {
    for fcmService <- ZIO.service[FcmService]
    yield new NotificationOrchestrator {
      def sendNotification(message: String): UIO[Unit] = ZIO.logInfo(s"Notification: $message")

      def sendPushToUser(personId: PersonId, notification: PushNotification): UIO[Unit] =
        fcmService
          .sendToUser(personId, notification)
          .tapError(e => ZIO.logWarning(s"Push notification failed: ${e.getMessage}"))
          .ignore
    }
  }
