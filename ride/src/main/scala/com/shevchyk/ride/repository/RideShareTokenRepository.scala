package com.shevchyk.ride.repository

import com.shevchyk.core.domain.RideId
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.ride.domain.RideShareToken
import zio.*

trait RideShareTokenRepository:
  def create(token: RideShareToken): Task[RideShareToken]
  def findByToken(token: String): Task[Option[RideShareToken]]

  /**
   * The most recent non-expired token for a ride, used to reuse an existing live link instead of minting a new one on
   * every share. Filters on the coarse DB `expires_at`; the fine status-based window is checked at resolve time.
   */
  def findActiveByRideId(rideId: RideId): Task[Option[RideShareToken]]

  /**
   * Revoke EVERY share token of a ride (regardless of expiry). Returns the number of tokens removed. Used when the ride
   * is reassigned to a different client: the previous client's guest /track link would otherwise stay live for up to
   * 24h and keep streaming the driver's position and route for a ride that is no longer theirs.
   */
  def deleteByRideId(rideId: RideId): Task[Int]

object RideShareTokenRepository:

  val layer: ZLayer[Any, Throwable, RideShareTokenRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresRideShareTokenRepository.layer
