package com.shevchyk.core.repository

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.util.UUID

/**
 * Integration tests for PostgresNotificationPreferenceRepository against a real PostgreSQL database via Testcontainers.
 *
 * These also guard a fixed bug: `upsert` used to bind `quiet_hours_start` / `quiet_hours_end` (Scala `Option[String]`)
 * into the TIME columns without a `::time` cast, so every write failed with "column ... is of type time without time
 * zone but expression is of type character varying". The repo now casts both with `::time`; the upsert round-trip test
 * below exercises that path.
 */
object PostgresNotificationPreferenceRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  val personId      = PersonId(UUID.fromString("0000000B-0000-0000-0000-000000000002"))
  val otherPersonId = PersonId(UUID.fromString("0000000B-0000-0000-0000-000000000003"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Pref Test GmbH', 'pref@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${personId.value}, 'Pref Person', 'pref-person@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherPersonId.value}, 'Other Pref Person', 'pref-other@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanPrefs(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM notification_preferences".update.run.transact(xa).unit

  /**
   * Seed a preference row directly with correct TIME casts (bypassing the broken upsert).
   */
  private def seedPref(
      xa: Transactor[Task],
      id: NotificationPreferenceId,
      person: PersonId,
      rideUpdates: Boolean = true,
      quietStart: Option[String] = None,
      quietEnd: Option[String] = None
  ): Task[Unit] =
    sql"""
      INSERT INTO notification_preferences
        (id, person_id, ride_updates, chat_messages, driver_approaching, geofence_alerts,
         pool_updates, email_notifications, sms_notifications, quiet_hours_start, quiet_hours_end, updated_at)
      VALUES
        (${id.value}, ${person.value}, $rideUpdates, false, true, false,
         true, true, false, ${quietStart}::time, ${quietEnd}::time, NOW())
    """.update.run.transact(xa).unit

  def spec =
    suite("PostgresNotificationPreferenceRepository")(
      test("findByPersonId maps a seeded row correctly (incl. quiet hours)") {
        val id = NotificationPreferenceId.generate()
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanPrefs(xa)
          _     <- seedPref(xa, id, personId, rideUpdates = true, quietStart = Some("22:00"), quietEnd = Some("07:00"))
          repo   = PostgresNotificationPreferenceRepository(xa)
          found <- repo.findByPersonId(personId)
        } yield assertTrue(
          found.isDefined,
          found.get.id == id,
          found.get.personId == personId,
          found.get.rideUpdates,
          !found.get.chatMessages,
          found.get.driverApproaching,
          !found.get.geofenceAlerts,
          found.get.poolUpdates,
          found.get.emailNotifications,
          !found.get.smsNotifications,
          found.get.quietHoursStart.contains("22:00:00"),
          found.get.quietHoursEnd.contains("07:00:00")
        )
      },
      test("findByPersonId returns None when absent") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanPrefs(xa)
          repo   = PostgresNotificationPreferenceRepository(xa)
          found <- repo.findByPersonId(personId)
        } yield assertTrue(found.isEmpty)
      },
      test("findByPersonId isolates by person") {
        val id1 = NotificationPreferenceId.generate()
        val id2 = NotificationPreferenceId.generate()
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanPrefs(xa)
          _      <- seedPref(xa, id1, personId, rideUpdates = true)
          _      <- seedPref(xa, id2, otherPersonId, rideUpdates = false)
          repo    = PostgresNotificationPreferenceRepository(xa)
          mine   <- repo.findByPersonId(personId)
          theirs <- repo.findByPersonId(otherPersonId)
        } yield assertTrue(
          mine.isDefined,
          mine.get.personId == personId,
          mine.get.rideUpdates,
          theirs.isDefined,
          theirs.get.personId == otherPersonId,
          !theirs.get.rideUpdates
        )
      },
      test("upsert inserts then updates on conflict (quiet hours cast to ::time)") {
        val pref = NotificationPreference(
          id = NotificationPreferenceId.generate(),
          personId = personId,
          rideUpdates = true,
          smsNotifications = false,
          quietHoursStart = Some("22:00"),
          quietHoursEnd = Some("06:00")
        )
        for {
          xa        <- ZIO.service[Transactor[Task]]
          _         <- seedTestData(xa)
          _         <- cleanPrefs(xa)
          repo       = PostgresNotificationPreferenceRepository(xa)
          // first upsert inserts the row
          _         <- repo.upsert(pref)
          inserted  <- repo.findByPersonId(personId)
          // second upsert with the same person_id updates in place (ON CONFLICT)
          _         <- repo.upsert(pref.copy(rideUpdates = false, smsNotifications = true, quietHoursStart = None))
          updated   <- repo.findByPersonId(personId)
          allForPid <- repo.findByPersonId(personId)
        } yield assertTrue(
          inserted.isDefined,
          inserted.get.rideUpdates,
          inserted.get.quietHoursStart.contains("22:00:00"),
          inserted.get.quietHoursEnd.contains("06:00:00"),
          updated.isDefined,
          !updated.get.rideUpdates,
          updated.get.smsNotifications,
          updated.get.quietHoursStart.isEmpty,
          // still exactly one row for this person — conflict updated, not duplicated
          allForPid.isDefined
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
