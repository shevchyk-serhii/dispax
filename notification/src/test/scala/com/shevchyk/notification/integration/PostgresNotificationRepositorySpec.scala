package com.shevchyk.notification.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId}
import com.shevchyk.notification.repository.PostgresNotificationRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for PostgresNotificationRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresNotificationRepositorySpec extends ZIOSpecDefault {

  val companyId     = CompanyId(UUID.fromString("0000000E-0000-0000-0000-000000000001"))
  val personId      = PersonId(UUID.fromString("0000000E-0000-0000-0000-000000000002"))
  val otherPersonId = PersonId(UUID.fromString("0000000E-0000-0000-0000-000000000003"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${companyId.value}, 'Notif Test GmbH', 'notif@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${personId.value}, 'Notif Person', 'notif-person@test.com', 'client'::person_role, ${companyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherPersonId.value}, 'Other Notif Person', 'notif-other@test.com', 'client'::person_role, ${companyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanNotifications(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM notifications".update.run.transact(xa).unit

  private def makeNotification(
      person: PersonId = personId,
      title: String = "Ride assigned",
      isRead: Boolean = false,
      createdAt: Instant = Instant.now(),
      data: Option[String] = Some("""{"rideId":"abc"}""")
  ): AppNotification = AppNotification(
    id = AppNotificationId.generate(),
    personId = person,
    companyId = companyId,
    title = title,
    body = "Your ride has been assigned to a driver",
    notificationType = "ride_update",
    data = data,
    isRead = isRead,
    createdAt = createdAt
  )

  def spec =
    suite("PostgresNotificationRepository")(
      test("save and findByPersonId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          n      = makeNotification()
          _     <- repo.save(n)
          found <- repo.findByPersonId(personId, 10, 0)
        } yield assertTrue(
          found.length == 1,
          found.head.id == n.id,
          found.head.personId == personId,
          found.head.companyId == companyId,
          found.head.title == "Ride assigned",
          found.head.body == "Your ride has been assigned to a driver",
          found.head.notificationType == "ride_update",
          found.head.data.exists(_.contains("rideId")),
          !found.head.isRead
        )
      },
      test("save with no data (null jsonb) round-trips") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          n      = makeNotification(data = None)
          _     <- repo.save(n)
          found <- repo.findByPersonId(personId, 10, 0)
        } yield assertTrue(
          found.length == 1,
          found.head.data.isEmpty
        )
      },
      test("findByPersonId orders by created_at DESC and honors limit/offset") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          base   = Instant.now()
          n1     = makeNotification(title = "oldest", createdAt = base.minusSeconds(300))
          n2     = makeNotification(title = "middle", createdAt = base.minusSeconds(200))
          n3     = makeNotification(title = "newest", createdAt = base.minusSeconds(100))
          _     <- repo.save(n1)
          _     <- repo.save(n2)
          _     <- repo.save(n3)
          page1 <- repo.findByPersonId(personId, 2, 0)
          page2 <- repo.findByPersonId(personId, 2, 2)
        } yield assertTrue(
          page1.map(_.title) == List("newest", "middle"),
          page2.map(_.title) == List("oldest")
        )
      },
      test("findByPersonId isolates by person") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanNotifications(xa)
          repo    = PostgresNotificationRepository(xa)
          _      <- repo.save(makeNotification(person = personId))
          _      <- repo.save(makeNotification(person = otherPersonId))
          mine   <- repo.findByPersonId(personId, 10, 0)
          theirs <- repo.findByPersonId(otherPersonId, 10, 0)
        } yield assertTrue(
          mine.length == 1,
          mine.forall(_.personId == personId),
          theirs.length == 1,
          theirs.forall(_.personId == otherPersonId)
        )
      },
      test("markAsRead flips is_read with person isolation") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          n      = makeNotification()
          _     <- repo.save(n)
          wrong <- repo.markAsRead(n.id, otherPersonId)
          right <- repo.markAsRead(n.id, personId)
          found <- repo.findByPersonId(personId, 10, 0)
        } yield assertTrue(
          !wrong,
          right,
          found.head.isRead
        )
      },
      test("markAllAsRead marks only the given person's notifications") {
        for {
          xa          <- ZIO.service[Transactor[Task]]
          _           <- seedTestData(xa)
          _           <- cleanNotifications(xa)
          repo         = PostgresNotificationRepository(xa)
          _           <- repo.save(makeNotification(person = personId))
          _           <- repo.save(makeNotification(person = personId))
          _           <- repo.save(makeNotification(person = otherPersonId))
          _           <- repo.markAllAsRead(personId)
          mineUnread  <- repo.countUnread(personId)
          otherUnread <- repo.countUnread(otherPersonId)
        } yield assertTrue(
          mineUnread == 0,
          otherUnread == 1
        )
      },
      test("countUnread counts only unread for the person") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          _     <- repo.save(makeNotification(isRead = false))
          _     <- repo.save(makeNotification(isRead = false))
          _     <- repo.save(makeNotification(isRead = true))
          _     <- repo.save(makeNotification(person = otherPersonId, isRead = false))
          count <- repo.countUnread(personId)
        } yield assertTrue(count == 2)
      },
      test("delete removes only the matching person's notification") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanNotifications(xa)
          repo   = PostgresNotificationRepository(xa)
          n      = makeNotification()
          _     <- repo.save(n)
          wrong <- repo.delete(n.id, otherPersonId)
          right <- repo.delete(n.id, personId)
          found <- repo.findByPersonId(personId, 10, 0)
        } yield assertTrue(
          !wrong,
          right,
          found.isEmpty
        )
      },
      test("deleteAllForPerson removes only that person's notifications") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanNotifications(xa)
          repo    = PostgresNotificationRepository(xa)
          _      <- repo.save(makeNotification(person = personId))
          _      <- repo.save(makeNotification(person = personId))
          _      <- repo.save(makeNotification(person = otherPersonId))
          _      <- repo.deleteAllForPerson(personId)
          mine   <- repo.findByPersonId(personId, 10, 0)
          theirs <- repo.findByPersonId(otherPersonId, 10, 0)
        } yield assertTrue(
          mine.isEmpty,
          theirs.length == 1
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag("integration")
}
