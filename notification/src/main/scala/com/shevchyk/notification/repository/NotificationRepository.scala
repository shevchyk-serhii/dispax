package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, CompanyId}
import com.shevchyk.notification.domain.{AppNotification, AppNotificationId}
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait NotificationRepository:
  def save(notification: AppNotification): Task[AppNotification]
  def findByPersonId(personId: PersonId, limit: Int, offset: Int): Task[List[AppNotification]]
  def markAsRead(id: AppNotificationId, personId: PersonId): Task[Boolean]
  def markAllAsRead(personId: PersonId): Task[Unit]
  def countUnread(personId: PersonId): Task[Int]
  def delete(id: AppNotificationId, personId: PersonId): Task[Boolean]
  def deleteAllForPerson(personId: PersonId): Task[Unit]

class InMemoryNotificationRepository extends NotificationRepository:
  private val store = new ConcurrentHashMap[AppNotificationId, AppNotification]()

  def save(notification: AppNotification): Task[AppNotification] = ZIO.succeed {
    store.put(notification.id, notification)
    notification
  }

  def findByPersonId(personId: PersonId, limit: Int, offset: Int): Task[List[AppNotification]] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(_.personId == personId)
      .toList
      .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
      .drop(offset)
      .take(limit)
  }

  def markAsRead(id: AppNotificationId, personId: PersonId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)).filter(_.personId == personId) match
      case Some(n) =>
        store.put(id, n.copy(isRead = true))
        true
      case None    => false
  }

  def markAllAsRead(personId: PersonId): Task[Unit] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(n => n.personId == personId && !n.isRead)
      .foreach(n => store.put(n.id, n.copy(isRead = true)))
  }

  def countUnread(personId: PersonId): Task[Int] = ZIO.succeed {
    store.values().asScala.count(n => n.personId == personId && !n.isRead)
  }

  def delete(id: AppNotificationId, personId: PersonId): Task[Boolean] = ZIO.succeed {
    Option(store.get(id)).filter(_.personId == personId) match
      case Some(_) => Option(store.remove(id)).isDefined
      case None    => false
  }

  def deleteAllForPerson(personId: PersonId): Task[Unit] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(_.personId == personId)
      .foreach(n => store.remove(n.id))
  }

object NotificationRepository:

  val layer: ZLayer[Any, Throwable, NotificationRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresNotificationRepository.postgresLayer

object InMemoryNotificationRepository:
  val layer: ZLayer[Any, Nothing, NotificationRepository] = ZLayer.succeed(new InMemoryNotificationRepository)
