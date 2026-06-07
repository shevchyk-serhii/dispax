package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.AuditService
import com.shevchyk.core.domain.*
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId, UnreadCountResponse}
import com.shevchyk.notification.repository.{InMemoryNotificationRepository, NotificationRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object RouteIntegrationSpec extends ZIOSpecDefault {

  // ---------------------------------------------------------------------------
  // Shared test constants
  // ---------------------------------------------------------------------------

  private val testUserId    = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val testCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")

  // ---------------------------------------------------------------------------
  // JWT helper (same pattern as ride module's TestJWT)
  // ---------------------------------------------------------------------------

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private def generateToken(
      userId: UUID,
      email: String = "test@example.com",
      role: PersonRole = PersonRole.Client,
      companyId: Option[UUID] = None
  ): ZIO[JwtService, Throwable, String] = {
    val person = Person(
      id = PersonId(userId),
      email = email,
      name = "Test User",
      role = role,
      passwordHash = "test-hash",
      companyId = companyId.map(CompanyId.apply),
      status = UserStatus.ACTIVE
    )
    ZIO.serviceWithZIO[JwtService](_.generateToken(person))
  }

  // ---------------------------------------------------------------------------
  // Route runners (same pattern as StatsRoutesSpec / RideApiSpec)
  // ---------------------------------------------------------------------------

  private def runNotification(request: Request): ZIO[NotificationRepository & JwtService, Nothing, Response] =
    NotificationRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  private def runAudit(request: Request): ZIO[AuditService & JwtService, Nothing, Response] =
    AuditRoutes.authenticatedRoutes.run(request).either.map {
      case Left(either)    => either.merge
      case Right(response) => response
    }

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  private val notificationLayers: ZLayer[Any, Nothing, NotificationRepository & JwtService] =
    InMemoryNotificationRepository.layer ++ testJwtService

  private val auditLayers: ZLayer[Any, Nothing, AuditService & JwtService] = AuditService.inMemory ++ testJwtService

  // ---------------------------------------------------------------------------
  // Test data helpers
  // ---------------------------------------------------------------------------

  private def makeNotification(
      personId: UUID = testUserId,
      title: String = "Test Notification",
      body: String = "Test body",
      notificationType: String = "RIDE_UPDATE",
      isRead: Boolean = false
  ): AppNotification = AppNotification(
    id = AppNotificationId.generate(),
    personId = PersonId(personId),
    companyId = CompanyId(testCompanyId),
    title = title,
    body = body,
    notificationType = notificationType,
    isRead = isRead,
    createdAt = Instant.now()
  )

  private def makeAuditEntry(
      companyId: UUID = testCompanyId,
      action: AuditAction = AuditAction.RideCreated
  ): AuditLogEntry = AuditLogEntry(
    id = AuditLogId.generate(),
    companyId = CompanyId(companyId),
    actorId = PersonId(testUserId),
    action = action,
    entityType = "ride",
    entityId = UUID.randomUUID(),
    createdAt = Instant.now()
  )

  // ===========================================================================
  // Specs
  // ===========================================================================

  def spec =
    suite("RouteIntegrationSpec")(
      authEnforcementSuite,
      notificationRoutesSuite,
      auditRoutesSuite
    )

  // ---------------------------------------------------------------------------
  // 1. Auth enforcement tests
  // ---------------------------------------------------------------------------

  private val authEnforcementSuite =
    suite("Auth enforcement")(
      test("request without Authorization header returns 401") {
        val request = Request.get(URL.decode("/api/notifications").toOption.get)
        for {
          response <- runNotification(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Unauthorized,
          body.contains("Missing Authorization header")
        )
      }.provide(notificationLayers),
      test("request with invalid JWT returns 401") {
        val request = Request
          .get(URL.decode("/api/notifications").toOption.get)
          .addHeader(Header.Authorization.Bearer("invalid-token-value"))
        for {
          response <- runNotification(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Unauthorized,
          body.contains("Invalid or expired token") || body.contains("Authentication failed")
        )
      }.provide(notificationLayers),
      test("request with valid JWT but wrong role returns 403 on role-protected route") {
        for {
          token    <- generateToken(
                        userId = testUserId,
                        email = "client@example.com",
                        role = PersonRole.Client,
                        companyId = Some(testCompanyId)
                      )
          request   = Request
                        .get(URL.decode("/api/audit/recent").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runAudit(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Forbidden,
          body.contains("Insufficient permissions")
        )
      }.provide(auditLayers)
    )

  // ---------------------------------------------------------------------------
  // 2. NotificationRoutes tests
  // ---------------------------------------------------------------------------

  private val notificationRoutesSuite =
    suite("NotificationRoutes")(
      test("GET /api/notifications returns notifications for authenticated user") {
        for {
          repo <- ZIO.service[NotificationRepository]
          n1   <- repo.save(makeNotification(title = "Ride assigned"))
          n2   <- repo.save(makeNotification(title = "Ride completed"))
          _    <- repo.save(makeNotification(personId = UUID.randomUUID(), title = "Other user"))

          token <- generateToken(
                     userId = testUserId,
                     email = "client@example.com",
                     role = PersonRole.Client,
                     companyId = Some(testCompanyId)
                   )

          request   = Request
                        .get(URL.decode("/api/notifications").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runNotification(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Ok,
          body.contains("Ride assigned"),
          body.contains("Ride completed"),
          !body.contains("Other user")
        )
      }.provide(notificationLayers),
      test("GET /api/notifications/unread-count returns count") {
        for {
          repo <- ZIO.service[NotificationRepository]
          _    <- repo.save(makeNotification(isRead = false))
          _    <- repo.save(makeNotification(isRead = false))
          _    <- repo.save(makeNotification(isRead = true))

          token <- generateToken(
                     userId = testUserId,
                     email = "client@example.com",
                     role = PersonRole.Client,
                     companyId = Some(testCompanyId)
                   )

          request   = Request
                        .get(URL.decode("/api/notifications/unread-count").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runNotification(request)
          body     <- response.body.asString
          parsed   <- ZIO.fromEither(body.fromJson[UnreadCountResponse]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(
          response.status == Status.Ok,
          parsed.count == 2
        )
      }.provide(notificationLayers),
      test("PUT /api/notifications/{id}/read marks notification as read") {
        for {
          repo         <- ZIO.service[NotificationRepository]
          notification <- repo.save(makeNotification(isRead = false))

          token <- generateToken(
                     userId = testUserId,
                     email = "client@example.com",
                     role = PersonRole.Client,
                     companyId = Some(testCompanyId)
                   )

          notifId   = notification.id.value.toString
          request   = Request
                        .put(
                          URL.decode(s"/api/notifications/$notifId/read").toOption.get,
                          Body.empty
                        )
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runNotification(request)

          // Verify the notification is now read by checking unread count
          countReq   = Request
                         .get(URL.decode("/api/notifications/unread-count").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
          countResp <- runNotification(countReq)
          countBody <- countResp.body.asString
          parsed    <- ZIO.fromEither(countBody.fromJson[UnreadCountResponse]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(
          response.status == Status.NoContent,
          parsed.count == 0
        )
      }.provide(notificationLayers),
      test("DELETE /api/notifications deletes all notifications for user") {
        for {
          repo <- ZIO.service[NotificationRepository]
          _    <- repo.save(makeNotification(title = "To delete 1"))
          _    <- repo.save(makeNotification(title = "To delete 2"))

          token <- generateToken(
                     userId = testUserId,
                     email = "client@example.com",
                     role = PersonRole.Client,
                     companyId = Some(testCompanyId)
                   )

          deleteReq   = Request
                          .delete(URL.decode("/api/notifications").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
          deleteResp <- runNotification(deleteReq)

          // Verify all notifications are gone
          listReq   = Request
                        .get(URL.decode("/api/notifications").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          listResp <- runNotification(listReq)
          listBody <- listResp.body.asString
          parsed   <- ZIO.fromEither(listBody.fromJson[List[AppNotification]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(
          deleteResp.status == Status.NoContent,
          parsed.isEmpty
        )
      }.provide(notificationLayers)
    )

  // ---------------------------------------------------------------------------
  // 3. AuditRoutes tests
  // ---------------------------------------------------------------------------

  private val auditRoutesSuite =
    suite("AuditRoutes")(
      test("GET /api/audit/recent requires DISPATCHER role") {
        for {
          token    <- generateToken(
                        userId = testUserId,
                        email = "driver@example.com",
                        role = PersonRole.Driver,
                        companyId = Some(testCompanyId)
                      )
          request   = Request
                        .get(URL.decode("/api/audit/recent").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runAudit(request)
          body     <- response.body.asString
        } yield assertTrue(
          response.status == Status.Forbidden,
          body.contains("Insufficient permissions")
        )
      }.provide(auditLayers),
      test("GET /api/audit/recent returns audit entries for company") {
        for {
          service <- ZIO.service[AuditService]
          entry1  <- ZIO.succeed(makeAuditEntry(action = AuditAction.RideCreated))
          entry2  <- ZIO.succeed(makeAuditEntry(action = AuditAction.RideAssigned))
          _       <- service.log(entry1)
          _       <- service.log(entry2)
          // Entry for a different company -- should not appear
          _       <- service.log(makeAuditEntry(companyId = UUID.randomUUID()))

          token <- generateToken(
                     userId = testUserId,
                     email = "dispatcher@example.com",
                     role = PersonRole.Dispatcher,
                     companyId = Some(testCompanyId)
                   )

          request   = Request
                        .get(URL.decode("/api/audit/recent?limit=10").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
          response <- runAudit(request)
          body     <- response.body.asString
          parsed   <- ZIO.fromEither(body.fromJson[List[AuditLogEntry]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(
          response.status == Status.Ok,
          parsed.length == 2,
          parsed.forall(_.companyId == CompanyId(testCompanyId))
        )
      }.provide(auditLayers)
    )
}
