package com.shevchyk.notification.application

import com.google.auth.oauth2.GoogleCredentials
import com.google.firebase.{FirebaseApp, FirebaseOptions}
import com.google.firebase.messaging.{FirebaseMessaging, Message, Notification}
import com.shevchyk.core.domain.PersonId
import com.shevchyk.notification.domain.{FcmToken, PushNotification}
import com.shevchyk.notification.repository.FcmTokenRepository
import zio.*
import java.time.Instant

trait FcmService:
  def registerToken(personId: PersonId, token: String, platform: String): Task[Unit]
  def unregisterToken(token: String): Task[Unit]
  def sendToUser(personId: PersonId, notification: PushNotification): Task[Unit]

object FcmService:

  final case class FcmServiceImpl(
      tokenRepo: FcmTokenRepository,
      messagingOpt: Option[FirebaseMessaging]
  ) extends FcmService:

    def registerToken(personId: PersonId, token: String, platform: String): Task[Unit] = tokenRepo.save(
      FcmToken(personId, token, platform, Instant.now())
    )

    def unregisterToken(token: String): Task[Unit] = tokenRepo.deleteByToken(token)

    def sendToUser(personId: PersonId, notification: PushNotification): Task[Unit] =
      for
        tokens <- tokenRepo.findByPersonId(personId)
        _      <- ZIO.foreachDiscard(tokens)(t => sendToToken(t.token, notification))
      yield ()

    private def sendToToken(token: String, notification: PushNotification): Task[Unit] =
      messagingOpt match
        case Some(messaging) =>
          ZIO
            .attemptBlocking {
              val message = Message
                .builder()
                .setToken(token)
                .setNotification(
                  Notification
                    .builder()
                    .setTitle(notification.title)
                    .setBody(notification.body)
                    .build()
                )
                .putAllData(
                  java.util.Map.copyOf(
                    scala.jdk.CollectionConverters.MapHasAsJava(notification.data).asJava
                  )
                )
                .build()
              messaging.send(message)
            }
            .tapError(e => ZIO.logWarning(s"FCM send failed for token $token: ${e.getMessage}"))
            .ignore
        case None            => ZIO.logInfo(s"FCM not configured, skipping push: ${notification.title}")

  val layer: ZLayer[FcmTokenRepository, Nothing, FcmService] = ZLayer {
    for
      tokenRepo <- ZIO.service[FcmTokenRepository]
      messaging <- ZIO
                     .attempt {
                       if (FirebaseApp.getApps.isEmpty) {
                         val options = FirebaseOptions
                           .builder()
                           .setCredentials(GoogleCredentials.getApplicationDefault())
                           .build()
                         val _       = FirebaseApp.initializeApp(options)
                       }
                       Some(FirebaseMessaging.getInstance())
                     }
                     .catchAll { e =>
                       ZIO
                         .logWarning(s"Firebase not configured: ${e.getMessage}. Push notifications disabled.")
                         .as(None)
                     }
    yield FcmServiceImpl(tokenRepo, messaging)
  }
