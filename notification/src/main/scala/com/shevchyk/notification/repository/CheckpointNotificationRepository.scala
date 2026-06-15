package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.database.DatabaseConfig
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

/**
 * Deduplication table for airport checkpoint push notifications. Keyed on (ride_id, driver_id, checkpoint_type) to
 * ensure one push per checkpoint per ride. Mirrors the SentReminderRepository pattern.
 */
trait CheckpointNotificationRepository:
  def isAlreadySent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean]
  def markSent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Unit]

object CheckpointNotificationRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, CheckpointNotificationRepository] = ZLayer.fromFunction(
    PostgresCheckpointNotificationRepository.apply
  )

  val layer: ZLayer[Any, Throwable, CheckpointNotificationRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer

class InMemoryCheckpointNotificationRepository extends CheckpointNotificationRepository:
  private val sent = new java.util.concurrent.ConcurrentHashMap[(java.util.UUID, java.util.UUID, String), Boolean]()

  override def isAlreadySent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean] = ZIO.succeed(
    sent.containsKey((rideId.value, driverId.value, checkpointType))
  )

  override def markSent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Unit] =
    ZIO.succeed(sent.put((rideId.value, driverId.value, checkpointType), true)).unit

object InMemoryCheckpointNotificationRepository:

  val layer: zio.ULayer[CheckpointNotificationRepository] = zio.ZLayer.succeed(
    new InMemoryCheckpointNotificationRepository
  )

final class PostgresCheckpointNotificationRepository(xa: Transactor[Task]) extends CheckpointNotificationRepository:

  override def isAlreadySent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean] =
    sql"""SELECT EXISTS(
            SELECT 1 FROM sent_checkpoint_notifications
            WHERE ride_id = ${rideId.value}
              AND driver_id = ${driverId.value}
              AND checkpoint_type = $checkpointType
          )"""
      .query[Boolean]
      .unique
      .transact(xa)

  override def markSent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Unit] =
    sql"""INSERT INTO sent_checkpoint_notifications (ride_id, driver_id, checkpoint_type)
          VALUES (${rideId.value}, ${driverId.value}, $checkpointType)
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .unit
