package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class EmergencyReassignmentId(value: UUID) derives JsonCodec

object EmergencyReassignmentId:
  def generate(): EmergencyReassignmentId = EmergencyReassignmentId(UuidCreator.getTimeOrderedEpoch())

enum EmergencyReason derives JsonCodec:
  case DriverIllness, VehicleBreakdown, DriverNoShow, Accident, PersonalEmergency, Other

enum ReassignmentStatus derives JsonCodec:
  case PENDING, REASSIGNED, CANCELLED

case class EmergencyReassignment(
    id: EmergencyReassignmentId,
    rideId: RideId,
    companyId: CompanyId,
    originalDriverId: PersonId,
    newDriverId: Option[PersonId] = None,
    reason: EmergencyReason,
    notes: Option[String] = None,
    reassignedBy: PersonId,
    createdAt: Instant = Instant.now(),
    status: ReassignmentStatus = ReassignmentStatus.PENDING
) derives JsonCodec

case class EmergencyReassignRequest(
    rideId: String,
    reason: String,
    newDriverId: Option[String] = None,
    notes: Option[String] = None
) derives JsonCodec
