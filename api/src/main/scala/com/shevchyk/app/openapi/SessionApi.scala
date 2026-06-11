package com.shevchyk.app.openapi

import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.SessionRepository
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the session endpoints. Replaces the hand-written zio-http handlers in
 * `SessionRoutes`. The Authorization header is consumed by the secure base for auth, and re-read as an explicit input
 * where the original handler needed the raw token to detect the "current" session.
 */
object SessionApi:

  import AppSecure.*

  private val sessionTag = "Session"

  given Schema[SessionDto] = Schema.derived

  type SessionEnv = JwtService & SessionRepository & TokenRepository

  // Raw Authorization header input (in addition to the bearer security input) so the logic can
  // detect the current session token exactly like the original handler did.
  private val authHeader = header[Option[String]]("Authorization")

  private def currentTokenOf(h: Option[String]): Option[String] =
    h.map(_.stripPrefix("Bearer "))

  // -- Endpoint descriptions ------------------------------------------------

  val listSessionsEndpoint =
    secureEndpoint.get
      .in("api" / "sessions")
      .in(authHeader)
      .out(jsonBody[List[SessionDto]])
      .tag(sessionTag)
      .summary("List active sessions for the current user")

  val revokeSessionEndpoint =
    secureEndpoint.delete
      .in("api" / "sessions" / path[String]("id"))
      .out(statusCode(StatusCode.NoContent))
      .tag(sessionTag)
      .summary("Revoke a specific session")

  val revokeAllSessionsEndpoint =
    secureEndpoint.delete
      .in("api" / "sessions")
      .in(authHeader)
      .out(stringBody.map(s => s)(s => s))
      .tag(sessionTag)
      .summary("Revoke all sessions except the current one")

  val createSessionEndpoint =
    secureEndpoint.post
      .in("api" / "sessions")
      .in(authHeader)
      .in(stringBody)
      .out(statusCode(StatusCode.Created).and(jsonBody[SessionDto]))
      .tag(sessionTag)
      .summary("Register a new session (called on login)")

  val endpoints = List(
    listSessionsEndpoint,
    revokeSessionEndpoint,
    revokeAllSessionsEndpoint,
    createSessionEndpoint
  )

  // -- Server logic ---------------------------------------------------------

  private val listSessionsServer: ZServerEndpoint[SessionEnv, Any] =
    listSessionsEndpoint.serverLogic[SessionEnv] { user => authHdr =>
      (for {
        repo        <- ZIO.service[SessionRepository]
        sessions    <- repo.findByUserId(PersonId(user.userId)).mapError(internal)
        currentToken = currentTokenOf(authHdr)
        dtos         = sessions.map { s =>
                         SessionDto(
                           id = s.id.value,
                           deviceInfo = s.deviceInfo,
                           ipAddress = s.ipAddress,
                           createdAt = s.createdAt.toString,
                           lastActiveAt = s.lastActiveAt.toString,
                           isActive = s.isActive,
                           isCurrent = currentToken.contains(s.token)
                         )
                       }
      } yield dtos)
    }

  private val revokeSessionServer: ZServerEndpoint[SessionEnv, Any] =
    revokeSessionEndpoint.serverLogic[SessionEnv] { user => id =>
      (for {
        repo      <- ZIO.service[SessionRepository]
        sessionId <- parseUuid(id).map(SessionId(_))
        sessions  <- repo.findByUserId(PersonId(user.userId)).mapError(internal)
        session   <- ZIO
                       .fromOption(sessions.find(_.id == sessionId))
                       .orElseFail(internal(new RuntimeException("Session not found")))
        tokenRepo <- ZIO.service[TokenRepository]
        _         <- tokenRepo.deleteByToken(session.token).mapError(internal)
        _         <- repo.deactivate(sessionId).mapError(internal)
      } yield ()).unit
    }

  private val revokeAllSessionsServer: ZServerEndpoint[SessionEnv, Any] =
    revokeAllSessionsEndpoint.serverLogic[SessionEnv] { user => authHdr =>
      (for {
        repo        <- ZIO.service[SessionRepository]
        currentToken = currentTokenOf(authHdr)
        currentSess <- currentToken match
                         case Some(t) => repo.findByToken(t).mapError(internal)
                         case None    => ZIO.succeed(None)
        count       <- currentSess match
                         case Some(s) => repo.deactivateAllExcept(PersonId(user.userId), s.id).mapError(internal)
                         case None    => repo.deactivateAllForUser(PersonId(user.userId)).mapError(internal)
      } yield s"""{"revokedCount":$count}""")
    }

  private val createSessionServer: ZServerEndpoint[SessionEnv, Any] =
    createSessionEndpoint.serverLogic[SessionEnv] { user =>
      { case (authHdr, bodyStr) =>
        (for {
          info    <- ZIO.succeed(bodyStr.fromJson[Map[String, String]].getOrElse(Map.empty))
          repo    <- ZIO.service[SessionRepository]
          token    = currentTokenOf(authHdr).getOrElse("")
          session  = Session(
                       id = SessionId.generate(),
                       userId = PersonId(user.userId),
                       token = token,
                       deviceInfo = info.get("deviceInfo"),
                       ipAddress = info.get("ipAddress"),
                       createdAt = Instant.now(),
                       lastActiveAt = Instant.now()
                     )
          created <- repo.create(session).mapError(internal)
        } yield SessionDto(
          id = created.id.value,
          deviceInfo = created.deviceInfo,
          ipAddress = created.ipAddress,
          createdAt = created.createdAt.toString,
          lastActiveAt = created.lastActiveAt.toString,
          isActive = created.isActive,
          isCurrent = true
        ))
      }
    }

  val serverEndpoints: List[ZServerEndpoint[SessionEnv, Any]] = List(
    listSessionsServer,
    revokeSessionServer,
    revokeAllSessionsServer,
    createSessionServer
  )
