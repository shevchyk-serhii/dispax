package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*

object RidePoolRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()
  val testCreatedBy  = PersonId.generate()
  val testClientId   = PersonId.generate()

  def makePool(
      companyId: CompanyId = testCompanyId,
      status: PoolStatus = PoolStatus.Open
  ): RidePool = RidePool(
    id = RidePoolId.generate(),
    companyId = companyId,
    name = Some("Test Pool"),
    status = status,
    maxPassengers = 4,
    createdBy = testCreatedBy
  )

  def makeMember(
      poolId: RidePoolId,
      rideId: RideId = RideId.generate(),
      pickupOrder: Int = 0
  ): RidePoolMember = RidePoolMember(
    id = RidePoolMemberId.generate(),
    poolId = poolId,
    rideId = rideId,
    clientId = testClientId,
    pickupOrder = pickupOrder
  )

  val layers = RidePoolRepository.inMemory

  def spec =
    suite("RidePoolRepository")(
      test("create and findById") {
        val pool = makePool()
        for {
          repo    <- ZIO.service[RidePoolRepository]
          created <- repo.create(pool)
          found   <- repo.findById(pool.id)
        } yield assertTrue(
          created.id == pool.id &&
            found.isDefined &&
            found.get.id == pool.id &&
            found.get.companyId == testCompanyId
        )
      }.provide(layers),
      test("findByCompanyId") {
        val pool1 = makePool(companyId = testCompanyId)
        val pool2 = makePool(companyId = otherCompanyId)
        for {
          repo  <- ZIO.service[RidePoolRepository]
          _     <- repo.create(pool1)
          _     <- repo.create(pool2)
          found <- repo.findByCompanyId(testCompanyId)
        } yield assertTrue(
          found.size == 1 &&
            found.head.companyId == testCompanyId
        )
      }.provide(layers),
      test("findOpenPools") {
        val openPool   = makePool(status = PoolStatus.Open)
        val closedPool = makePool(status = PoolStatus.Completed)
        for {
          repo  <- ZIO.service[RidePoolRepository]
          _     <- repo.create(openPool)
          _     <- repo.create(closedPool)
          found <- repo.findOpenPools(testCompanyId)
        } yield assertTrue(
          found.size == 1 &&
            found.head.status == PoolStatus.Open
        )
      }.provide(layers),
      test("addMember and findMembersByPoolId") {
        val pool    = makePool()
        val member1 = makeMember(pool.id, pickupOrder = 2)
        val member2 = makeMember(pool.id, pickupOrder = 1)
        for {
          repo    <- ZIO.service[RidePoolRepository]
          _       <- repo.create(pool)
          added1  <- repo.addMember(member1)
          added2  <- repo.addMember(member2)
          members <- repo.findMembersByPoolId(pool.id)
        } yield assertTrue(
          members.size == 2 &&
            added1.id == member1.id &&
            added2.id == member2.id &&
            members.head.pickupOrder == 1 &&
            members(1).pickupOrder == 2
        )
      }.provide(layers),
      test("removeMember") {
        val pool   = makePool()
        val rideId = RideId.generate()
        val member = makeMember(pool.id, rideId = rideId)
        for {
          repo    <- ZIO.service[RidePoolRepository]
          _       <- repo.create(pool)
          _       <- repo.addMember(member)
          removed <- repo.removeMember(pool.id, rideId)
          members <- repo.findMembersByPoolId(pool.id)
        } yield assertTrue(removed && members.isEmpty)
      }.provide(layers),
      test("findPoolByRideId") {
        val pool   = makePool()
        val rideId = RideId.generate()
        val member = makeMember(pool.id, rideId = rideId)
        for {
          repo     <- ZIO.service[RidePoolRepository]
          _        <- repo.create(pool)
          _        <- repo.addMember(member)
          found    <- repo.findPoolByRideId(rideId)
          notFound <- repo.findPoolByRideId(RideId.generate())
        } yield assertTrue(
          found.isDefined &&
            found.get.id == pool.id &&
            notFound.isEmpty
        )
      }.provide(layers)
    )
}
