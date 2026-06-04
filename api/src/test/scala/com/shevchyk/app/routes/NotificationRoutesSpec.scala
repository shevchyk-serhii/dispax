package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import com.shevchyk.notification.repository.{NotificationRepository, InMemoryNotificationRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object NotificationRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val userId        = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val otherUserId   = UUID.fromString("00000000-0000-0000-0000-000000000002")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )) >>> JwtService.live

  private def generateToken(id: UUID = userId, role: PersonRole = PersonRole.Client): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(Person(
      id = PersonId(id),
      email = s"$id@test.com",
      name = "Test User",
      role = role,
      passwordHash = "hash",
      companyId = Some(CompanyId(taxiCompanyId)),
      status = UserStatus.ACTIVE
    )))

  private def runRequest(req: Request): ZIO[NotificationRepository & JwtService, Nothing, Response] =
    NotificationRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makeNotification(personId: UUID = userId, notifType: String = "ride_update", isRead: Boolean = false): AppNotification =
    AppNotification(
      id = AppNotificationId(UUID.randomUUID()),
      personId = PersonId(personId),
      companyId = CompanyId(taxiCompanyId),
      title = "Test",
      body = "Test notification",
      notificationType = notifType,
      isRead = isRead,
      createdAt = Instant.now()
    )

  private val layers =
    InMemoryNotificationRepository.layer ++
    testJwtLayer

  def spec = suite("NotificationRoutes")(

    suite("GET /api/notifications")(
      test("returns user's notifications") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          n1    <- repo.save(makeNotification())
          n2    <- repo.save(makeNotification())
          _     <- repo.save(makeNotification(personId = otherUserId))
          token <- generateToken()
          resp  <- runRequest(
                     Request.get(URL.decode("/api/notifications").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[AppNotification]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 2)
      },

      test("filters by type when type param provided") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          _     <- repo.save(makeNotification(notifType = "ride_update"))
          _     <- repo.save(makeNotification(notifType = "chat_message"))
          token <- generateToken()
          resp  <- runRequest(
                     Request.get(URL.decode("/api/notifications?type=ride_update").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[AppNotification]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.forall(_.notificationType == "ride_update"))
      },

      test("returns 401 without token") {
        for {
          resp <- runRequest(Request.get(URL.decode("/api/notifications").toOption.get))
        } yield assertTrue(resp.status == Status.Unauthorized)
      }
    ),

    suite("GET /api/notifications/unread-count")(
      test("returns correct unread count") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          _     <- repo.save(makeNotification(isRead = false))
          _     <- repo.save(makeNotification(isRead = false))
          _     <- repo.save(makeNotification(isRead = true))
          token <- generateToken()
          resp  <- runRequest(
                     Request.get(URL.decode("/api/notifications/unread-count").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          bodyStr <- resp.body.asString.orDie
          result  <- ZIO.fromEither(bodyStr.fromJson[UnreadCountResponse]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, result.count == 2)
      }
    ),

    suite("PUT /api/notifications/:id/read")(
      test("marks notification as read") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          notif <- repo.save(makeNotification(isRead = false))
          token <- generateToken()
          resp  <- runRequest(
                     Request.put(
                       URL.decode(s"/api/notifications/${notif.id.value}/read").toOption.get,
                       Body.empty
                     ).addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status == Status.NoContent)
      },

      test("returns 404 for unknown notification") {
        for {
          token <- generateToken()
          resp  <- runRequest(
                     Request.put(
                       URL.decode(s"/api/notifications/${UUID.randomUUID()}/read").toOption.get,
                       Body.empty
                     ).addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status == Status.NotFound)
      }
    ),

    suite("PUT /api/notifications/read-all")(
      test("marks all notifications as read") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          _     <- repo.save(makeNotification(isRead = false))
          _     <- repo.save(makeNotification(isRead = false))
          token <- generateToken()
          resp  <- runRequest(
                     Request.put(URL.decode("/api/notifications/read-all").toOption.get, Body.empty)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          count <- repo.countUnread(PersonId(userId))
        } yield assertTrue(resp.status == Status.NoContent, count == 0)
      }
    ),

    suite("DELETE /api/notifications/:id")(
      test("deletes a notification") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          notif <- repo.save(makeNotification())
          token <- generateToken()
          resp  <- runRequest(
                     Request.delete(URL.decode(s"/api/notifications/${notif.id.value}").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          list  <- repo.findByPersonId(PersonId(userId), 100, 0)
        } yield assertTrue(resp.status == Status.NoContent, list.isEmpty)
      }
    ),

    suite("DELETE /api/notifications")(
      test("deletes all notifications for user") {
        for {
          repo  <- ZIO.service[NotificationRepository]
          _     <- repo.save(makeNotification())
          _     <- repo.save(makeNotification())
          _     <- repo.save(makeNotification(personId = otherUserId))
          token <- generateToken()
          resp  <- runRequest(
                     Request.delete(URL.decode("/api/notifications").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          userList  <- repo.findByPersonId(PersonId(userId), 100, 0)
          otherList <- repo.findByPersonId(PersonId(otherUserId), 100, 0)
        } yield assertTrue(
          resp.status == Status.NoContent,
          userList.isEmpty,
          otherList.length == 1
        )
      }
    )

  ).provide(layers) @@ TestAspect.sequential
}
