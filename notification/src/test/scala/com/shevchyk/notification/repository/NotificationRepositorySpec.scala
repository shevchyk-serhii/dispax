package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, CompanyId}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object NotificationRepositorySpec extends ZIOSpecDefault {

  val personId1 = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val personId2 = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
  val companyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000001"))

  def makeNotification(personId: PersonId, title: String, isRead: Boolean = false): AppNotification = AppNotification(
    id = AppNotificationId.generate(),
    personId = personId,
    companyId = companyId,
    title = title,
    body = s"Body of $title",
    notificationType = "test",
    isRead = isRead,
    createdAt = Instant.now()
  )

  def spec =
    suite("NotificationRepository (InMemory)")(
      suite("save and findByPersonId")(
        test("saves and retrieves notification") {
          for {
            repo  <- ZIO.service[NotificationRepository]
            n      = makeNotification(personId1, "Test 1")
            saved <- repo.save(n)
            found <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            found.size == 1 &&
              found.head.title == "Test 1"
          )
        }.provide(InMemoryNotificationRepository.layer),
        test("respects personId filter") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            _      <- repo.save(makeNotification(personId1, "For person 1"))
            _      <- repo.save(makeNotification(personId2, "For person 2"))
            found1 <- repo.findByPersonId(personId1, 10, 0)
            found2 <- repo.findByPersonId(personId2, 10, 0)
          } yield assertTrue(
            found1.size == 1 && found1.head.title == "For person 1" &&
              found2.size == 1 && found2.head.title == "For person 2"
          )
        }.provide(InMemoryNotificationRepository.layer),
        test("respects limit and offset") {
          for {
            repo  <- ZIO.service[NotificationRepository]
            _     <- ZIO.foreach(1 to 5)(i => repo.save(makeNotification(personId1, s"Notification $i")))
            page1 <- repo.findByPersonId(personId1, 2, 0)
            page2 <- repo.findByPersonId(personId1, 2, 2)
            all   <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            page1.size == 2 &&
              page2.size == 2 &&
              all.size == 5
          )
        }.provide(InMemoryNotificationRepository.layer)
      ),
      suite("markAsRead")(
        test("marks notification as read") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            n       = makeNotification(personId1, "Unread")
            saved  <- repo.save(n)
            result <- repo.markAsRead(saved.id, personId1)
            found  <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            result == true &&
              found.head.isRead == true
          )
        }.provide(InMemoryNotificationRepository.layer),
        test("returns false for non-existent notification") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            result <- repo.markAsRead(AppNotificationId.generate(), personId1)
          } yield assertTrue(result == false)
        }.provide(InMemoryNotificationRepository.layer),
        test("does not mark another person's notification as read (tenant isolation)") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            saved  <- repo.save(makeNotification(personId1, "Owned by p1"))
            result <- repo.markAsRead(saved.id, personId2)
            found  <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            result == false &&
              found.head.isRead == false
          )
        }.provide(InMemoryNotificationRepository.layer)
      ),
      suite("markAllAsRead")(
        test("marks all unread notifications as read") {
          for {
            repo         <- ZIO.service[NotificationRepository]
            _            <- repo.save(makeNotification(personId1, "N1"))
            _            <- repo.save(makeNotification(personId1, "N2"))
            _            <- repo.save(makeNotification(personId1, "N3"))
            unreadBefore <- repo.countUnread(personId1)
            _            <- repo.markAllAsRead(personId1)
            unreadAfter  <- repo.countUnread(personId1)
          } yield assertTrue(
            unreadBefore == 3 &&
              unreadAfter == 0
          )
        }.provide(InMemoryNotificationRepository.layer),
        test("only affects specified person") {
          for {
            repo    <- ZIO.service[NotificationRepository]
            _       <- repo.save(makeNotification(personId1, "P1"))
            _       <- repo.save(makeNotification(personId2, "P2"))
            _       <- repo.markAllAsRead(personId1)
            unread1 <- repo.countUnread(personId1)
            unread2 <- repo.countUnread(personId2)
          } yield assertTrue(
            unread1 == 0 &&
              unread2 == 1
          )
        }.provide(InMemoryNotificationRepository.layer)
      ),
      suite("countUnread")(
        test("counts only unread notifications") {
          for {
            repo  <- ZIO.service[NotificationRepository]
            _     <- repo.save(makeNotification(personId1, "Unread 1"))
            _     <- repo.save(makeNotification(personId1, "Unread 2"))
            read   = makeNotification(personId1, "Read", isRead = true)
            _     <- repo.save(read)
            count <- repo.countUnread(personId1)
          } yield assertTrue(count == 2)
        }.provide(InMemoryNotificationRepository.layer),
        test("returns 0 for unknown person") {
          for {
            repo     <- ZIO.service[NotificationRepository]
            unknownId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
            count    <- repo.countUnread(unknownId)
          } yield assertTrue(count == 0)
        }.provide(InMemoryNotificationRepository.layer)
      ),
      suite("delete")(
        test("deletes notification") {
          for {
            repo    <- ZIO.service[NotificationRepository]
            n        = makeNotification(personId1, "To Delete")
            saved   <- repo.save(n)
            deleted <- repo.delete(saved.id, personId1)
            found   <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            deleted == true &&
              found.isEmpty
          )
        }.provide(InMemoryNotificationRepository.layer),
        test("returns false for non-existent notification") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            result <- repo.delete(AppNotificationId.generate(), personId1)
          } yield assertTrue(result == false)
        }.provide(InMemoryNotificationRepository.layer),
        test("does not delete another person's notification (tenant isolation)") {
          for {
            repo    <- ZIO.service[NotificationRepository]
            saved   <- repo.save(makeNotification(personId1, "Owned by p1"))
            deleted <- repo.delete(saved.id, personId2)
            found   <- repo.findByPersonId(personId1, 10, 0)
          } yield assertTrue(
            deleted == false &&
              found.size == 1
          )
        }.provide(InMemoryNotificationRepository.layer)
      ),
      suite("deleteAllForPerson")(
        test("deletes all notifications for person") {
          for {
            repo   <- ZIO.service[NotificationRepository]
            _      <- repo.save(makeNotification(personId1, "N1"))
            _      <- repo.save(makeNotification(personId1, "N2"))
            _      <- repo.save(makeNotification(personId2, "Other"))
            _      <- repo.deleteAllForPerson(personId1)
            found1 <- repo.findByPersonId(personId1, 10, 0)
            found2 <- repo.findByPersonId(personId2, 10, 0)
          } yield assertTrue(
            found1.isEmpty &&
              found2.size == 1
          )
        }.provide(InMemoryNotificationRepository.layer)
      )
    )
}
