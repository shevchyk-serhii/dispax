package com.shevchyk.schedule.repository

import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.domain.{CalendarShareInviteId, PersonId}
import com.shevchyk.schedule.domain.CalendarShareInvite
import doobie.Transactor
import zio.*

import java.time.Instant

trait CalendarShareInviteRepository:
  def create(invite: CalendarShareInvite): Task[CalendarShareInvite]
  def findByToken(token: String): Task[Option[CalendarShareInvite]]
  def findActiveByGrantor(grantorPersonId: PersonId, now: Instant): Task[List[CalendarShareInvite]]

  /**
   * Grantor-scoped soft revoke. Returns `true` when exactly one active row was revoked; `false` when the invite does
   * not exist, belongs to someone else, or is already revoked — callers collapse all of those to a 404.
   */
  def revoke(id: CalendarShareInviteId, grantorPersonId: PersonId, now: Instant): Task[Boolean]

object CalendarShareInviteRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, CalendarShareInviteRepository] = ZLayer.fromFunction(
    PostgresCalendarShareInviteRepository.apply
  )

  val layer: ZLayer[Any, Throwable, CalendarShareInviteRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
