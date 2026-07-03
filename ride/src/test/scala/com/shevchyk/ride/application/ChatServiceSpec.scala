package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{ChatService, ChatServiceImpl}
import com.shevchyk.ride.repository.{InMemoryRideRepository, InMemoryChatMessageRepository}
import zio.*
import zio.test.*
import java.util.UUID

object ChatServiceSpec extends ZIOSpecDefault {

  val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId  = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000002"))
  val driverId  = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000003"))

  def makeRide(status: RideStatus): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = status,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B"),
    pickupDateTime = java.time.Instant.now().plusSeconds(3600)
  )

  def layers =
    InMemoryRideRepository.layer ++
      InMemoryChatMessageRepository.layer ++
      EventHub.layer >>>
      (ZLayer.fromFunction(ChatServiceImpl.apply) ++
        InMemoryRideRepository.layer ++
        InMemoryChatMessageRepository.layer ++
        EventHub.layer)

  def createRide(status: RideStatus) = ZIO
    .serviceWithZIO[com.shevchyk.ride.repository.RideRepository](_.create(makeRide(status)).orDie)

  def spec =
    suite("ChatService")(
      suite("sendMessage")(
        test("saves message for Assigned ride") {
          for {
            ride <- createRide(RideStatus.Assigned)
            svc  <- ZIO.service[ChatService]
            msg  <- svc.sendMessage(ride.id, clientId, "hello")
          } yield assertTrue(msg.message == "hello", msg.rideId == ride.id, msg.senderId == clientId)
        }.provide(layers),
        test("saves message for InProgress ride") {
          for {
            ride <- createRide(RideStatus.InProgress)
            svc  <- ZIO.service[ChatService]
            msg  <- svc.sendMessage(ride.id, driverId, "on my way")
          } yield assertTrue(msg.message == "on my way")
        }.provide(layers),
        test("fails for Requested ride with a typed ChatNotAvailable error") {
          for {
            ride  <- createRide(RideStatus.Requested)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, "hi").flip
          } yield assertTrue(error == ChatError.ChatNotAvailable(RideStatus.Requested))
        }.provide(layers),
        test("fails for Completed ride with a typed ChatNotAvailable error") {
          for {
            ride  <- createRide(RideStatus.Completed)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, "hi").flip
          } yield assertTrue(error == ChatError.ChatNotAvailable(RideStatus.Completed))
        }.provide(layers),
        test("fails for Cancelled ride with a typed ChatNotAvailable error") {
          for {
            ride  <- createRide(RideStatus.Cancelled)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, "hi").flip
          } yield assertTrue(error == ChatError.ChatNotAvailable(RideStatus.Cancelled))
        }.provide(layers),
        test("fails when ride not found with a typed RideNotFound error") {
          val missingId = RideId.generate()
          for {
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(missingId, clientId, "hi").flip
          } yield assertTrue(error == ChatError.RideNotFound(missingId))
        }.provide(layers),
        test("rejects an empty message with EmptyMessage and stores nothing") {
          for {
            ride  <- createRide(RideStatus.Assigned)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, "").flip
            msgs  <- svc.getMessages(ride.id)
          } yield assertTrue(error == ChatError.EmptyMessage, msgs.isEmpty)
        }.provide(layers),
        test("rejects a whitespace-only message with EmptyMessage") {
          for {
            ride  <- createRide(RideStatus.Assigned)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, " \t\n ").flip
          } yield assertTrue(error == ChatError.EmptyMessage)
        }.provide(layers),
        test("rejects a message above MaxMessageLength with MessageTooLong and stores nothing") {
          for {
            ride  <- createRide(RideStatus.Assigned)
            svc   <- ZIO.service[ChatService]
            error <- svc.sendMessage(ride.id, clientId, "x" * (ChatService.MaxMessageLength + 1)).flip
            msgs  <- svc.getMessages(ride.id)
          } yield assertTrue(error == ChatError.MessageTooLong(ChatService.MaxMessageLength), msgs.isEmpty)
        }.provide(layers),
        test("accepts a message exactly at MaxMessageLength") {
          for {
            ride <- createRide(RideStatus.Assigned)
            svc  <- ZIO.service[ChatService]
            msg  <- svc.sendMessage(ride.id, clientId, "x" * ChatService.MaxMessageLength)
          } yield assertTrue(msg.message.length == ChatService.MaxMessageLength)
        }.provide(layers),
        test("publishes ChatMessageSent event to EventHub") {
          for {
            hub   <- ZIO.service[EventHub]
            ride  <- createRide(RideStatus.Assigned)
            svc   <- ZIO.service[ChatService]
            event <- ZIO.scoped {
                       for {
                         queue <- hub.subscribe
                         _     <- svc.sendMessage(ride.id, clientId, "event test")
                         e     <- queue.take
                       } yield e
                     }
          } yield assertTrue(event.isInstanceOf[WebSocketEvent.ChatMessageSent])
        }.provide(layers),

        // ─── Mutation-kill: companyId field hardcoded as rideId.value, senderId→rideId, message→"MUTATED" ─

        test("published ChatMessageSent event carries correct companyId, senderId and message") {
          for {
            hub   <- ZIO.service[EventHub]
            ride  <- createRide(RideStatus.Assigned)
            svc   <- ZIO.service[ChatService]
            event <- ZIO.scoped {
                       for {
                         queue <- hub.subscribe
                         _     <- svc.sendMessage(ride.id, clientId, "hello mutation")
                         e     <- queue.take.map(_.asInstanceOf[WebSocketEvent.ChatMessageSent])
                       } yield e
                     }
          } yield assertTrue(
            // companyId must equal ride.companyId.value, NOT rideId.value
            event.companyId == companyId.value,
            // senderId must equal the sender's PersonId, NOT the rideId
            event.senderId == clientId.value,
            // message must be the original text, not a mutation placeholder
            event.message == "hello mutation",
            // rideId sanity check
            event.rideId == ride.id.value
          )
        }.provide(layers)
      ),
      suite("getMessages")(
        test("returns empty list when no messages") {
          for {
            ride <- createRide(RideStatus.Assigned)
            svc  <- ZIO.service[ChatService]
            msgs <- svc.getMessages(ride.id)
          } yield assertTrue(msgs.isEmpty)
        }.provide(layers),
        test("returns all messages for ride in sent order") {
          for {
            ride <- createRide(RideStatus.Assigned)
            svc  <- ZIO.service[ChatService]
            _    <- svc.sendMessage(ride.id, clientId, "first")
            _    <- svc.sendMessage(ride.id, driverId, "second")
            msgs <- svc.getMessages(ride.id)
          } yield assertTrue(msgs.length == 2, msgs.head.message == "first", msgs(1).message == "second")
        }.provide(layers),
        test("returns messages only for requested ride") {
          for {
            repo  <- ZIO.service[com.shevchyk.ride.repository.RideRepository]
            svc   <- ZIO.service[ChatService]
            ride1 <- repo.create(makeRide(RideStatus.Assigned)).orDie
            ride2 <- repo.create(makeRide(RideStatus.Assigned)).orDie
            _     <- svc.sendMessage(ride1.id, clientId, "for ride1")
            _     <- svc.sendMessage(ride2.id, clientId, "for ride2")
            msgs  <- svc.getMessages(ride1.id)
          } yield assertTrue(msgs.length == 1, msgs.head.message == "for ride1")
        }.provide(layers)
      )
    )
}
