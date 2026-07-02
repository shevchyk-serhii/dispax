package com.shevchyk.schedule.repository

import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.domain.{CalendarShareGrantId, PersonId}
import com.shevchyk.schedule.domain.CalendarShareGrant
import doobie.Transactor
import zio.*

import java.time.Instant

trait CalendarShareGrantRepository:

  /**
   * Insert a new grant. May fail with a unique-constraint violation when an active grant for the same (grantor,
   * grantee) pair already exists — callers absorb that race by re-reading via `findActivePair`.
   */
  def create(grant: CalendarShareGrant): Task[CalendarShareGrant]

  def findById(id: CalendarShareGrantId): Task[Option[CalendarShareGrant]]
  def findActivePair(grantorPersonId: PersonId, granteePersonId: PersonId): Task[Option[CalendarShareGrant]]
  def findActiveByGrantor(grantorPersonId: PersonId): Task[List[CalendarShareGrant]]
  def findActiveByGrantee(granteePersonId: PersonId): Task[List[CalendarShareGrant]]
  def countActiveByGrantor(grantorPersonId: PersonId): Task[Int]

  /**
   * Party-scoped soft revoke: the row is only revoked when `partyPersonId` is its grantor OR its grantee (both sides
   * may sever the share). Returns `true` when exactly one active row was revoked; `false` otherwise — callers collapse
   * that to a 404.
   */
  def revoke(id: CalendarShareGrantId, partyPersonId: PersonId, now: Instant): Task[Boolean]

object CalendarShareGrantRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, CalendarShareGrantRepository] = ZLayer.fromFunction(
    PostgresCalendarShareGrantRepository.apply
  )

  val layer: ZLayer[Any, Throwable, CalendarShareGrantRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
