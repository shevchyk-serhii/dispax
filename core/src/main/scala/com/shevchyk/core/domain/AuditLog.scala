package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class AuditLogId(value: UUID)

object AuditLogId:
  def generate(): AuditLogId  = AuditLogId(UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[AuditLogId] = JsonCodec[UUID].transform(AuditLogId(_), _.value)

enum AuditAction derives JsonCodec:

  case RideCreated, RideAssigned, RideReassigned, RideCancelled, RideStatusChanged,
    RideEdited, UserCreated, UserUpdated, UserDeactivated, PaymentRecorded,
    DriverAvailabilityChanged, AuthorizationDenied

final case class AuditLogEntry(
    id: AuditLogId,
    companyId: CompanyId,
    actorId: PersonId,
    action: AuditAction,
    entityType: String,
    entityId: UUID,
    oldValue: Option[String] = None,
    newValue: Option[String] = None,
    metadata: Option[String] = None,
    createdAt: Instant = Instant.now()
) derives JsonCodec

object AuditLogEntry:

  /**
   * Smart constructor for audit entries recorded by a request handler. It fills in the always-the-same parts (a fresh
   * id and the default `createdAt`) so call sites only pass what actually varies. Keeps the `AuditLogEntry(id =
   * AuditLogId.generate(), actorId = PersonId(user.userId), ...)` boilerplate out of every endpoint.
   */
  def record(
      companyId: CompanyId,
      actorId: PersonId,
      action: AuditAction,
      entityType: String,
      entityId: UUID,
      oldValue: Option[String] = None,
      newValue: Option[String] = None,
      metadata: Option[String] = None
  ): AuditLogEntry = AuditLogEntry(
    id = AuditLogId.generate(),
    companyId = companyId,
    actorId = actorId,
    action = action,
    entityType = entityType,
    entityId = entityId,
    oldValue = oldValue,
    newValue = newValue,
    metadata = metadata
  )
