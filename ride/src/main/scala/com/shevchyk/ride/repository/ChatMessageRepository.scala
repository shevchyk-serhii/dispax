package com.shevchyk.ride.repository

import com.shevchyk.core.domain.RideId
import com.shevchyk.ride.domain.{ChatMessage, ChatMessageId}
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait ChatMessageRepository:
  def save(message: ChatMessage): Task[ChatMessage]
  def findByRideId(rideId: RideId): Task[List[ChatMessage]]

object ChatMessageRepository:
  import com.shevchyk.core.database.DatabaseConfig

  val layer: ZLayer[Any, Throwable, ChatMessageRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresChatMessageRepository.layer

class InMemoryChatMessageRepository extends ChatMessageRepository:
  private val store = new ConcurrentHashMap[ChatMessageId, ChatMessage]()

  def save(message: ChatMessage): Task[ChatMessage] = ZIO.succeed {
    store.put(message.id, message)
    message
  }

  def findByRideId(rideId: RideId): Task[List[ChatMessage]] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(_.rideId == rideId)
      .toList
      .sortBy(_.sentAt)
  }

object InMemoryChatMessageRepository:
  val layer: ULayer[ChatMessageRepository] = ZLayer.succeed(InMemoryChatMessageRepository())
