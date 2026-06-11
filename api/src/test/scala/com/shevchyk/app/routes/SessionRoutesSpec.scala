package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{SessionRepository, InMemorySessionRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.time.Instant
import java.util.UUID

class InMemoryTokenRepository extends TokenRepository:
  private var tokens: Map[String, UUID] = Map.empty

  def create(token: String, userId: UUID): Task[Unit]      = ZIO.succeed { tokens = tokens + (token -> userId) }
  def findUserIdByToken(token: String): Task[Option[UUID]] = ZIO.succeed(tokens.get(token))
  def deleteByToken(token: String): Task[Unit]             = ZIO.succeed { tokens = tokens - token }

  def deleteByUserId(userId: UUID): Task[Unit] = ZIO.succeed {
    tokens = tokens.filter { case (_, uid) => uid != userId }
  }

object SessionRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val userId        = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val otherUserId   = UUID.fromString("00000000-0000-0000-0000-000000000002")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
        issuer = "test-issuer",
        audience = "test-audience",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def generateToken(
      id: UUID = userId,
      role: PersonRole = PersonRole.Dispatcher
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(id),
        email = s"$id@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = Some(CompanyId(taxiCompanyId)),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(req: Request): ZIO[SessionRepository & TokenRepository & JwtService, Nothing, Response] =
    SessionRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makeSession(uid: UUID = userId, token: String = "some-token"): Session = Session(
    id = SessionId.generate(),
    userId = PersonId(uid),
    token = token,
    deviceInfo = Some("iPhone"),
    ipAddress = Some("127.0.0.1"),
    createdAt = Instant.now(),
    lastActiveAt = Instant.now()
  )

  private val layers =
    ZLayer.succeed(new InMemorySessionRepository) ++
      ZLayer.succeed(new InMemoryTokenRepository) ++
      testJwtLayer

  def spec =
    suite("SessionRoutes")(
      suite("GET /api/sessions")(
        test("returns user's active sessions with isCurrent flag") {
          for {
            repo    <- ZIO.service[SessionRepository]
            token   <- generateToken()
            session  = makeSession(uid = userId, token = token)
            _       <- repo.create(session)
            _       <- repo.create(makeSession(uid = otherUserId, token = "other-token"))
            resp    <- runRequest(
                         Request
                           .get(URL.decode("/api/sessions").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            list    <- ZIO.fromEither(bodyStr.fromJson[List[SessionDto]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            list.length == 1,
            list.head.isCurrent == true
          )
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/sessions").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("POST /api/sessions")(
        test("creates a new session") {
          for {
            token   <- generateToken()
            body     = """{"deviceInfo":"Android","ipAddress":"192.168.1.1"}"""
            request  = Request
                         .post(URL.decode("/api/sessions").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            dto     <- ZIO.fromEither(bodyStr.fromJson[SessionDto]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Created,
            dto.deviceInfo.contains("Android"),
            dto.isCurrent == true
          )
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(
                      Request.post(URL.decode("/api/sessions").toOption.get, Body.fromString("{}"))
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("DELETE /api/sessions/:id")(
        test("deletes specific session") {
          for {
            repo     <- ZIO.service[SessionRepository]
            token    <- generateToken()
            session   = makeSession(uid = userId, token = token)
            _        <- repo.create(session)
            resp     <- runRequest(
                          Request
                            .delete(URL.decode(s"/api/sessions/${session.id.value}").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            sessions <- repo.findByUserId(PersonId(userId))
          } yield assertTrue(resp.status == Status.NoContent, sessions.isEmpty)
        },
        test("returns error for session not belonging to user") {
          for {
            repo   <- ZIO.service[SessionRepository]
            token  <- generateToken()
            session = makeSession(uid = otherUserId, token = "other-token")
            _      <- repo.create(session)
            resp   <- runRequest(
                        Request
                          .delete(URL.decode(s"/api/sessions/${session.id.value}").toOption.get)
                          .addHeader(Header.Authorization.Bearer(token))
                      )
          } yield assertTrue(resp.status != Status.NoContent)
        }
      ),
      suite("DELETE /api/sessions")(
        test("revokes all other sessions except current") {
          for {
            repo     <- ZIO.service[SessionRepository]
            token    <- generateToken()
            current   = makeSession(uid = userId, token = token)
            other1    = makeSession(uid = userId, token = "old-token-1")
            other2    = makeSession(uid = userId, token = "old-token-2")
            _        <- repo.create(current)
            _        <- repo.create(other1)
            _        <- repo.create(other2)
            resp     <- runRequest(
                          Request
                            .delete(URL.decode("/api/sessions").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            bodyStr  <- resp.body.asString.orDie
            sessions <- repo.findByUserId(PersonId(userId))
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("revokedCount"),
            sessions.length == 1,
            sessions.head.token == token
          )
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
