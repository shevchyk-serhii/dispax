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
 * Integration tests for PostgresRidePoolRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresRidePoolRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("0a000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("0a000001-0000-0000-0000-000000000002"))
  val creatorId      = PersonId(UUID.fromString("0a000002-0000-0000-0000-000000000001"))
  val driverId       = PersonId(UUID.fromString("0a000002-0000-0000-0000-000000000002"))
  val clientId       = PersonId(UUID.fromString("0a000002-0000-0000-0000-000000000003"))
  val rideId1        = RideId(UUID.fromString("0a000003-0000-0000-0000-000000000001"))
  val rideId2        = RideId(UUID.fromString("0a000003-0000-0000-0000-000000000002"))

  private def insertPerson(id: PersonId, email: String, role: String, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
          VALUES (${id.value}, 'Test Person', $email, $role::person_role, ${company.value}, 'placeholder')
          ON CONFLICT DO NOTHING""".update.run

  private def insertRide(id: RideId, company: CompanyId): ConnectionIO[Int] =
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime)
          VALUES (${id.value}, ${clientId.value}, ${creatorId.value}, ${company.value},
                  'From', 'To', NOW())
          ON CONFLICT DO NOTHING""".update.run

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Test GmbH', 'pool-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Other GmbH', 'pool-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <- insertPerson(creatorId, "pool-creator@test.com", "dispatcher", testCompanyId)
      _ <- insertPerson(driverId, "pool-driver@test.com", "driver", testCompanyId)
      _ <- insertPerson(clientId, "pool-client@test.com", "client", testCompanyId)
      _ <- insertRide(rideId1, testCompanyId)
      _ <- insertRide(rideId2, testCompanyId)
    } yield ()).transact(xa)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <- sql"DELETE FROM ride_pool_members".update.run
      _ <- sql"DELETE FROM ride_pools".update.run
    } yield ()).transact(xa).unit

  private def makePool(
      id: RidePoolId = RidePoolId(UUID.randomUUID()),
      company: CompanyId = testCompanyId,
      status: PoolStatus = PoolStatus.Open,
      name: Option[String] = Some("Pool"),
      driver: Option[PersonId] = None
  ): RidePool = RidePool(
    id = id,
    companyId = company,
    name = name,
    status = status,
    driverId = driver,
    maxPassengers = 4,
    currentPassengers = 0,
    routeDirection = Some("North"),
    scheduledTime = Some(Instant.now().plusSeconds(3600)),
    createdAt = Instant.now(),
    createdBy = creatorId
  )

  private def makeMember(
      poolId: RidePoolId,
      rideId: RideId,
      pickupOrder: Int = 0,
      status: PoolMemberStatus = PoolMemberStatus.Pending
  ): RidePoolMember = RidePoolMember(
    id = RidePoolMemberId(UUID.randomUUID()),
    poolId = poolId,
    rideId = rideId,
    clientId = clientId,
    pickupOrder = pickupOrder,
    status = status,
    addedAt = Instant.now()
  )

  def spec =
    suite("PostgresRidePoolRepository")(
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresRidePoolRepository(xa)
          pool   = makePool(driver = Some(driverId))
          _     <- repo.create(pool)
          found <- repo.findById(pool.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == pool.id,
          found.get.companyId == testCompanyId,
          found.get.name.contains("Pool"),
          found.get.status == PoolStatus.Open,
          found.get.driverId.contains(driverId),
          found.get.routeDirection.contains("North"),
          found.get.createdBy == creatorId
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresRidePoolRepository(xa)
          found <- repo.findById(RidePoolId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("findByCompanyId isolates by company") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresRidePoolRepository(xa)
          _      <- repo.create(makePool())
          _      <- repo.create(makePool())
          _      <- repo.create(makePool(company = otherCompanyId))
          mine   <- repo.findByCompanyId(testCompanyId)
          others <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.companyId == testCompanyId),
          others.length == 1
        )
      },
      test("findOpenPools returns only OPEN pools of the company") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresRidePoolRepository(xa)
          open   = makePool(status = PoolStatus.Open)
          closed = makePool(status = PoolStatus.Completed)
          _     <- repo.create(open)
          _     <- repo.create(closed)
          _     <- repo.create(makePool(status = PoolStatus.Open, company = otherCompanyId))
          pools <- repo.findOpenPools(testCompanyId)
        } yield assertTrue(
          pools.length == 1,
          pools.head.id == open.id,
          pools.forall(_.status == PoolStatus.Open)
        )
      },
      test("update changes status, driver and passenger count") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          repo    = PostgresRidePoolRepository(xa)
          pool    = makePool()
          _      <- repo.create(pool)
          updated = pool.copy(status = PoolStatus.Full, driverId = Some(driverId), currentPassengers = 4)
          _      <- repo.update(updated)
          found  <- repo.findById(pool.id)
        } yield assertTrue(
          found.get.status == PoolStatus.Full,
          found.get.driverId.contains(driverId),
          found.get.currentPassengers == 4
        )
      },
      test("addMember and findMembersByPoolId ordered by pickup_order") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresRidePoolRepository(xa)
          pool     = makePool()
          _       <- repo.create(pool)
          m1       = makeMember(pool.id, rideId2, pickupOrder = 2)
          m2       = makeMember(pool.id, rideId1, pickupOrder = 1)
          _       <- repo.addMember(m1)
          _       <- repo.addMember(m2)
          members <- repo.findMembersByPoolId(pool.id)
        } yield assertTrue(
          members.length == 2,
          members.head.rideId == rideId1,
          members(1).rideId == rideId2,
          members.head.clientId == clientId
        )
      },
      test("findPoolByRideId joins member to pool") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          repo   = PostgresRidePoolRepository(xa)
          pool   = makePool()
          _     <- repo.create(pool)
          _     <- repo.addMember(makeMember(pool.id, rideId1))
          found <- repo.findPoolByRideId(rideId1)
          none  <- repo.findPoolByRideId(rideId2)
        } yield assertTrue(
          found.isDefined,
          found.get.id == pool.id,
          none.isEmpty
        )
      },
      test("removeMember deletes membership") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresRidePoolRepository(xa)
          pool     = makePool()
          _       <- repo.create(pool)
          _       <- repo.addMember(makeMember(pool.id, rideId1))
          removed <- repo.removeMember(pool.id, rideId1)
          missing <- repo.removeMember(pool.id, rideId2)
          members <- repo.findMembersByPoolId(pool.id)
        } yield assertTrue(removed, !missing, members.isEmpty)
      },
      test("updateMemberStatus changes member status") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seed(xa)
          _       <- clean(xa)
          repo     = PostgresRidePoolRepository(xa)
          pool     = makePool()
          _       <- repo.create(pool)
          _       <- repo.addMember(makeMember(pool.id, rideId1))
          updated <- repo.updateMemberStatus(pool.id, rideId1, PoolMemberStatus.PickedUp)
          members <- repo.findMembersByPoolId(pool.id)
        } yield assertTrue(updated, members.head.status == PoolMemberStatus.PickedUp)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
