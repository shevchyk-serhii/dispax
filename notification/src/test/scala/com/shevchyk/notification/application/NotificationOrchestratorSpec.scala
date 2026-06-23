package com.shevchyk.notification.application

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.notification.domain.PushNotification
import com.shevchyk.notification.repository.InMemoryFcmTokenRepository
import zio.test.*
import zio.*

import java.util.UUID

object NotificationOrchestratorSpec extends ZIOSpecDefault {

  private val testLayers = InMemoryFcmTokenRepository.layer >>> FcmService.layer >>> NotificationOrchestrator.layer

  private val testPerson   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  private val testCompany  = CompanyId(UUID.fromString("00000050-0000-0000-0000-000000000001"))
  private val notification = PushNotification(title = "Ride assigned", body = "You have a new ride")

  /**
   * FcmService that records call count and optionally fails.
   */
  final private class RecordingFcmService(fail: Boolean) extends FcmService {

    val calls: Ref[Int]                                                                                      = Unsafe.unsafe { implicit u =>
      Runtime.default.unsafe.run(Ref.make(0)).getOrThrowFiberFailure()
    }
    def registerToken(personId: PersonId, companyId: CompanyId, token: String, platform: String): Task[Unit] = ZIO.unit
    def unregisterToken(token: String): Task[Unit]                                                           = ZIO.unit

    def sendToUser(personId: PersonId, companyId: CompanyId, n: PushNotification): Task[Unit] =
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
        }.provide(testLayers),
        test("sendNotification does not invoke FCM (pure log, zero FCM calls)") {
          val fcm = new RecordingFcmService(fail = false)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            _            <- orchestrator.sendNotification("No FCM needed")
            calls        <- fcm.calls.get
          } yield assertTrue(calls == 0)
        }
      ),
      suite("sendPushToUser")(
        test("delegates to FcmService when it succeeds") {
          val fcm = new RecordingFcmService(fail = false)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            _            <- orchestrator.sendPushToUser(testPerson, testCompany, notification)
            calls        <- fcm.calls.get
          } yield assertTrue(calls == 1)
        },
        test("swallows FcmService failure (push is best-effort, never propagates)") {
          val fcm = new RecordingFcmService(fail = true)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            // .ignore in the orchestrator must turn the FCM failure into a successful Unit
            exit         <- orchestrator.sendPushToUser(testPerson, testCompany, notification).exit
            calls        <- fcm.calls.get
          } yield assertTrue(exit.isSuccess, calls == 1)
        },
        test("sendPushToUser logs a warning when FcmService fails") {
          val fcm = new RecordingFcmService(fail = true)
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            _            <- orchestrator.sendPushToUser(testPerson, testCompany, notification)
            logs         <- ZTestLogger.logOutput
          } yield assertTrue(
            logs.exists(e => e.logLevel == zio.LogLevel.Warning && e.message().contains("Push notification failed"))
          )
        },
        test("sendPushToUser delegates FCM call regardless of whether data map is empty or populated") {
          val fcm         = new RecordingFcmService(fail = false)
          val withData    = PushNotification(title = "T", body = "B", data = Map("k" -> "v"))
          val withoutData = PushNotification(title = "T", body = "B")
          for {
            orchestrator <- ZIO.service[NotificationOrchestrator].provide(orchestratorWith(fcm))
            _            <- orchestrator.sendPushToUser(testPerson, testCompany, withoutData)
            _            <- orchestrator.sendPushToUser(testPerson, testCompany, withData)
            calls        <- fcm.calls.get
          } yield assertTrue(calls == 2)
        }
      )
    )
}
