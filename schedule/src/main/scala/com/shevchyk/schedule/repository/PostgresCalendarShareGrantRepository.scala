package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CalendarShareGrantId, CalendarShareInviteId, CompanyId, PersonId}
import com.shevchyk.schedule.domain.{CalendarShareError, CalendarShareGrant}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresCalendarShareGrantRepository(xa: Transactor[Task]) extends CalendarShareGrantRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val grantRead: Read[CalendarShareGrant] =
    Read[(UUID, Option[UUID], UUID, UUID, UUID, UUID, Instant, Option[Instant], Option[Instant])].map {
      case (id, inviteId, grantorPid, grantorCid, granteePid, granteeCid, createdAt, expiresAt, revokedAt) =>
        CalendarShareGrant(
          id = CalendarShareGrantId(id),
          inviteId = inviteId.map(CalendarShareInviteId.apply),
          grantorPersonId = PersonId(grantorPid),
          grantorCompanyId = CompanyId(grantorCid),
          granteePersonId = PersonId(granteePid),
          granteeCompanyId = CompanyId(granteeCid),
          createdAt = createdAt,
          expiresAt = expiresAt,
          revokedAt = revokedAt
        )
    }

  private val columns =
    fr"""id, invite_id, grantor_person_id, grantor_company_id, grantee_person_id, grantee_company_id,
         created_at, expires_at, revoked_at"""

  override def create(grant: CalendarShareGrant): Task[CalendarShareGrant] =
    sql"""
      INSERT INTO calendar_share_grants
        (id, invite_id, grantor_person_id, grantor_company_id, grantee_person_id, grantee_company_id,
         created_at, expires_at, revoked_at)
      VALUES (
        ${grant.id.value}, ${grant.inviteId.map(_.value)},
        ${grant.grantorPersonId.value}, ${grant.grantorCompanyId.value},
        ${grant.granteePersonId.value}, ${grant.granteeCompanyId.value},
        ${grant.createdAt}, ${grant.expiresAt}, ${grant.revokedAt}
      )
    """.update.run
      .transact(xa)
      .mapBoth(ex => CalendarShareError.DatabaseError(ex), _ => grant)

  override def findById(id: CalendarShareGrantId): Task[Option[CalendarShareGrant]] =
    (fr"SELECT" ++ columns ++ fr"FROM calendar_share_grants WHERE id = ${id.value}")
      .query[CalendarShareGrant]
      .option
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def findActivePair(
      grantorPersonId: PersonId,
      granteePersonId: PersonId
  ): Task[Option[CalendarShareGrant]] =
    (fr"SELECT" ++ columns ++
      fr"""FROM calendar_share_grants
           WHERE grantor_person_id = ${grantorPersonId.value}
             AND grantee_person_id = ${granteePersonId.value}
             AND revoked_at IS NULL
        """)
      .query[CalendarShareGrant]
      .option
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def findActiveByGrantor(grantorPersonId: PersonId): Task[List[CalendarShareGrant]] =
    (fr"SELECT" ++ columns ++
      fr"""FROM calendar_share_grants
           WHERE grantor_person_id = ${grantorPersonId.value} AND revoked_at IS NULL
           ORDER BY created_at DESC
        """)
      .query[CalendarShareGrant]
      .to[List]
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def findActiveByGrantee(granteePersonId: PersonId): Task[List[CalendarShareGrant]] =
    (fr"SELECT" ++ columns ++
      fr"""FROM calendar_share_grants
           WHERE grantee_person_id = ${granteePersonId.value} AND revoked_at IS NULL
           ORDER BY created_at DESC
        """)
      .query[CalendarShareGrant]
      .to[List]
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def countActiveByGrantor(grantorPersonId: PersonId): Task[Int] =
    sql"""
      SELECT COUNT(*) FROM calendar_share_grants
      WHERE grantor_person_id = ${grantorPersonId.value} AND revoked_at IS NULL
    """
      .query[Int]
      .unique
      .transact(xa)
      .mapError(ex => CalendarShareError.DatabaseError(ex))

  override def revoke(id: CalendarShareGrantId, partyPersonId: PersonId, now: Instant): Task[Boolean] =
    sql"""
      UPDATE calendar_share_grants
      SET revoked_at = $now
      WHERE id = ${id.value}
        AND (grantor_person_id = ${partyPersonId.value} OR grantee_person_id = ${partyPersonId.value})
        AND revoked_at IS NULL
    """.update.run
      .transact(xa)
      .mapBoth(ex => CalendarShareError.DatabaseError(ex), _ == 1)

object PostgresCalendarShareGrantRepository:

  val layer: ZLayer[Transactor[Task], Nothing, CalendarShareGrantRepository] = ZLayer.fromFunction(
    PostgresCalendarShareGrantRepository.apply
  )
