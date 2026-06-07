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
        }.provide(sharedLayers)
      ),
      suite("sendToUser")(
        test("succeeds without Firebase (logs instead)") {
          for {
            service <- ZIO.service[FcmService]
            _       <- service.registerToken(personId1, "test-token", "android")
            _       <- service.sendToUser(personId1, PushNotification("Title", "Body"))
          } yield assertTrue(true)
        }.provide(sharedLayers),
        test("succeeds when user has no tokens") {
          for {
            service <- ZIO.service[FcmService]
            _       <- service.sendToUser(personId2, PushNotification("Title", "Body"))
          } yield assertTrue(true)
        }.provide(sharedLayers)
      )
    )
}
