package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{ChatMessageRepository, RideRepository}
import zio.*
import java.util.UUID

trait ChatService:
  def sendMessage(rideId: RideId, senderId: PersonId, message: String): IO[ChatError, ChatMessage]
  def getMessages(rideId: RideId): IO[ChatError, List[ChatMessage]]

class ChatServiceImpl(
    chatRepo: ChatMessageRepository,
    rideRepo: RideRepository,
    eventHub: EventHub
) extends ChatService:

  def sendMessage(rideId: RideId, senderId: PersonId, message: String): IO[ChatError, ChatMessage] =
    for
      _       <- ZIO.fail(ChatError.EmptyMessage).when(message.trim.isEmpty)
      _       <- ZIO
                   .fail(ChatError.MessageTooLong(ChatService.MaxMessageLength))
                   .when(message.length > ChatService.MaxMessageLength)
      rideOpt <- rideRepo.findById(rideId).mapError(ChatError.StorageError(_))
      ride    <- ZIO.fromOption(rideOpt).orElseFail(ChatError.RideNotFound(rideId))
      _       <- ZIO
                   .fail(ChatError.ChatNotAvailable(ride.status))
                   .when(ride.status != RideStatus.Assigned && ride.status != RideStatus.InProgress)
      msg      = ChatMessage(
                   id = ChatMessageId(UUID.randomUUID()),
                   rideId = rideId,
                   senderId = senderId,
                   message = message
                 )
      saved   <- chatRepo.save(msg).mapError(ChatError.StorageError(_))
      _       <-
        eventHub
          .publish(
            WebSocketEvent.ChatMessageSent(
              rideId = rideId.value,
              senderId = senderId.value,
              message = message,
              companyId = ride.companyId.value
            )
          )
          .ignore
    yield saved

  def getMessages(rideId: RideId): IO[ChatError, List[ChatMessage]] = chatRepo
    .findByRideId(rideId)
    .mapError(ChatError.StorageError(_))

object ChatService:

  /**
   * Maximum accepted chat message length in characters. Longer payloads are rejected with [[ChatError.MessageTooLong]]
   * before anything is stored — the column is unbounded TEXT, so this is the only cap.
   */
  val MaxMessageLength: Int = 2000

  val layer: ZLayer[ChatMessageRepository & RideRepository & EventHub, Nothing, ChatService] = ZLayer.fromFunction(
    ChatServiceImpl.apply
  )
