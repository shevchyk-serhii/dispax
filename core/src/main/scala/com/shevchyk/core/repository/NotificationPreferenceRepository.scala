package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*

trait NotificationPreferenceRepository:
  def findByPersonId(personId: PersonId): Task[Option[NotificationPreference]]
  def upsert(pref: NotificationPreference): Task[NotificationPreference]

object NotificationPreferenceRepository:

  val inMemory: ZLayer[Any, Nothing, NotificationPreferenceRepository] = ZLayer.succeed(
    InMemoryNotificationPreferenceRepository()
  )

  val layer: ZLayer[Any, Throwable, NotificationPreferenceRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresNotificationPreferenceRepository.postgresLayer

class InMemoryNotificationPreferenceRepository extends NotificationPreferenceRepository:
  private var prefs: Map[PersonId, NotificationPreference] = Map.empty

  def findByPersonId(personId: PersonId): Task[Option[NotificationPreference]] = ZIO.succeed(prefs.get(personId))

  def upsert(pref: NotificationPreference): Task[NotificationPreference] = ZIO.succeed {
    prefs = prefs + (pref.personId -> pref)
    pref
  }
