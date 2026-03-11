package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{ChatMessageRepository, RideRepository}
import zio.*
import java.util.UUID

trait ChatService:
  def sendMessage(rideId: RideId, senderId: PersonId, message: String): Task[ChatMessage]
  def getMessages(rideId: RideId): Task[List[ChatMessage]]

class ChatServiceImpl(
    chatRepo: ChatMessageRepository,
    rideRepo: RideRepository,
    eventHub: EventHub
) extends ChatService:

  def sendMessage(rideId: RideId, senderId: PersonId, message: String): Task[ChatMessage] =
    for
      rideOpt <- rideRepo.findById(rideId)
      ride    <- ZIO.fromOption(rideOpt).orElseFail(new RuntimeException(s"Ride not found: ${rideId.value}"))
      _       <- ZIO
                   .fail(new RuntimeException("Chat is only available for active rides"))
                   .when(ride.status != RideStatus.Assigned && ride.status != RideStatus.InProgress)
      msg      = ChatMessage(
                   id = ChatMessageId(UUID.randomUUID()),
                   rideId = rideId,
                   senderId = senderId,
                   message = message
                 )
      saved   <- chatRepo.save(msg)
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

  def getMessages(rideId: RideId): Task[List[ChatMessage]] = chatRepo.findByRideId(rideId)

object ChatService:

  val layer: ZLayer[ChatMessageRepository & RideRepository & EventHub, Nothing, ChatService] = ZLayer.fromFunction(
    ChatServiceImpl.apply
  )
