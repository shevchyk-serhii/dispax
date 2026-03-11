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
