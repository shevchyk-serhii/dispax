package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class AuditLogId(value: UUID) derives JsonCodec

object AuditLogId:
  def generate(): AuditLogId = AuditLogId(UuidCreator.getTimeOrderedEpoch())

enum AuditAction derives JsonCodec:

  case RideCreated, RideAssigned, RideReassigned, RideCancelled, RideStatusChanged,
    RideEdited, UserCreated, UserUpdated, UserDeactivated, PaymentRecorded,
    DriverAvailabilityChanged

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
