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

final class PostgresEmergencyReassignmentRepository(xa: Transactor[Task]) extends EmergencyReassignmentRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val reasonMeta: Meta[EmergencyReason]    = Meta[String].imap(EmergencyReason.valueOf)(_.toString)
  implicit val statusMeta: Meta[ReassignmentStatus] = Meta[String].imap(ReassignmentStatus.valueOf)(_.toString)

  override def create(reassignment: EmergencyReassignment): Task[EmergencyReassignment] =
    sql"""
      INSERT INTO emergency_reassignments (id, ride_id, company_id, original_driver_id, new_driver_id,
                                            reason, notes, reassigned_by, created_at, status)
      VALUES (${reassignment.id.value}, ${reassignment.rideId.value}, ${reassignment.companyId.value},
              ${reassignment.originalDriverId.value}, ${reassignment.newDriverId.map(_.value)},
              ${reassignment.reason.toString}, ${reassignment.notes}, ${reassignment.reassignedBy.value},
              ${reassignment.createdAt}, ${reassignment.status.toString})
    """.update.run
      .transact(xa)
      .as(reassignment)

  override def findByCompanyId(companyId: CompanyId): Task[List[EmergencyReassignment]] =
    sql"""
      SELECT id, ride_id, company_id, original_driver_id, new_driver_id, reason, notes, reassigned_by, created_at, status
      FROM emergency_reassignments WHERE company_id = ${companyId.value}
      ORDER BY created_at DESC
    """
      .query[EmergencyReassignment]
      .to[List]
      .transact(xa)

  override def findByRideId(rideId: RideId): Task[List[EmergencyReassignment]] =
    sql"""
      SELECT id, ride_id, company_id, original_driver_id, new_driver_id, reason, notes, reassigned_by, created_at, status
      FROM emergency_reassignments WHERE ride_id = ${rideId.value}
    """
      .query[EmergencyReassignment]
      .to[List]
      .transact(xa)

  override def updateStatus(
      id: EmergencyReassignmentId,
      status: ReassignmentStatus,
      newDriverId: Option[PersonId]
  ): Task[Boolean] =
    val driverUpdate =
      newDriverId match
        case Some(dId) =>
          sql"""UPDATE emergency_reassignments SET status = ${status.toString}, new_driver_id = ${dId.value} WHERE id = ${id.value}"""
        case None      => sql"""UPDATE emergency_reassignments SET status = ${status.toString} WHERE id = ${id.value}"""
    driverUpdate.update.run
      .transact(xa)
      .map(_ > 0)

  implicit val reassignmentRead: Read[EmergencyReassignment] =
    Read[(UUID, UUID, UUID, UUID, Option[UUID], String, Option[String], UUID, Instant, String)].map {
      case (id, rideId, companyId, originalDriverId, newDriverId, reason, notes, reassignedBy, createdAt, status) =>
        EmergencyReassignment(
          id = EmergencyReassignmentId(id),
          rideId = RideId(rideId),
          companyId = CompanyId(companyId),
          originalDriverId = PersonId(originalDriverId),
          newDriverId = newDriverId.map(PersonId.apply),
          reason = EmergencyReason.valueOf(reason),
          notes = notes,
          reassignedBy = PersonId(reassignedBy),
          createdAt = createdAt,
          status = ReassignmentStatus.valueOf(status)
        )
    }

object PostgresEmergencyReassignmentRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, EmergencyReassignmentRepository] = ZLayer.fromFunction(
    PostgresEmergencyReassignmentRepository(_)
  )
