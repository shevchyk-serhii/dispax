package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.database.DatabaseConfig
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

/**
 * Deduplicates delay-risk alerts from the predictive ETA monitor: at most one
 * alert per (ride, driver) until the ride changes. Mirrors
 * [[SentReminderRepository]].
 */
trait EtaAlertRepository:
  def isAlreadyAlerted(rideId: RideId, driverId: PersonId): Task[Boolean]
  def markAlerted(rideId: RideId, driverId: PersonId): Task[Unit]
  def clear(rideId: RideId): Task[Unit]

object EtaAlertRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, EtaAlertRepository] = ZLayer.fromFunction(
    PostgresEtaAlertRepository.apply
  )

  val layer: ZLayer[Any, Throwable, EtaAlertRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer

final class PostgresEtaAlertRepository(xa: Transactor[Task]) extends EtaAlertRepository:

  override def isAlreadyAlerted(rideId: RideId, driverId: PersonId): Task[Boolean] =
    sql"""SELECT EXISTS(
            SELECT 1 FROM eta_alerts
            WHERE ride_id = ${rideId.value} AND driver_id = ${driverId.value}
          )"""
      .query[Boolean]
      .unique
      .transact(xa)

  override def markAlerted(rideId: RideId, driverId: PersonId): Task[Unit] =
    sql"""INSERT INTO eta_alerts (ride_id, driver_id)
          VALUES (${rideId.value}, ${driverId.value})
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .unit

  override def clear(rideId: RideId): Task[Unit] =
    sql"""DELETE FROM eta_alerts WHERE ride_id = ${rideId.value}""".update.run
      .transact(xa)
      .unit
