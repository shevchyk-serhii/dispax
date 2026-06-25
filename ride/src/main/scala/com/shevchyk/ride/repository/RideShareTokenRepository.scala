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

object RideShareTokenRepository:

  val layer: ZLayer[Any, Throwable, RideShareTokenRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresRideShareTokenRepository.layer
