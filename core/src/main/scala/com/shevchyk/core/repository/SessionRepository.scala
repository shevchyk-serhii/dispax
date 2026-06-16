package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import java.time.Instant
import java.util.UUID

trait SessionRepository:
  def create(session: Session): Task[Session]
  def findByUserId(userId: PersonId): Task[List[Session]]
  def findByToken(token: String): Task[Option[Session]]
  def updateLastActive(sessionId: SessionId): Task[Unit]
  def deactivate(sessionId: SessionId): Task[Boolean]
  def deactivateAllForUser(userId: PersonId): Task[Int]
  def deactivateAllExcept(userId: PersonId, currentSessionId: SessionId): Task[Int]

  // ---------------------------------------------------------------------------
  // Platform-level (cross-tenant) analytics — SuperAdmin only.
  // ---------------------------------------------------------------------------

  /**
   * Count of all active sessions across ALL companies. No company_id filter.
   */
  def countActivePlatform(): Task[Int]

  /**
   * Count of active sessions for users belonging to a specific company. Requires a JOIN to `persons` because `sessions`
   * has no company_id column.
   */
  def countActiveByCompany(companyId: CompanyId): Task[Int]

object SessionRepository:

  val inMemory: ZLayer[Any, Nothing, SessionRepository] = ZLayer.succeed(InMemorySessionRepository())

  val layer: ZLayer[Any, Throwable, SessionRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresSessionRepository.postgresLayer

class InMemorySessionRepository extends SessionRepository:
  private var sessions: List[Session] = List.empty

  override def create(session: Session): Task[Session] = ZIO.succeed {
    sessions = sessions :+ session
    session
  }

  override def findByUserId(userId: PersonId): Task[List[Session]] = ZIO.succeed {
    sessions.filter(s => s.userId == userId && s.isActive).sortBy(_.lastActiveAt).reverse
  }

  override def findByToken(token: String): Task[Option[Session]] = ZIO.succeed {
    sessions.find(s => s.token == token && s.isActive)
  }

  override def updateLastActive(sessionId: SessionId): Task[Unit] = ZIO.succeed {
    val idx = sessions.indexWhere(_.id == sessionId)
    if idx >= 0 then sessions = sessions.updated(idx, sessions(idx).copy(lastActiveAt = Instant.now()))
  }

  override def deactivate(sessionId: SessionId): Task[Boolean] = ZIO.succeed {
    val idx = sessions.indexWhere(s => s.id == sessionId && s.isActive)
    if idx >= 0 then
      sessions = sessions.updated(idx, sessions(idx).copy(isActive = false))
      true
    else false
  }

  override def deactivateAllForUser(userId: PersonId): Task[Int] = ZIO.succeed {
    val count = sessions.count(s => s.userId == userId && s.isActive)
    sessions = sessions.map(s => if s.userId == userId && s.isActive then s.copy(isActive = false) else s)
    count
  }

  override def deactivateAllExcept(userId: PersonId, currentSessionId: SessionId): Task[Int] = ZIO.succeed {
    val count = sessions.count(s => s.userId == userId && s.isActive && s.id != currentSessionId)
    sessions = sessions.map(s =>
      if s.userId == userId && s.isActive && s.id != currentSessionId then s.copy(isActive = false) else s
    )
    count
  }

  override def countActivePlatform(): Task[Int] = ZIO.succeed {
    sessions.count(_.isActive)
  }

  // The in-memory implementation cannot perform the JOIN to persons,
  // so it always returns 0. Integration tests should use the Postgres implementation.
  override def countActiveByCompany(companyId: CompanyId): Task[Int] = ZIO.succeed(0)
