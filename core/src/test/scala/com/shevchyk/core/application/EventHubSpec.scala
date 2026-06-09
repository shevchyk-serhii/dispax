package com.shevchyk.core.application

import com.shevchyk.core.domain.WebSocketEvent
import zio.*
import zio.test.*
import java.util.UUID

object EventHubSpec extends ZIOSpecDefault {

  val testCompanyId: UUID = UUID.fromString("00000001-0000-0000-0000-000000000001")

  def spec =
    suite("EventHub")(
      suite("publish and subscribe")(
        test("published event is received by subscriber") {
          ZIO.scoped {
            for {
              hub      <- ZIO.service[EventHub]
              dequeue  <- hub.subscribe
              event     = WebSocketEvent.RideCreated(
                            rideId = UUID.randomUUID(),
                            clientId = UUID.randomUUID(),
                            companyId = testCompanyId
                          )
              _        <- hub.publish(event)
              received <- dequeue.take
            } yield assertTrue(received == event)
          }
        }.provide(EventHub.layer),
        test("multiple subscribers each receive the event") {
          ZIO.scoped {
            for {
              hub      <- ZIO.service[EventHub]
              dequeue1 <- hub.subscribe
              dequeue2 <- hub.subscribe
              event     = WebSocketEvent.RideCreated(
                            rideId = UUID.randomUUID(),
                            clientId = UUID.randomUUID(),
                            companyId = testCompanyId
                          )
              _        <- hub.publish(event)
              r1       <- dequeue1.take
              r2       <- dequeue2.take
            } yield assertTrue(r1 == event && r2 == event)
          }
        }.provide(EventHub.layer),
        test("no events received when none published") {
          ZIO.scoped {
            for {
              hub     <- ZIO.service[EventHub]
              dequeue <- hub.subscribe
              events  <- dequeue.takeAll
            } yield assertTrue(events.isEmpty)
          }
        }.provide(EventHub.layer)
      ),
      suite("event types")(
        test("RideCreated event preserves all fields") {
          val rideId   = UUID.randomUUID()
          val clientId = UUID.randomUUID()
          ZIO.scoped {
            for {
              hub      <- ZIO.service[EventHub]
              dequeue  <- hub.subscribe
              event     = WebSocketEvent.RideCreated(
                            rideId = rideId,
                            clientId = clientId,
                            companyId = testCompanyId
                          )
              _        <- hub.publish(event)
              received <- dequeue.take
              rc        = received.asInstanceOf[WebSocketEvent.RideCreated]
            } yield assertTrue(
              rc.rideId == rideId &&
                rc.clientId == clientId &&
                rc.companyId == testCompanyId
            )
          }
        }.provide(EventHub.layer),
        test("RideAssigned event preserves all fields") {
          val rideId   = UUID.randomUUID()
          val driverId = UUID.randomUUID()
          val clientId = UUID.randomUUID()
          ZIO.scoped {
            for {
              hub      <- ZIO.service[EventHub]
              dequeue  <- hub.subscribe
              event     = WebSocketEvent.RideAssigned(
                            rideId = rideId,
                            driverId = driverId,
                            clientId = clientId,
                            companyId = testCompanyId
                          )
              _        <- hub.publish(event)
              received <- dequeue.take
              ra        = received.asInstanceOf[WebSocketEvent.RideAssigned]
            } yield assertTrue(
              ra.rideId == rideId &&
                ra.driverId == driverId &&
                ra.clientId == clientId &&
                ra.companyId == testCompanyId
            )
          }
        }.provide(EventHub.layer),
        test("LocationUpdated event preserves all fields") {
          val userId = UUID.randomUUID()
          val rideId = UUID.randomUUID()
          ZIO.scoped {
            for {
              hub      <- ZIO.service[EventHub]
              dequeue  <- hub.subscribe
              event     = WebSocketEvent.LocationUpdated(
                            rideId = Some(rideId),
                            userId = userId,
                            latitude = 48.1351,
                            longitude = 11.5820,
                            locationType = "driver",
                            companyId = testCompanyId
                          )
              _        <- hub.publish(event)
              received <- dequeue.take
              lu        = received.asInstanceOf[WebSocketEvent.LocationUpdated]
            } yield assertTrue(
              lu.rideId.contains(rideId) &&
                lu.userId == userId &&
                lu.latitude == 48.1351 &&
                lu.longitude == 11.5820 &&
                lu.locationType == "driver" &&
                lu.companyId == testCompanyId
            )
          }
        }.provide(EventHub.layer)
      )
    )
}
