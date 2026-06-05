package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.database.DatabaseConfig
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

trait SentReminderRepository:
  def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean]
  def markSent(rideId: RideId, personId: PersonId): Task[Unit]

object SentReminderRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, SentReminderRepository] = ZLayer.fromFunction(
    PostgresSentReminderRepository.apply
  )

  val layer: ZLayer[Any, Throwable, SentReminderRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer

final class PostgresSentReminderRepository(xa: Transactor[Task]) extends SentReminderRepository:

  override def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean] =
    sql"""SELECT EXISTS(
            SELECT 1 FROM sent_reminders
            WHERE ride_id = ${rideId.value} AND person_id = ${personId.value}
          )"""
      .query[Boolean]
      .unique
      .transact(xa)

  override def markSent(rideId: RideId, personId: PersonId): Task[Unit] =
    sql"""INSERT INTO sent_reminders (ride_id, person_id)
          VALUES (${rideId.value}, ${personId.value})
          ON CONFLICT DO NOTHING""".update.run
      .transact(xa)
      .unit
