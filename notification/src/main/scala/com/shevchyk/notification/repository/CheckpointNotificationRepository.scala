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

  /**
   * Atomically records a checkpoint notification for (ride, driver, checkpoint), returning `true` only if this call
   * inserted a *new* record. Lets callers deduplicate without a check-then-act race: two concurrent checkpoint events
   * (or two app instances) cannot both observe `true`. Mirrors `EtaAlertRepository.markAlertedIfNew`.
   */
  def markSentIfNew(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean]

object CheckpointNotificationRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, CheckpointNotificationRepository] = ZLayer.fromFunction(
    PostgresCheckpointNotificationRepository.apply
  )

  val layer: ZLayer[Any, Throwable, CheckpointNotificationRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer

class InMemoryCheckpointNotificationRepository extends CheckpointNotificationRepository:

  // java.lang.Boolean (not scala.Boolean) so putIfAbsent can signal "no previous mapping" with null.
  private val sent =
    new java.util.concurrent.ConcurrentHashMap[(java.util.UUID, java.util.UUID, String), java.lang.Boolean]()

  override def isAlreadySent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean] = ZIO.succeed(
    sent.containsKey((rideId.value, driverId.value, checkpointType))
  )

  override def markSent(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Unit] =
    ZIO.succeed(sent.put((rideId.value, driverId.value, checkpointType), true)).unit

  override def markSentIfNew(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean] =
    // putIfAbsent returns null only when no mapping existed — i.e. this call inserted the record.
    ZIO.succeed(sent.putIfAbsent((rideId.value, driverId.value, checkpointType), java.lang.Boolean.TRUE) == null)

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

  override def markSentIfNew(rideId: RideId, driverId: PersonId, checkpointType: String): Task[Boolean] =
    sql"""INSERT INTO sent_checkpoint_notifications (ride_id, driver_id, checkpoint_type)
          VALUES (${rideId.value}, ${driverId.value}, $checkpointType)
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .map(_ > 0)
