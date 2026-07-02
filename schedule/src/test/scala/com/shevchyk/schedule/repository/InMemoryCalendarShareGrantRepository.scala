package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CalendarShareGrantId, PersonId}
import com.shevchyk.schedule.domain.CalendarShareGrant
import zio.*

import java.time.Instant

/**
 * In-memory double. Mirrors the partial unique index `uq_calendar_share_grants_active`: inserting a second ACTIVE grant
 * for the same (grantor, grantee) pair fails, exactly like Postgres.
 */
final class InMemoryCalendarShareGrantRepository(
    store: Ref.Synchronized[Map[CalendarShareGrantId, CalendarShareGrant]]
) extends CalendarShareGrantRepository:

  override def create(grant: CalendarShareGrant): Task[CalendarShareGrant] = store.modifyZIO { grants =>
    val duplicate = grants.values.exists(g =>
      g.grantorPersonId == grant.grantorPersonId &&
        g.granteePersonId == grant.granteePersonId &&
        g.revokedAt.isEmpty
    )
    if duplicate then
      ZIO.fail(new RuntimeException("duplicate key value violates unique constraint uq_calendar_share_grants_active"))
    else ZIO.succeed((grant, grants.updated(grant.id, grant)))
  }

  override def findById(id: CalendarShareGrantId): Task[Option[CalendarShareGrant]] = store.get.map(_.get(id))

  override def findActivePair(
      grantorPersonId: PersonId,
      granteePersonId: PersonId
  ): Task[Option[CalendarShareGrant]] = store.get.map(
    _.values.find(g =>
      g.grantorPersonId == grantorPersonId && g.granteePersonId == granteePersonId && g.revokedAt.isEmpty
    )
  )

  override def findActiveByGrantor(grantorPersonId: PersonId): Task[List[CalendarShareGrant]] = store.get.map(
    _.values.filter(g => g.grantorPersonId == grantorPersonId && g.revokedAt.isEmpty).toList.sortBy(_.createdAt).reverse
  )

  override def findActiveByGrantee(granteePersonId: PersonId): Task[List[CalendarShareGrant]] = store.get.map(
    _.values.filter(g => g.granteePersonId == granteePersonId && g.revokedAt.isEmpty).toList.sortBy(_.createdAt).reverse
  )

  override def countActiveByGrantor(grantorPersonId: PersonId): Task[Int] = store.get.map(
    _.values.count(g => g.grantorPersonId == grantorPersonId && g.revokedAt.isEmpty)
  )

  override def revoke(id: CalendarShareGrantId, partyPersonId: PersonId, now: Instant): Task[Boolean] = store.modify {
    grants =>
      grants
        .get(id)
        .filter(g =>
          (g.grantorPersonId == partyPersonId || g.granteePersonId == partyPersonId) && g.revokedAt.isEmpty
        ) match
        case Some(grant) => (true, grants.updated(id, grant.copy(revokedAt = Some(now))))
        case None        => (false, grants)
  }

object InMemoryCalendarShareGrantRepository:

  val layer: ZLayer[Any, Nothing, CalendarShareGrantRepository] = ZLayer.fromZIO(
    Ref.Synchronized
      .make(Map.empty[CalendarShareGrantId, CalendarShareGrant])
      .map(InMemoryCalendarShareGrantRepository(_))
  )
