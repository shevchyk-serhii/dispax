package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.core.repository.SentConfirmationRequestRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

/**
 * PostgreSQL-backed implementation of [[SentConfirmationRequestRepository]]. The trait and in-memory implementation
 * live in `core` so that the `ride` module can depend on the abstraction without a circular reference (notification →
 * ride → notification).
 */
final class PostgresSentConfirmationRequestRepository(xa: Transactor[Task]) extends SentConfirmationRequestRepository:

  override def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean] =
    sql"""SELECT EXISTS(
            SELECT 1 FROM sent_confirmation_requests
            WHERE ride_id = ${rideId.value} AND person_id = ${personId.value}
          )"""
      .query[Boolean]
      .unique
      .transact(xa)

  override def markSent(rideId: RideId, personId: PersonId): Task[Unit] =
    sql"""INSERT INTO sent_confirmation_requests (ride_id, person_id)
          VALUES (${rideId.value}, ${personId.value})
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .unit

  override def markSentIfNew(rideId: RideId, personId: PersonId): Task[Boolean] =
    sql"""INSERT INTO sent_confirmation_requests (ride_id, person_id)
          VALUES (${rideId.value}, ${personId.value})
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .map(_ > 0)

  override def clear(rideId: RideId): Task[Unit] =
    sql"""DELETE FROM sent_confirmation_requests WHERE ride_id = ${rideId.value}""".update.run
      .transact(xa)
      .unit

object PostgresSentConfirmationRequestRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, SentConfirmationRequestRepository] = ZLayer.fromFunction(
    PostgresSentConfirmationRequestRepository.apply
  )

  /**
   * Full Postgres layer with Flyway migrations.
   */
  val layer: ZLayer[Any, Throwable, SentConfirmationRequestRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
