package com.shevchyk.core.repository

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for PostgresEmergencyReassignmentRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresEmergencyReassignmentRepositorySpec extends ZIOSpecDefault {

  val testCompanyId    = CompanyId(UUID.fromString("0d000001-0000-0000-0000-000000000001"))
  val otherCompanyId   = CompanyId(UUID.fromString("0d000001-0000-0000-0000-000000000002"))
  val clientId         = PersonId(UUID.fromString("0d000002-0000-0000-0000-000000000001"))
  val origDriverId     = PersonId(UUID.fromString("0d000002-0000-0000-0000-000000000002"))
  val newDriverId      = PersonId(UUID.fromString("0d000002-0000-0000-0000-000000000003"))
  val dispatcherId     = PersonId(UUID.fromString("0d000002-0000-0000-0000-000000000004"))
  val rideId1          = RideId(UUID.fromString("0d000003-0000-0000-0000-000000000001"))
  val rideId2          = RideId(UUID.fromString("0d000003-0000-0000-0000-000000000002"))
  val otherCompanyRide = RideId(UUID.fromString("0d000003-0000-0000-0000-000000000003"))

  private def insertPerson(id: PersonId, email: String, role: String, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
          VALUES (${id.value}, 'Test Person', $email, $role::person_role, ${company.value}, 'placeholder')
          ON CONFLICT DO NOTHING""".update.run

  private def insertRide(id: RideId, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime)
          VALUES (${id.value}, ${clientId.value}, ${dispatcherId.value}, ${company.value}, 'From', 'To', NOW())
          ON CONFLICT DO NOTHING""".update.run

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'emg-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'emg-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- insertPerson(clientId, "emg-client@test.com", "client", testCompanyId)
      _ <- insertPerson(origDriverId, "emg-orig@test.com", "driver", testCompanyId)
      _ <- insertPerson(newDriverId, "emg-new@test.com", "driver", testCompanyId)
      _ <- insertPerson(dispatcherId, "emg-disp@test.com", "dispatcher", testCompanyId)
      _ <- insertRide(rideId1, testCompanyId)
      _ <- insertRide(rideId2, testCompanyId)
      _ <- insertRide(otherCompanyRide, otherCompanyId)
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM emergency_reassignments".update.run.transact(xa).unit

  private def makeReassignment(
      id: EmergencyReassignmentId = EmergencyReassignmentId(UUID.randomUUID()),
      ride: RideId = rideId1,
      company: CompanyId = testCompanyId,
      newDriver: Option[PersonId] = None,
      status: ReassignmentStatus = ReassignmentStatus.PENDING
  ): EmergencyReassignment = EmergencyReassignment(
    id = id,
    rideId = ride,
    companyId = company,
    originalDriverId = origDriverId,
    newDriverId = newDriver,
    reason = EmergencyReason.VehicleBreakdown,
    notes = Some("car broke down"),
    reassignedBy = dispatcherId,
    createdAt = Instant.now(),
    status = status
  )

  def spec =
    suite("PostgresEmergencyReassignmentRepository")(
      test("create and findByRideId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresEmergencyReassignmentRepository(xa)
          r      = makeReassignment()
          _     <- repo.create(r)
          found <- repo.findByRideId(rideId1)
        } yield assertTrue(
          found.length == 1,
          found.head.id == r.id,
          found.head.rideId == rideId1,
          found.head.originalDriverId == origDriverId,
          found.head.reason == EmergencyReason.VehicleBreakdown,
          found.head.notes.contains("car broke down"),
          found.head.reassignedBy == dispatcherId,
          found.head.status == ReassignmentStatus.PENDING,
          found.head.newDriverId.isEmpty
        )
      },
      test("create with newDriverId persists it") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresEmergencyReassignmentRepository(xa)
          r      = makeReassignment(newDriver = Some(newDriverId), status = ReassignmentStatus.REASSIGNED)
          _     <- repo.create(r)
          found <- repo.findByRideId(rideId1)
        } yield assertTrue(
          found.head.newDriverId.contains(newDriverId),
          found.head.status == ReassignmentStatus.REASSIGNED
        )
      },
      test("findByCompanyId isolates by company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresEmergencyReassignmentRepository(xa)
          _      <- repo.create(makeReassignment(ride = rideId1))
          _      <- repo.create(makeReassignment(ride = rideId2))
          _      <- repo.create(makeReassignment(ride = otherCompanyRide, company = otherCompanyId))
          mine   <- repo.findByCompanyId(testCompanyId)
          others <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(mine.length == 2, mine.forall(_.companyId == testCompanyId), others.length == 1)
      },
      test("updateStatus without driver changes only status") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresEmergencyReassignmentRepository(xa)
          r        = makeReassignment()
          _       <- repo.create(r)
          updated <- repo.updateStatus(r.id, ReassignmentStatus.CANCELLED, None)
          found   <- repo.findByRideId(rideId1)
        } yield assertTrue(updated, found.head.status == ReassignmentStatus.CANCELLED, found.head.newDriverId.isEmpty)
      },
      test("updateStatus with driver sets new_driver_id") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresEmergencyReassignmentRepository(xa)
          r        = makeReassignment()
          _       <- repo.create(r)
          updated <- repo.updateStatus(r.id, ReassignmentStatus.REASSIGNED, Some(newDriverId))
          missing <- repo.updateStatus(EmergencyReassignmentId(UUID.randomUUID()), ReassignmentStatus.REASSIGNED, None)
          found   <- repo.findByRideId(rideId1)
        } yield assertTrue(
          updated,
          !missing,
          found.head.status == ReassignmentStatus.REASSIGNED,
          found.head.newDriverId.contains(newDriverId)
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
