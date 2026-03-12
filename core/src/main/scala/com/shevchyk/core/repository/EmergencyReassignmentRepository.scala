package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*

trait EmergencyReassignmentRepository:
  def create(reassignment: EmergencyReassignment): Task[EmergencyReassignment]
  def findByCompanyId(companyId: CompanyId): Task[List[EmergencyReassignment]]
  def findByRideId(rideId: RideId): Task[List[EmergencyReassignment]]

  def updateStatus(
      id: EmergencyReassignmentId,
      status: ReassignmentStatus,
      newDriverId: Option[PersonId]
  ): Task[Boolean]

object EmergencyReassignmentRepository:

  val inMemory: ZLayer[Any, Nothing, EmergencyReassignmentRepository] = ZLayer.succeed(
    InMemoryEmergencyReassignmentRepository()
  )

  val layer: ZLayer[Any, Throwable, EmergencyReassignmentRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresEmergencyReassignmentRepository.postgresLayer

class InMemoryEmergencyReassignmentRepository extends EmergencyReassignmentRepository:
  private var reassignments: List[EmergencyReassignment] = List.empty

  override def create(reassignment: EmergencyReassignment): Task[EmergencyReassignment] = ZIO.succeed {
    reassignments = reassignments :+ reassignment
    reassignment
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[EmergencyReassignment]] = ZIO.succeed {
    reassignments.filter(_.companyId == companyId).sortBy(_.createdAt).reverse
  }

  override def findByRideId(rideId: RideId): Task[List[EmergencyReassignment]] = ZIO.succeed {
    reassignments.filter(_.rideId == rideId)
  }

  override def updateStatus(
      id: EmergencyReassignmentId,
      status: ReassignmentStatus,
      newDriverId: Option[PersonId]
  ): Task[Boolean] = ZIO.succeed {
    val idx = reassignments.indexWhere(_.id == id)
    if idx >= 0 then
      reassignments = reassignments.updated(
        idx,
        reassignments(idx).copy(status = status, newDriverId = newDriverId.orElse(reassignments(idx).newDriverId))
      )
      true
    else false
  }
