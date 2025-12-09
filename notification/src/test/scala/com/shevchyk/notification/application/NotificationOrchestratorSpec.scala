package com.shevchyk.notification.application

import zio.test.*
import zio.*

object NotificationOrchestratorSpec extends ZIOSpecDefault {

  def spec = suite("NotificationOrchestrator")(
    suite("sendNotification")(
      test("should successfully send notification") {
        for {
          orchestrator <- ZIO.service[NotificationOrchestrator]
          result       <- orchestrator.sendNotification("Test notification")
        } yield assertTrue(result == ())
      }.provide(NotificationOrchestrator.layer),

      test("should handle empty message") {
        for {
          orchestrator <- ZIO.service[NotificationOrchestrator]
          result       <- orchestrator.sendNotification("")
        } yield assertTrue(result == ())
      }.provide(NotificationOrchestrator.layer)
    )
  )
}