package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresGdprRepository(xa: Transactor[Task]) extends GdprRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val consentTypeMeta: Meta[ConsentType]             = Meta[String].imap(ConsentType.valueOf)(_.toString)
  implicit val gdprRequestTypeMeta: Meta[GdprRequestType]     = Meta[String].imap(GdprRequestType.valueOf)(_.toString)
  implicit val gdprRequestStatusMeta: Meta[GdprRequestStatus] = Meta[String].imap(GdprRequestStatus.valueOf)(_.toString)

  override def createConsent(consent: GdprConsent): Task[GdprConsent] =
    sql"""
      INSERT INTO gdpr_consents (id, user_id, consent_type, granted_at, revoked_at, ip_address)
      VALUES (${consent.id.value}, ${consent.userId.value}, ${consent.consentType.toString},
              ${consent.grantedAt}, ${consent.revokedAt}, ${consent.ipAddress})
      ON CONFLICT (user_id, consent_type)
      DO UPDATE SET granted_at = ${consent.grantedAt}, revoked_at = NULL, ip_address = ${consent.ipAddress}
    """.update.run
      .transact(xa)
      .as(consent)

  override def findConsentsByUserId(userId: PersonId): Task[List[GdprConsent]] =
    sql"""
      SELECT id, user_id, consent_type, granted_at, revoked_at, ip_address
      FROM gdpr_consents
      WHERE user_id = ${userId.value}
      ORDER BY granted_at DESC
    """
      .query[GdprConsent]
      .to[List]
      .transact(xa)

  override def revokeConsent(userId: PersonId, consentType: ConsentType): Task[Boolean] =
    sql"""
      UPDATE gdpr_consents SET revoked_at = NOW()
      WHERE user_id = ${userId.value} AND consent_type = ${consentType.toString} AND revoked_at IS NULL
    """.update.run
      .transact(xa)
      .map(_ > 0)

  override def createRequest(request: GdprRequest): Task[GdprRequest] =
    sql"""
      INSERT INTO gdpr_requests (id, user_id, request_type, status, requested_at, completed_at, notes)
      VALUES (${request.id.value}, ${request.userId.value}, ${request.requestType.toString},
              ${request.status.toString}, ${request.requestedAt}, ${request.completedAt}, ${request.notes})
    """.update.run
      .transact(xa)
      .as(request)

  override def findRequestsByUserId(userId: PersonId): Task[List[GdprRequest]] =
    sql"""
      SELECT id, user_id, request_type, status, requested_at, completed_at, notes
      FROM gdpr_requests
      WHERE user_id = ${userId.value}
      ORDER BY requested_at DESC
    """
      .query[GdprRequest]
      .to[List]
      .transact(xa)

  override def findAllRequests(companyId: CompanyId): Task[List[GdprRequest]] =
    sql"""
      SELECT r.id, r.user_id, r.request_type, r.status, r.requested_at, r.completed_at, r.notes
      FROM gdpr_requests r
      JOIN persons p ON p.id = r.user_id
      WHERE p.company_id = ${companyId.value}
      ORDER BY r.requested_at DESC
    """
      .query[GdprRequest]
      .to[List]
      .transact(xa)

  override def updateRequestStatus(requestId: GdprRequestId, status: GdprRequestStatus): Task[Boolean] =
    val completedAt = if status == GdprRequestStatus.COMPLETED then Some(Instant.now()) else None
    sql"""
      UPDATE gdpr_requests SET status = ${status.toString}, completed_at = ${completedAt}
      WHERE id = ${requestId.value}
    """.update.run
      .transact(xa)
      .map(_ > 0)

  implicit val consentRead: Read[GdprConsent] = Read[(UUID, UUID, String, Instant, Option[Instant], Option[String])]
    .map { case (id, userId, consentType, grantedAt, revokedAt, ipAddress) =>
      GdprConsent(
        id = GdprConsentId(id),
        userId = PersonId(userId),
        consentType = ConsentType.valueOf(consentType),
        grantedAt = grantedAt,
        revokedAt = revokedAt,
        ipAddress = ipAddress
      )
    }

  implicit val requestRead: Read[GdprRequest] =
    Read[(UUID, UUID, String, String, Instant, Option[Instant], Option[String])].map {
      case (id, userId, requestType, status, requestedAt, completedAt, notes) =>
        GdprRequest(
          id = GdprRequestId(id),
          userId = PersonId(userId),
          requestType = GdprRequestType.valueOf(requestType),
          status = GdprRequestStatus.valueOf(status),
          requestedAt = requestedAt,
          completedAt = completedAt,
          notes = notes
        )
    }

object PostgresGdprRepository:
  val postgresLayer: ZLayer[Transactor[Task], Nothing, GdprRepository] = ZLayer.fromFunction(PostgresGdprRepository(_))
