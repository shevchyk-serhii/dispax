package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.notification.domain.FcmToken
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait FcmTokenRepository:
  def save(token: FcmToken): Task[Unit]
  // Tenant-scoped lookup: only returns tokens that belong to the given company,
  // so a push can never be delivered to a person's token from another tenant.
  def findByPersonIdAndCompany(personId: PersonId, companyId: CompanyId): Task[List[FcmToken]]
  def deleteByToken(token: String): Task[Unit]
  def deleteByPersonId(personId: PersonId): Task[Unit]

object FcmTokenRepository:

  val layer: ZLayer[Any, Throwable, FcmTokenRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresFcmTokenRepository.postgresLayer

object InMemoryFcmTokenRepository:

  val layer: ZLayer[Any, Nothing, FcmTokenRepository] = ZLayer.succeed {
    new FcmTokenRepository {
      private val store = new ConcurrentHashMap[String, FcmToken]()

      def save(token: FcmToken): Task[Unit] = ZIO.succeed {
        store.put(token.token, token)
      }

      def findByPersonIdAndCompany(personId: PersonId, companyId: CompanyId): Task[List[FcmToken]] = ZIO.succeed {
        store.values().asScala.filter(t => t.personId == personId && t.companyId == companyId).toList
      }

      def deleteByToken(token: String): Task[Unit] = ZIO.succeed {
        store.remove(token)
      }

      def deleteByPersonId(personId: PersonId): Task[Unit] = ZIO.succeed {
        store
          .values()
          .asScala
          .filter(_.personId == personId)
          .foreach(t => store.remove(t.token))
      }
    }
  }
