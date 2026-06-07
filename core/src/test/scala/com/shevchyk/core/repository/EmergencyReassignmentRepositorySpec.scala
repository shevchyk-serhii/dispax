package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*
import java.time.Instant

object EmergencyReassignmentRepositorySpec extends ZIOSpecDefault {

  val companyId      = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()
  val rideId1        = RideId.generate()
  val rideId2        = RideId.generate()
  val driverId1      = PersonId.generate()
  val driverId2      = PersonId.generate()
  val adminId        = PersonId.generate()

  def makeReassignment(
      rideId: RideId = rideId1,
      companyId: CompanyId = companyId,
      originalDriverId: PersonId = driverId1,
      newDriverId: Option[PersonId] = None,
      reason: EmergencyReason = EmergencyReason.DriverIllness,
      status: ReassignmentStatus = ReassignmentStatus.PENDING
  ): EmergencyReassignment = EmergencyReassignment(
    id = EmergencyReassignmentId.generate(),
    rideId = rideId,
    companyId = companyId,
    originalDriverId = originalDriverId,
    newDriverId = newDriverId,
    reason = reason,
    reassignedBy = adminId,
    createdAt = Instant.now(),
    status = status
  )

  val layers = EmergencyReassignmentRepository.inMemory

  def spec =
    suite("EmergencyReassignmentRepository")(
      suite("create and findByCompanyId")(
        test("creates and finds by company") {
          val r = makeReassignment()
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(r)
            found <- repo.findByCompanyId(companyId)
          } yield assertTrue(found.size == 1 && found.head.id == r.id)
        }.provide(layers),
        test("does not return other company's reassignments") {
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(makeReassignment(companyId = companyId))
            found <- repo.findByCompanyId(otherCompanyId)
          } yield assertTrue(found.isEmpty)
        }.provide(layers),
        test("returns multiple reassignments for same company") {
          val r1 = makeReassignment(rideId = rideId1)
          val r2 = makeReassignment(rideId = rideId2)
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(r1)
            _     <- repo.create(r2)
            found <- repo.findByCompanyId(companyId)
          } yield assertTrue(found.size == 2)
        }.provide(layers)
      ),
      suite("findByRideId")(
        test("returns reassignments for specific ride") {
          val r1 = makeReassignment(rideId = rideId1)
          val r2 = makeReassignment(rideId = rideId2)
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(r1)
            _     <- repo.create(r2)
            found <- repo.findByRideId(rideId1)
          } yield assertTrue(found.size == 1 && found.head.rideId == rideId1)
        }.provide(layers),
        test("returns empty for unknown ride") {
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(makeReassignment(rideId = rideId1))
            found <- repo.findByRideId(rideId2)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("updateStatus")(
        test("updates status to REASSIGNED") {
          val r = makeReassignment()
          for {
            repo   <- ZIO.service[EmergencyReassignmentRepository]
            _      <- repo.create(r)
            result <- repo.updateStatus(r.id, ReassignmentStatus.REASSIGNED, None)
            found  <- repo.findByCompanyId(companyId)
          } yield assertTrue(result && found.head.status == ReassignmentStatus.REASSIGNED)
        }.provide(layers),
        test("updates status to CANCELLED") {
          val r = makeReassignment()
          for {
            repo   <- ZIO.service[EmergencyReassignmentRepository]
            _      <- repo.create(r)
            result <- repo.updateStatus(r.id, ReassignmentStatus.CANCELLED, None)
            found  <- repo.findByCompanyId(companyId)
          } yield assertTrue(result && found.head.status == ReassignmentStatus.CANCELLED)
        }.provide(layers),
        test("sets new driver id when provided") {
          val r = makeReassignment(newDriverId = None)
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(r)
            _     <- repo.updateStatus(r.id, ReassignmentStatus.REASSIGNED, Some(driverId2))
            found <- repo.findByCompanyId(companyId)
          } yield assertTrue(found.head.newDriverId.contains(driverId2))
        }.provide(layers),
        test("preserves existing new driver id when None passed") {
          val r = makeReassignment(newDriverId = Some(driverId1))
          for {
            repo  <- ZIO.service[EmergencyReassignmentRepository]
            _     <- repo.create(r)
            _     <- repo.updateStatus(r.id, ReassignmentStatus.REASSIGNED, None)
            found <- repo.findByCompanyId(companyId)
          } yield assertTrue(found.head.newDriverId.contains(driverId1))
        }.provide(layers),
        test("returns false for unknown id") {
          for {
            repo   <- ZIO.service[EmergencyReassignmentRepository]
            result <- repo.updateStatus(EmergencyReassignmentId.generate(), ReassignmentStatus.CANCELLED, None)
          } yield assertTrue(!result)
        }.provide(layers)
      )
    )
}
