package com.shevchyk.notification.application

import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.PushNotification
import com.shevchyk.notification.repository.InMemoryFcmTokenRepository
import zio.test.*
import zio.*

import java.util.UUID

object NotificationOrchestratorSpec extends ZIOSpecDefault {

  private val testLayers = InMemoryFcmTokenRepository.layer >>> FcmService.layer >>> NotificationOrchestrator.layer

  private val testPerson   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  private val notification = PushNotification(title = "Ride assigned", body = "You have a new ride")

  /**
   * FcmService that records call count and optionally fails.
   */
  final private class RecordingFcmService(fail: Boolean) extends FcmService {

    val calls: Ref[Int]                                                                = Unsafe.unsafe { implicit u =>
      Runtime.default.unsafe.run(Ref.make(0)).getOrThrowFiberFailure()
    }
    def registerToken(personId: PersonId, token: String, platform: String): Task[Unit] = ZIO.unit
    def unregisterToken(token: String): Task[Unit]                                     = ZIO.unit

    def sendToUser(personId: PersonId, n: PushNotification): Task[Unit] =
      calls.update(_ + 1) *> (if fail then ZIO.fail(new RuntimeException("FCM down")) else ZIO.unit)
  }

  private def orchestratorWith(fcm: FcmService): ZLayer[Any, Nothing, NotificationOrchestrator] =
    ZLayer.succeed[FcmService](fcm) >>> NotificationOrchestrator.layer

  def spec =
    suite("NotificationOrchestrator")(
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
      ),
      suite("sendPushToUser")(
        test("delegates to FcmService when it succeeds") {
          val fcm = new RecordingFcmService(fail = false)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            _            <- orchestrator.sendPushToUser(testPerson, notification)
            calls        <- fcm.calls.get
          } yield assertTrue(calls == 1)
        },
        test("swallows FcmService failure (push is best-effort, never propagates)") {
          val fcm = new RecordingFcmService(fail = true)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            // .ignore in the orchestrator must turn the FCM failure into a successful Unit
            exit         <- orchestrator.sendPushToUser(testPerson, notification).exit
            calls        <- fcm.calls.get
          } yield assertTrue(exit.isSuccess, calls == 1)
        }
      )
    )
}
