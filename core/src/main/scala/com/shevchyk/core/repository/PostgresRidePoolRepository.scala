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

final class PostgresRidePoolRepository(xa: Transactor[Task]) extends RidePoolRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val poolStatusMeta: Meta[PoolStatus] =
    Meta[String].imap {
      case "OPEN"        => PoolStatus.Open
      case "FULL"        => PoolStatus.Full
      case "IN_PROGRESS" => PoolStatus.InProgress
      case "COMPLETED"   => PoolStatus.Completed
      case "CANCELLED"   => PoolStatus.Cancelled
      case s             => PoolStatus.valueOf(s)
    } {
      case PoolStatus.Open       => "OPEN"
      case PoolStatus.Full       => "FULL"
      case PoolStatus.InProgress => "IN_PROGRESS"
      case PoolStatus.Completed  => "COMPLETED"
      case PoolStatus.Cancelled  => "CANCELLED"
    }

  implicit val memberStatusMeta: Meta[PoolMemberStatus] =
    Meta[String].imap {
      case "PENDING"     => PoolMemberStatus.Pending
      case "CONFIRMED"   => PoolMemberStatus.Confirmed
      case "PICKED_UP"   => PoolMemberStatus.PickedUp
      case "DROPPED_OFF" => PoolMemberStatus.DroppedOff
      case "CANCELLED"   => PoolMemberStatus.Cancelled
      case s             => PoolMemberStatus.valueOf(s)
    } {
      case PoolMemberStatus.Pending    => "PENDING"
      case PoolMemberStatus.Confirmed  => "CONFIRMED"
      case PoolMemberStatus.PickedUp   => "PICKED_UP"
      case PoolMemberStatus.DroppedOff => "DROPPED_OFF"
      case PoolMemberStatus.Cancelled  => "CANCELLED"
    }

  override def create(pool: RidePool): Task[RidePool] =
    sql"""
      INSERT INTO ride_pools (id, company_id, name, status, driver_id, max_passengers, current_passengers,
                               route_direction, scheduled_time, created_at, created_by)
      VALUES (${pool.id.value}, ${pool.companyId.value}, ${pool.name}, ${pool.status},
              ${pool.driverId.map(_.value)}, ${pool.maxPassengers}, ${pool.currentPassengers},
              ${pool.routeDirection}, ${pool.scheduledTime}, ${pool.createdAt}, ${pool.createdBy.value})
    """.update.run
      .transact(xa)
      .as(pool)

  override def findById(id: RidePoolId): Task[Option[RidePool]] =
    sql"""
      SELECT id, company_id, name, status, driver_id, max_passengers, current_passengers,
             route_direction, scheduled_time, created_at, created_by
      FROM ride_pools WHERE id = ${id.value}
    """
      .query[RidePool]
      .option
      .transact(xa)

  override def findByCompanyId(companyId: CompanyId): Task[List[RidePool]] =
    sql"""
      SELECT id, company_id, name, status, driver_id, max_passengers, current_passengers,
             route_direction, scheduled_time, created_at, created_by
      FROM ride_pools WHERE company_id = ${companyId.value} ORDER BY created_at DESC
    """
      .query[RidePool]
      .to[List]
      .transact(xa)

  override def findOpenPools(companyId: CompanyId): Task[List[RidePool]] =
    sql"""
      SELECT id, company_id, name, status, driver_id, max_passengers, current_passengers,
             route_direction, scheduled_time, created_at, created_by
      FROM ride_pools WHERE company_id = ${companyId.value} AND status = 'OPEN'
    """
      .query[RidePool]
      .to[List]
      .transact(xa)

  override def update(pool: RidePool): Task[RidePool] =
    sql"""
      UPDATE ride_pools SET
        name = ${pool.name}, status = ${pool.status}, driver_id = ${pool.driverId.map(_.value)},
        max_passengers = ${pool.maxPassengers}, current_passengers = ${pool.currentPassengers},
        route_direction = ${pool.routeDirection}, scheduled_time = ${pool.scheduledTime}
      WHERE id = ${pool.id.value} AND company_id = ${pool.companyId.value}
    """.update.run
      .transact(xa)
      .as(pool)

  override def addMember(member: RidePoolMember): Task[RidePoolMember] =
    sql"""
      INSERT INTO ride_pool_members (id, pool_id, ride_id, client_id, pickup_order, status, added_at)
      VALUES (${member.id.value}, ${member.poolId.value}, ${member.rideId.value},
              ${member.clientId.value}, ${member.pickupOrder}, ${member.status}, ${member.addedAt})
    """.update.run
      .transact(xa)
      .as(member)

  override def findMembersByPoolId(poolId: RidePoolId): Task[List[RidePoolMember]] =
    sql"""
      SELECT id, pool_id, ride_id, client_id, pickup_order, status, added_at
      FROM ride_pool_members WHERE pool_id = ${poolId.value} ORDER BY pickup_order
    """
      .query[RidePoolMember]
      .to[List]
      .transact(xa)

  override def findPoolByRideId(rideId: RideId): Task[Option[RidePool]] =
    sql"""
      SELECT p.id, p.company_id, p.name, p.status, p.driver_id, p.max_passengers, p.current_passengers,
             p.route_direction, p.scheduled_time, p.created_at, p.created_by
      FROM ride_pools p
      JOIN ride_pool_members m ON m.pool_id = p.id
      WHERE m.ride_id = ${rideId.value}
    """
      .query[RidePool]
      .option
      .transact(xa)

  override def removeMember(poolId: RidePoolId, rideId: RideId): Task[Boolean] =
    sql"""DELETE FROM ride_pool_members WHERE pool_id = ${poolId.value} AND ride_id = ${rideId.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def updateMemberStatus(poolId: RidePoolId, rideId: RideId, status: PoolMemberStatus): Task[Boolean] =
    sql"""UPDATE ride_pool_members SET status = ${status} WHERE pool_id = ${poolId.value} AND ride_id = ${rideId.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  implicit val poolRead: Read[RidePool] =
    Read[
      (UUID, UUID, Option[String], PoolStatus, Option[UUID], Int, Int, Option[String], Option[Instant], Instant, UUID)
    ].map {
      case (
            id,
            companyId,
            name,
            status,
            driverId,
            maxPassengers,
            currentPassengers,
            routeDirection,
            scheduledTime,
            createdAt,
            createdBy
          ) =>
        RidePool(
          id = RidePoolId(id),
          companyId = CompanyId(companyId),
          name = name,
          status = status,
          driverId = driverId.map(PersonId.apply),
          maxPassengers = maxPassengers,
          currentPassengers = currentPassengers,
          routeDirection = routeDirection,
          scheduledTime = scheduledTime,
          createdAt = createdAt,
          createdBy = PersonId(createdBy)
        )
    }

  implicit val memberRead: Read[RidePoolMember] = Read[(UUID, UUID, UUID, UUID, Int, PoolMemberStatus, Instant)].map {
    case (id, poolId, rideId, clientId, pickupOrder, status, addedAt) =>
      RidePoolMember(
        id = RidePoolMemberId(id),
        poolId = RidePoolId(poolId),
        rideId = RideId(rideId),
        clientId = PersonId(clientId),
        pickupOrder = pickupOrder,
        status = status,
        addedAt = addedAt
      )
  }

object PostgresRidePoolRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RidePoolRepository] = ZLayer.fromFunction(
    PostgresRidePoolRepository(_)
  )
