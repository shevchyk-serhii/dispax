package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CalendarShareInviteId, CompanyId, PersonId}
import com.shevchyk.schedule.domain.{CalendarShareInvite, CalendarShareError}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresCalendarShareInviteRepository(xa: Transactor[Task]) extends CalendarShareInviteRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val inviteRead: Read[CalendarShareInvite] =
    Read[(UUID, String, UUID, UUID, Instant, Instant, Option[Instant])].map {
      case (id, token, grantorPersonId, grantorCompanyId, createdAt, expiresAt, revokedAt) =>
        CalendarShareInvite(
          id = CalendarShareInviteId(id),
          token = token,
          grantorPersonId = PersonId(grantorPersonId),
          grantorCompanyId = CompanyId(grantorCompanyId),
          createdAt = createdAt,
          expiresAt = expiresAt,
          revokedAt = revokedAt
        )
    }

  private val columns = fr"id, token, grantor_person_id, grantor_company_id, created_at, expires_at, revoked_at"

  override def create(invite: CalendarShareInvite): Task[CalendarShareInvite] =
    sql"""
      INSERT INTO calendar_share_invites
        (id, token, grantor_person_id, grantor_company_id, created_at, expires_at, revoked_at)
      VALUES (
        ${invite.id.value}, ${invite.token}, ${invite.grantorPersonId.value}, ${invite.grantorCompanyId.value},
        ${invite.createdAt}, ${invite.expiresAt}, ${invite.revokedAt}
      )
    """.update.run
      .transact(xa)
      .mapBoth(ex => CalendarShareError.DatabaseError(ex), _ => invite)

  override def findByToken(token: String): Task[Option[CalendarShareInvite]] =
    (fr"SELECT" ++ columns ++ fr"FROM calendar_share_invites WHERE token = $token")
      .query[CalendarShareInvite]
      .option
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def findActiveByGrantor(grantorPersonId: PersonId, now: Instant): Task[List[CalendarShareInvite]] =
    (fr"SELECT" ++ columns ++
      fr"""FROM calendar_share_invites
           WHERE grantor_person_id = ${grantorPersonId.value}
             AND revoked_at IS NULL
             AND expires_at > $now
           ORDER BY created_at DESC
        """)
      .query[CalendarShareInvite]
      .to[List]
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def revoke(id: CalendarShareInviteId, grantorPersonId: PersonId, now: Instant): Task[Boolean] =
    sql"""
      UPDATE calendar_share_invites
      SET revoked_at = $now
      WHERE id = ${id.value} AND grantor_person_id = ${grantorPersonId.value} AND revoked_at IS NULL
    """.update.run
      .transact(xa)
      .mapBoth(ex => CalendarShareError.DatabaseError(ex), _ == 1)

object PostgresCalendarShareInviteRepository:

  val layer: ZLayer[Transactor[Task], Nothing, CalendarShareInviteRepository] = ZLayer.fromFunction(
    PostgresCalendarShareInviteRepository.apply
  )
