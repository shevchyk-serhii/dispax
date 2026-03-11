package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, PersonId}
import com.shevchyk.ride.domain.{ChatMessage, ChatMessageId}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresChatMessageRepository(xa: Transactor[Task]) extends ChatMessageRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def save(message: ChatMessage): Task[ChatMessage] =
    sql"""
      INSERT INTO chat_messages (id, ride_id, sender_id, message, sent_at)
      VALUES (${message.id.value}, ${message.rideId.value}, ${message.senderId.value}, ${message.message}, ${message.sentAt})
    """.update.run
      .transact(xa)
      .as(message)

  override def findByRideId(rideId: RideId): Task[List[ChatMessage]] =
    sql"""
      SELECT id, ride_id, sender_id, message, sent_at
      FROM chat_messages
      WHERE ride_id = ${rideId.value}
      ORDER BY sent_at ASC
    """
      .query[(UUID, UUID, UUID, String, Instant)]
      .to[List]
      .transact(xa)
      .map(_.map { case (id, rideId, senderId, message, sentAt) =>
        ChatMessage(ChatMessageId(id), RideId(rideId), PersonId(senderId), message, sentAt)
      })

object PostgresChatMessageRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ChatMessageRepository] = ZLayer.fromFunction(
    PostgresChatMessageRepository(_)
  )
