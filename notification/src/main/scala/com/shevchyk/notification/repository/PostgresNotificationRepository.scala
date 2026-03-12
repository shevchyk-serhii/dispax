package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, CompanyId}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId}
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresNotificationRepository(xa: Transactor[Task]) extends NotificationRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def save(notification: AppNotification): Task[AppNotification] =
    sql"""
      INSERT INTO notifications (id, person_id, company_id, title, body, type, data, is_read, created_at)
      VALUES (${notification.id.value}, ${notification.personId.value}, ${notification.companyId.value},
              ${notification.title}, ${notification.body}, ${notification.notificationType},
              ${notification.data}::jsonb, ${notification.isRead}, ${notification.createdAt})
    """.update.run
      .transact(xa)
      .as(notification)

  override def findByPersonId(personId: PersonId, limit: Int, offset: Int): Task[List[AppNotification]] =
    sql"""
      SELECT id, person_id, company_id, title, body, type, data::text, is_read, created_at
      FROM notifications WHERE person_id = ${personId.value}
      ORDER BY created_at DESC LIMIT $limit OFFSET $offset
    """
      .query[AppNotification]
      .to[List]
      .transact(xa)

  override def markAsRead(id: AppNotificationId): Task[Boolean] =
    sql"""UPDATE notifications SET is_read = true WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def markAllAsRead(personId: PersonId): Task[Unit] =
    sql"""UPDATE notifications SET is_read = true WHERE person_id = ${personId.value} AND is_read = false""".update.run
      .transact(xa)
      .unit

  override def countUnread(personId: PersonId): Task[Int] =
    sql"""SELECT COUNT(*)::int FROM notifications WHERE person_id = ${personId.value} AND is_read = false"""
      .query[Int]
      .unique
      .transact(xa)

  override def delete(id: AppNotificationId): Task[Boolean] =
    sql"""DELETE FROM notifications WHERE id = ${id.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def deleteAllForPerson(personId: PersonId): Task[Unit] =
    sql"""DELETE FROM notifications WHERE person_id = ${personId.value}""".update.run
      .transact(xa)
      .unit

  implicit val notificationRead: Read[AppNotification] =
    Read[(UUID, UUID, UUID, String, String, String, Option[String], Boolean, Instant)].map {
      case (id, personId, companyId, title, body, notificationType, data, isRead, createdAt) =>
        AppNotification(
          id = AppNotificationId(id),
          personId = PersonId(personId),
          companyId = CompanyId(companyId),
          title = title,
          body = body,
          notificationType = notificationType,
          data = data,
          isRead = isRead,
          createdAt = createdAt
        )
    }

object PostgresNotificationRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, NotificationRepository] = ZLayer.fromFunction(
    PostgresNotificationRepository(_)
  )
