package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresNotificationPreferenceRepository(xa: Transactor[Task]) extends NotificationPreferenceRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def findByPersonId(personId: PersonId): Task[Option[NotificationPreference]] =
    sql"""
      SELECT id, person_id, ride_updates, chat_messages, driver_approaching, geofence_alerts,
             pool_updates, email_notifications, sms_notifications, quiet_hours_start::text, quiet_hours_end::text, updated_at
      FROM notification_preferences WHERE person_id = ${personId.value}
    """
      .query[NotificationPreference]
      .option
      .transact(xa)

  override def upsert(pref: NotificationPreference): Task[NotificationPreference] =
    sql"""
      INSERT INTO notification_preferences (id, person_id, ride_updates, chat_messages, driver_approaching,
                                             geofence_alerts, pool_updates, email_notifications, sms_notifications,
                                             quiet_hours_start, quiet_hours_end, updated_at)
      VALUES (${pref.id.value}, ${pref.personId.value}, ${pref.rideUpdates}, ${pref.chatMessages},
              ${pref.driverApproaching}, ${pref.geofenceAlerts}, ${pref.poolUpdates},
              ${pref.emailNotifications}, ${pref.smsNotifications},
              ${pref.quietHoursStart}, ${pref.quietHoursEnd},
              NOW())
      ON CONFLICT (person_id) DO UPDATE SET
        ride_updates = ${pref.rideUpdates}, chat_messages = ${pref.chatMessages},
        driver_approaching = ${pref.driverApproaching}, geofence_alerts = ${pref.geofenceAlerts},
        pool_updates = ${pref.poolUpdates}, email_notifications = ${pref.emailNotifications},
        sms_notifications = ${pref.smsNotifications},
        quiet_hours_start = ${pref.quietHoursStart}, quiet_hours_end = ${pref.quietHoursEnd},
        updated_at = NOW()
    """.update.run
      .transact(xa)
      .as(pref.copy(updatedAt = Instant.now()))

  implicit val prefRead: Read[NotificationPreference] =
    Read[
      (
          UUID,
          UUID,
          Boolean,
          Boolean,
          Boolean,
          Boolean,
          Boolean,
          Boolean,
          Boolean,
          Option[String],
          Option[String],
          Instant
      )
    ].map {
      case (
            id,
            personId,
            rideUpdates,
            chatMessages,
            driverApproaching,
            geofenceAlerts,
            poolUpdates,
            emailNotifications,
            smsNotifications,
            quietHoursStart,
            quietHoursEnd,
            updatedAt
          ) =>
        NotificationPreference(
          id = NotificationPreferenceId(id),
          personId = PersonId(personId),
          rideUpdates = rideUpdates,
          chatMessages = chatMessages,
          driverApproaching = driverApproaching,
          geofenceAlerts = geofenceAlerts,
          poolUpdates = poolUpdates,
          emailNotifications = emailNotifications,
          smsNotifications = smsNotifications,
          quietHoursStart = quietHoursStart,
          quietHoursEnd = quietHoursEnd,
          updatedAt = updatedAt
        )
    }

object PostgresNotificationPreferenceRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, NotificationPreferenceRepository] = ZLayer.fromFunction(
    PostgresNotificationPreferenceRepository(_)
  )
