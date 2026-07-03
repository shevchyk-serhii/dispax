package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant
import java.util.UUID
import zio.json.*

case class ChatMessageId(value: UUID)

object ChatMessageId:
  given JsonCodec[ChatMessageId] = JsonCodec[UUID].transform(ChatMessageId(_), _.value)

final case class ChatMessage(
    id: ChatMessageId,
    rideId: RideId,
    senderId: PersonId,
    message: String,
    sentAt: Instant = Instant.now()
)

object ChatMessage:
  given JsonEncoder[ChatMessage] = DeriveJsonEncoder.gen[ChatMessage]
  given JsonDecoder[ChatMessage] = DeriveJsonDecoder.gen[ChatMessage]

/**
 * Typed failure channel of the chat service (see docs/scala-style.md §6). Extends `Throwable` so the errors can also
 * flow through `Task`-typed call sites.
 */
enum ChatError extends Throwable:
  /**
   * The ride the message targets does not exist.
   */
  case RideNotFound(rideId: RideId)

  /**
   * Chat is only open while a ride is Assigned or InProgress.
   */
  case ChatNotAvailable(status: RideStatus)

  /**
   * The message is empty or whitespace-only.
   */
  case EmptyMessage

  /**
   * The message exceeds the maximum accepted length.
   */
  case MessageTooLong(maxLength: Int)

  /**
   * An underlying repository/eventing failure.
   */
  case StorageError(cause: Throwable)
