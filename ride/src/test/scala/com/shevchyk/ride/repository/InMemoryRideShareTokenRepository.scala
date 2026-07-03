package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, RideShareTokenId}
import com.shevchyk.ride.domain.RideShareToken
import zio.*

import java.time.Instant

class InMemoryRideShareTokenRepository extends RideShareTokenRepository:

  private val tokens = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe
      .run(Ref.Synchronized.make(Map.empty[RideShareTokenId, RideShareToken]))
      .getOrThrowFiberFailure()
  }

  override def create(token: RideShareToken): Task[RideShareToken] = tokens.update(_.updated(token.id, token)).as(token)

  override def findByToken(token: String): Task[Option[RideShareToken]] = tokens.get.map(
    _.values.find(_.token == token)
  )

  override def findActiveByRideId(rideId: RideId): Task[Option[RideShareToken]] = tokens.get.map(
    _.values
      .filter(t => t.rideId == rideId && t.expiresAt.isAfter(Instant.now()))
      .toList
      .sortBy(_.createdAt)
      .lastOption
  )

  override def deleteByRideId(rideId: RideId): Task[Int] = tokens.modify { m =>
    val (dead, alive) = m.partition(_._2.rideId == rideId)
    (dead.size, alive)
  }

object InMemoryRideShareTokenRepository:
  val layer: ULayer[RideShareTokenRepository] = ZLayer.succeed(new InMemoryRideShareTokenRepository)
