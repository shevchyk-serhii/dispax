package com.shevchyk.notification.application

import com.shevchyk.notification.repository.InMemoryFcmTokenRepository
import zio.test.*
import zio.*

object NotificationOrchestratorSpec extends ZIOSpecDefault {

  private val testLayers = InMemoryFcmTokenRepository.layer >>> FcmService.layer >>> NotificationOrchestrator.layer

  def spec = suite("NotificationOrchestrator")(
    suite("sendNotification")(
      test("should successfully send notification") {
        for {
          orchestrator <- ZIO.service[NotificationOrchestrator]
          result       <- orchestrator.sendNotification("Test notification")
        } yield assertTrue(result == ())
      }.provide(testLayers),

      test("should handle empty message") {
        for {
          orchestrator <- ZIO.service[NotificationOrchestrator]
          result       <- orchestrator.sendNotification("")
        } yield assertTrue(result == ())
      }.provide(testLayers)
    )
  )
}
