package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*

trait RidePoolRepository:
  def create(pool: RidePool): Task[RidePool]
  def findById(id: RidePoolId): Task[Option[RidePool]]
  def findByCompanyId(companyId: CompanyId): Task[List[RidePool]]
  def findOpenPools(companyId: CompanyId): Task[List[RidePool]]
  def update(pool: RidePool): Task[RidePool]
  def addMember(member: RidePoolMember): Task[RidePoolMember]
  def findMembersByPoolId(poolId: RidePoolId): Task[List[RidePoolMember]]
  def findPoolByRideId(rideId: RideId): Task[Option[RidePool]]
  def removeMember(poolId: RidePoolId, rideId: RideId): Task[Boolean]
  def updateMemberStatus(poolId: RidePoolId, rideId: RideId, status: PoolMemberStatus): Task[Boolean]

object RidePoolRepository:

  val inMemory: ZLayer[Any, Nothing, RidePoolRepository] = ZLayer.succeed(InMemoryRidePoolRepository())

  val layer: ZLayer[Any, Throwable, RidePoolRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresRidePoolRepository.postgresLayer

class InMemoryRidePoolRepository extends RidePoolRepository:
  private var pools: Map[RidePoolId, RidePool] = Map.empty
  private var members: List[RidePoolMember]    = List.empty

  def create(pool: RidePool): Task[RidePool] = ZIO.succeed {
    pools = pools + (pool.id -> pool)
    pool
  }

  def findById(id: RidePoolId): Task[Option[RidePool]] = ZIO.succeed(pools.get(id))

  def findByCompanyId(companyId: CompanyId): Task[List[RidePool]] = ZIO.succeed(
    pools.values.filter(_.companyId == companyId).toList.sortBy(_.createdAt).reverse
  )

  def findOpenPools(companyId: CompanyId): Task[List[RidePool]] = ZIO.succeed(
    pools.values.filter(p => p.companyId == companyId && p.status == PoolStatus.Open).toList
  )

  def update(pool: RidePool): Task[RidePool] = ZIO.succeed {
    pools = pools + (pool.id -> pool)
    pool
  }

  def addMember(member: RidePoolMember): Task[RidePoolMember] = ZIO.succeed {
    members = members :+ member
    member
  }

  def findMembersByPoolId(poolId: RidePoolId): Task[List[RidePoolMember]] = ZIO.succeed(
    members.filter(_.poolId == poolId).sortBy(_.pickupOrder)
  )

  def findPoolByRideId(rideId: RideId): Task[Option[RidePool]] = ZIO.succeed {
    members.find(_.rideId == rideId).flatMap(m => pools.get(m.poolId))
  }

  def removeMember(poolId: RidePoolId, rideId: RideId): Task[Boolean] = ZIO.succeed {
    val before = members.size
    members = members.filterNot(m => m.poolId == poolId && m.rideId == rideId)
    members.size < before
  }

  def updateMemberStatus(poolId: RidePoolId, rideId: RideId, status: PoolMemberStatus): Task[Boolean] = ZIO.succeed {
    var found = false
    members = members.map { m =>
      if m.poolId == poolId && m.rideId == rideId then
        found = true
        m.copy(status = status)
      else m
    }
    found
  }
