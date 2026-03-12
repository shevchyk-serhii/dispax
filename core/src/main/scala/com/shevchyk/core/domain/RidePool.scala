package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class RidePoolId(value: UUID) derives JsonCodec

object RidePoolId:
  def generate(): RidePoolId = RidePoolId(UuidCreator.getTimeOrderedEpoch())

enum PoolStatus derives JsonCodec:
  case Open, Full, InProgress, Completed, Cancelled

case class RidePoolMemberId(value: UUID) derives JsonCodec

object RidePoolMemberId:
  def generate(): RidePoolMemberId = RidePoolMemberId(UuidCreator.getTimeOrderedEpoch())

enum PoolMemberStatus derives JsonCodec:
  case Pending, Confirmed, PickedUp, DroppedOff, Cancelled

final case class RidePool(
    id: RidePoolId,
    companyId: CompanyId,
    name: Option[String] = None,
    status: PoolStatus = PoolStatus.Open,
    driverId: Option[PersonId] = None,
    maxPassengers: Int = 4,
    currentPassengers: Int = 0,
    routeDirection: Option[String] = None,
    scheduledTime: Option[Instant] = None,
    createdAt: Instant = Instant.now(),
    createdBy: PersonId
) derives JsonCodec:

  def isFull: Boolean          = currentPassengers >= maxPassengers
  def canAddPassenger: Boolean = status == PoolStatus.Open && !isFull
  def canStart: Boolean        = status == PoolStatus.Open || status == PoolStatus.Full
  def canComplete: Boolean     = status == PoolStatus.InProgress

final case class RidePoolMember(
    id: RidePoolMemberId,
    poolId: RidePoolId,
    rideId: RideId,
    clientId: PersonId,
    pickupOrder: Int = 0,
    status: PoolMemberStatus = PoolMemberStatus.Pending,
    addedAt: Instant = Instant.now()
) derives JsonCodec

final case class CreatePoolRequest(
    name: Option[String] = None,
    maxPassengers: Option[Int] = None,
    routeDirection: Option[String] = None,
    scheduledTime: Option[String] = None,
    rideIds: List[String] = Nil
) derives JsonCodec

final case class AddToPoolRequest(
    rideId: String
) derives JsonCodec
