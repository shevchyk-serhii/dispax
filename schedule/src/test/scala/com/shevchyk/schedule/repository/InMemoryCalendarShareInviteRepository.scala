package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CalendarShareInviteId, PersonId}
import com.shevchyk.schedule.domain.CalendarShareInvite
import zio.*

import java.time.Instant

final class InMemoryCalendarShareInviteRepository(
    store: Ref.Synchronized[Map[CalendarShareInviteId, CalendarShareInvite]]
) extends CalendarShareInviteRepository:

  override def create(invite: CalendarShareInvite): Task[CalendarShareInvite] = store
    .update(_.updated(invite.id, invite))
    .as(invite)

  override def findByToken(token: String): Task[Option[CalendarShareInvite]] = store.get.map(
    _.values.find(_.token == token)
  )

  override def findActiveByGrantor(grantorPersonId: PersonId, now: Instant): Task[List[CalendarShareInvite]] = store.get
    .map(
      _.values
        .filter(i => i.grantorPersonId == grantorPersonId && i.isActive(now))
        .toList
        .sortBy(_.createdAt)
        .reverse
    )

  override def revoke(id: CalendarShareInviteId, grantorPersonId: PersonId, now: Instant): Task[Boolean] = store
    .modify { invites =>
      invites.get(id).filter(i => i.grantorPersonId == grantorPersonId && i.revokedAt.isEmpty) match
        case Some(invite) => (true, invites.updated(id, invite.copy(revokedAt = Some(now))))
        case None         => (false, invites)
    }

object InMemoryCalendarShareInviteRepository:

  val layer: ZLayer[Any, Nothing, CalendarShareInviteRepository] = ZLayer.fromZIO(
    Ref.Synchronized
      .make(Map.empty[CalendarShareInviteId, CalendarShareInvite])
      .map(InMemoryCalendarShareInviteRepository(_))
  )
