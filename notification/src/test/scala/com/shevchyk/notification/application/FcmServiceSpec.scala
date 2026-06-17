package com.shevchyk.notification.application

import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.{FcmToken, PushNotification}
import com.shevchyk.notification.repository.{FcmTokenRepository, InMemoryFcmTokenRepository}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object FcmServiceSpec extends ZIOSpecDefault {

  val personId1 = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val personId2 = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000002"))

  /**
   * FcmService layer without Firebase -- passes None so push sends log instead of calling FCM.
   */
  val testFcmServiceLayer: ZLayer[FcmTokenRepository, Nothing, FcmService] = ZLayer {
    for tokenRepo <- ZIO.service[FcmTokenRepository]
    yield FcmService.FcmServiceImpl(tokenRepo, None)
  }

  /**
   * Shared layers: single InMemoryFcmTokenRepository feeds both FcmService and direct repo access.
   */
  val sharedLayers: ZLayer[Any, Nothing, FcmTokenRepository & FcmService] =
    InMemoryFcmTokenRepository.layer >+> testFcmServiceLayer

  def spec =
    suite("FcmService")(
      suite("registerToken")(
        test("registers token for user") {
          for {
            service   <- ZIO.service[FcmService]
            _         <- service.registerToken(personId1, "token-abc-123", "android")
            tokenRepo <- ZIO.service[FcmTokenRepository]
            tokens    <- tokenRepo.findByPersonId(personId1)
          } yield assertTrue(
            tokens.size == 1 &&
              tokens.head.token == "token-abc-123" &&
              tokens.head.platform == "android"
          )
        }.provide(sharedLayers),
        test("registers multiple tokens for same user") {
          for {
            service   <- ZIO.service[FcmService]
            _         <- service.registerToken(personId1, "token-1", "android")
            _         <- service.registerToken(personId1, "token-2", "ios")
            tokenRepo <- ZIO.service[FcmTokenRepository]
            tokens    <- tokenRepo.findByPersonId(personId1)
          } yield assertTrue(tokens.size == 2)
        }.provide(sharedLayers)
      ),
      suite("unregisterToken")(
        test("removes token") {
          for {
            service   <- ZIO.service[FcmService]
            _         <- service.registerToken(personId1, "token-to-remove", "android")
            _         <- service.unregisterToken("token-to-remove")
            tokenRepo <- ZIO.service[FcmTokenRepository]
            tokens    <- tokenRepo.findByPersonId(personId1)
          } yield assertTrue(tokens.isEmpty)
        }.provide(sharedLayers),
        test("unregisterToken for nonexistent token is a no-op and does not fail") {
          for {
            service <- ZIO.service[FcmService]
            exit    <- service.unregisterToken("does-not-exist").exit
          } yield assertTrue(exit.isSuccess)
        }.provide(sharedLayers),
        test("re-registering same token string with a different platform overwrites (key-on-token, exactly 1 record)") {
          // InMemoryFcmTokenRepository keys on token string (ConcurrentHashMap key = token).
          // Saving the same token twice with different platforms must result in exactly 1 record
          // with the last platform — confirming the upsert-by-token semantic.
          for {
            service   <- ZIO.service[FcmService]
            _         <- service.registerToken(personId1, "shared-token", "android")
            _         <- service.registerToken(personId1, "shared-token", "ios")
            tokenRepo <- ZIO.service[FcmTokenRepository]
            tokens    <- tokenRepo.findByPersonId(personId1)
          } yield assertTrue(tokens.size == 1 && tokens.head.platform == "ios")
        }.provide(sharedLayers)
      ),
      suite("sendToUser")(
        test("succeeds without Firebase and emits FCM-skipped log for the registered token") {
          // messagingOpt = None → sendToToken falls into the None branch and calls
          // ZIO.logInfo("FCM not configured, skipping push: <title>") for every token.
          // ZTestLogger captures that log so we can assert the code path was taken.
          for {
            service <- ZIO.service[FcmService]
            _       <- service.registerToken(personId1, "test-token", "android")
            _       <- service.sendToUser(personId1, PushNotification("Title", "Body"))
            logs    <- ZTestLogger.logOutput
          } yield assertTrue(
            logs.exists(e =>
              e.logLevel == zio.LogLevel.Info && e.message().contains("FCM not configured, skipping push")
            )
          )
        }.provide(sharedLayers),
        test("sendToUser with no tokens is a no-op (no FCM log emitted)") {
          // personId2 has no registered tokens → foreachDiscard over Nil → nothing happens.
          // No "FCM not configured" log should appear — the token-iteration body is never entered.
          for {
            service <- ZIO.service[FcmService]
            _       <- service.sendToUser(personId2, PushNotification("Title", "Body"))
            logs    <- ZTestLogger.logOutput
          } yield assertTrue(
            !logs.exists(_.message().contains("FCM not configured, skipping push"))
          )
        }.provide(sharedLayers)
      )
    )
}
