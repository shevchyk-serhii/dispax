package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.Instant

object SessionRepositorySpec extends ZIOSpecDefault {

  val userId1 = PersonId.generate()
  val userId2 = PersonId.generate()

  def makeSession(
      userId: PersonId = userId1,
      token: String = java.util.UUID.randomUUID().toString,
      isActive: Boolean = true
  ): Session = Session(
    id = SessionId.generate(),
    userId = userId,
    token = token,
    deviceInfo = Some("test-device"),
    ipAddress = Some("127.0.0.1"),
    createdAt = Instant.now(),
    lastActiveAt = Instant.now(),
    isActive = isActive
  )

  val layers = SessionRepository.inMemory

  def spec =
    suite("SessionRepository")(
      suite("create and findByUserId")(
        test("creates session and finds by user ID") {
          val session = makeSession()
          for {
            repo    <- ZIO.service[SessionRepository]
            created <- repo.create(session)
            found   <- repo.findByUserId(userId1)
          } yield assertTrue(
            created.id == session.id &&
              found.size == 1 &&
              found.head.id == session.id &&
              found.head.userId == userId1
          )
        }.provide(layers),
        test("returns empty for unknown user") {
          val session = makeSession(userId = userId1)
          for {
            repo  <- ZIO.service[SessionRepository]
            _     <- repo.create(session)
            found <- repo.findByUserId(userId2)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("deactivate")(
        test("deactivates an active session") {
          val session = makeSession()
          for {
            repo   <- ZIO.service[SessionRepository]
            _      <- repo.create(session)
            result <- repo.deactivate(session.id)
            found  <- repo.findByUserId(userId1)
          } yield assertTrue(result && found.isEmpty)
        }.provide(layers),
        test("returns false for unknown session ID") {
          for {
            repo   <- ZIO.service[SessionRepository]
            result <- repo.deactivate(SessionId.generate())
          } yield assertTrue(!result)
        }.provide(layers)
      ),
      suite("deactivateAllForUser")(
        test("deactivates all sessions for a user") {
          val s1 = makeSession(userId = userId1)
          val s2 = makeSession(userId = userId1)
          val s3 = makeSession(userId = userId2)
          for {
            repo  <- ZIO.service[SessionRepository]
            _     <- repo.create(s1)
            _     <- repo.create(s2)
            _     <- repo.create(s3)
            count <- repo.deactivateAllForUser(userId1)
            user1 <- repo.findByUserId(userId1)
            user2 <- repo.findByUserId(userId2)
          } yield assertTrue(
            count == 2 &&
              user1.isEmpty &&
              user2.size == 1
          )
        }.provide(layers)
      ),
      suite("deactivateAllExcept")(
        test("deactivates all sessions except the current one") {
          val s1 = makeSession(userId = userId1)
          val s2 = makeSession(userId = userId1)
          val s3 = makeSession(userId = userId1)
          for {
            repo  <- ZIO.service[SessionRepository]
            _     <- repo.create(s1)
            _     <- repo.create(s2)
            _     <- repo.create(s3)
            count <- repo.deactivateAllExcept(userId1, s2.id)
            found <- repo.findByUserId(userId1)
          } yield assertTrue(
            count == 2 &&
              found.size == 1 &&
              found.head.id == s2.id
          )
        }.provide(layers)
      )
    )
}
