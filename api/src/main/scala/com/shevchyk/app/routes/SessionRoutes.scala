package com.shevchyk.app.routes

import com.shevchyk.auth.service.JwtService
import com.shevchyk.auth.repository.TokenRepository
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.SessionRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object SessionRoutes:

  val authenticatedRoutes: Routes[SessionRepository & TokenRepository & JwtService, Response] = Routes(
    // GET /api/sessions — list active sessions for current user
    Method.GET / "api" / "sessions" -> RouteHelpers.authHandler("Session") { (user, request) =>
      for {
        repo        <- ZIO.service[SessionRepository]
        sessions    <- repo.findByUserId(PersonId(user.userId))
        currentToken = request.header(Header.Authorization).map(_.renderedValue.stripPrefix("Bearer "))
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
      } yield Response.json(dtos.toJson)
    },

    // DELETE /api/sessions/{id} — revoke a specific session
    Method.DELETE / "api" / "sessions" / string("id") -> RouteHelpers.authPathHandler("Session") {
      (user, id: String, _) =>
        for {
          repo      <- ZIO.service[SessionRepository]
          sessionId <- UuidParser.parse(id).map(SessionId(_))
          sessions  <- repo.findByUserId(PersonId(user.userId))
          session   <- ZIO
                         .fromOption(sessions.find(_.id == sessionId))
                         .orElseFail(new RuntimeException("Session not found"))
          tokenRepo <- ZIO.service[TokenRepository]
          _         <- tokenRepo.deleteByToken(session.token)
          _         <- repo.deactivate(sessionId)
        } yield Response.status(Status.NoContent)
    },

    // DELETE /api/sessions — revoke all sessions except current
    Method.DELETE / "api" / "sessions" -> RouteHelpers.authHandler("Session") { (user, request) =>
      for {
        repo        <- ZIO.service[SessionRepository]
        currentToken = request.header(Header.Authorization).map(_.renderedValue.stripPrefix("Bearer "))
        currentSess <-
          currentToken match
            case Some(t) => repo.findByToken(t)
            case None    => ZIO.succeed(None)
        count       <-
          currentSess match
            case Some(s) => repo.deactivateAllExcept(PersonId(user.userId), s.id)
            case None    => repo.deactivateAllForUser(PersonId(user.userId))
      } yield Response.json(s"""{"revokedCount":$count}""")
    },

    // POST /api/sessions — register a new session (called on login)
    Method.POST / "api" / "sessions" -> RouteHelpers.authHandler("Session") { (user, request) =>
      for {
        bodyStr <- request.body.asString
        info     = bodyStr.fromJson[Map[String, String]].getOrElse(Map.empty)
        repo    <- ZIO.service[SessionRepository]
        token    = request.header(Header.Authorization).map(_.renderedValue.stripPrefix("Bearer ")).getOrElse("")
        session  = Session(
                     id = SessionId.generate(),
                     userId = PersonId(user.userId),
                     token = token,
                     deviceInfo = info.get("deviceInfo"),
                     ipAddress = info.get("ipAddress"),
                     createdAt = Instant.now(),
                     lastActiveAt = Instant.now()
                   )
        created <- repo.create(session)
      } yield Response(
        Status.Created,
        body = Body.fromString(
          SessionDto(
            id = created.id.value,
            deviceInfo = created.deviceInfo,
            ipAddress = created.ipAddress,
            createdAt = created.createdAt.toString,
            lastActiveAt = created.lastActiveAt.toString,
            isActive = created.isActive,
            isCurrent = true
          ).toJson
        )
      )
    }
  )
