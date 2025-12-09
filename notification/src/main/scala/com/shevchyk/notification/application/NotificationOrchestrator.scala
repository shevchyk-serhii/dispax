package com.shevchyk.notification.application

import com.shevchyk.core.domain.*
import zio.UIO
import zio.*

trait NotificationOrchestrator:
  def sendNotification(message: String): UIO[Unit]

object NotificationOrchestrator:

  val layer: ZLayer[Any, Nothing, NotificationOrchestrator] = ZLayer.succeed {
    new NotificationOrchestrator {
      def sendNotification(message: String): UIO[Unit] = ZIO.logInfo(s"📢 Notification: $message")
    }
  }
