package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.notification.repository.{
  CheckpointNotificationRepository,
  InMemoryCheckpointNotificationRepository,
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository
}
import zio.*
import zio.test.*
import zio.test.TestClock

import java.util.UUID

object PushNotificationListenerSpec extends ZIOSpecDefault {

  private val companyId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val driverId  = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val rideId    = UUID.fromString("00000003-0000-0000-0000-000000000003")
  private val clientId  = UUID.fromString("00000004-0000-0000-0000-000000000004")

  private val testFcmLayer: ZLayer[Any, Nothing, FcmService] =
    InMemoryFcmTokenRepository.layer >>> FcmServiceSpec.testFcmServiceLayer

  private val baseLayers =
    EventHub.layer ++
      InMemoryNotificationRepository.layer ++
      testFcmLayer ++
      InMemoryCheckpointNotificationRepository.layer

  // Publish event, advance clock by 200ms, read notifications for one person.
  private def publishAndCollect(
      event: WebSocketEvent,
      forPerson: PersonId
  ): ZIO[EventHub & FcmService & NotificationRepository & CheckpointNotificationRepository & Scope, Throwable, List[com.shevchyk.notification.domain.AppNotification]] =
    for {
      _         <- PushNotificationListener.start
      eventHub  <- ZIO.service[EventHub]
      notifRepo <- ZIO.service[NotificationRepository]
      _         <- eventHub.publish(event)
      _         <- TestClock.adjust(200.millis)
      notifs    <- notifRepo.findByPersonId(forPerson, limit = 10, offset = 0)
    } yield notifs

  def spec =
    suite("PushNotificationListener")(
      test("RideAssigned saves notification for driver") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideAssigned(rideId, driverId, clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(
              notifs.nonEmpty &&
                notifs.exists(_.notificationType == "ride_assigned") &&
                notifs.exists(_.title == "New Ride Assigned")
            )
          }
        }
      }.provide(baseLayers),
      test("RideAssigned also notifies the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideAssigned(rideId, driverId, clientId, companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_assigned") &&
                notifs.exists(_.title == "Driver Assigned")
            )
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged InProgress saves Ride Started notification for driver") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "InProgress", Some(driverId), clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_status_changed") &&
                notifs.exists(_.title == "Ride Started")
            )
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged InProgress also notifies the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "InProgress", Some(driverId), clientId, companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(notifs.exists(_.title == "Ride Started"))
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged Completed saves Ride Completed notification") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "Completed", Some(driverId), clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(notifs.exists(_.title == "Ride Completed"))
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged Cancelled notifies the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "Cancelled", Some(driverId), clientId, companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_status_changed") &&
                notifs.exists(_.title == "Ride Cancelled")
            )
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged Cancelled notifies the assigned driver") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "Cancelled", Some(driverId), clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(notifs.exists(_.title == "Ride Cancelled"))
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged with unknown status saves no notification") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "Assigned", Some(driverId), clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(notifs.isEmpty)
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged with no driverId still notifies the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "InProgress", None, clientId, companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(notifs.exists(_.title == "Ride Started"))
          }
        }
      }.provide(baseLayers),
      test("RideCreated sends the client a booking confirmation") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideCreated(rideId, clientId, companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_created") &&
                notifs.exists(_.title == "Ride Booked")
            )
          }
        }
      }.provide(baseLayers),
      test("LocationUpdated event produces no notification") {
        ZIO.scoped {
          val userId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.LocationUpdated(Some(rideId), userId, 48.1, 11.5, "driver", companyId),
            PersonId(userId)
          ).map(notifs => assertTrue(notifs.isEmpty))
        }
      }.provide(baseLayers),
      test("ChatMessageSent event produces no notification") {
        ZIO.scoped {
          val senderId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.ChatMessageSent(rideId, senderId, "Hello!", companyId),
            PersonId(senderId)
          ).map(notifs => assertTrue(notifs.isEmpty))
        }
      }.provide(baseLayers),
      test("GeofenceTriggered event produces no notification") {
        ZIO.scoped {
          val geofenceId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.GeofenceTriggered(geofenceId, "Zone A", driverId, "entry", 48.1, 11.5, companyId),
            PersonId(driverId)
          ).map(notifs => assertTrue(notifs.isEmpty))
        }
      }.provide(baseLayers),
      test("DriverApproaching notifies the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.DriverApproaching(rideId, driverId, clientId, 450, "500m", companyId),
            PersonId(clientId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "driver_approaching") &&
                notifs.exists(_.title == "Driver Approaching")
            )
          }
        }
      }.provide(baseLayers),

      // -- AirportCheckpointReached tests ------------------------------------

      test("AirportCheckpointReached notifies driver with correct notificationType and checkpointName in data") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.AirportCheckpointReached(rideId, driverId, clientId, "landed", "Landed", companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "airport_checkpoint"),
              notifs.exists(_.title == "Client at Landed"),
              notifs.exists(n => n.data.exists(_.contains("checkpointName")))
            )
          }
        }
      }.provide(baseLayers),

      test("AirportCheckpointReached does NOT send duplicate push when same checkpointType sent twice") {
        ZIO.scoped {
          for {
            _             <- PushNotificationListener.start
            eventHub      <- ZIO.service[EventHub]
            notifRepo     <- ZIO.service[com.shevchyk.notification.repository.NotificationRepository]
            checkpointRepo <- ZIO.service[com.shevchyk.notification.repository.CheckpointNotificationRepository]
            event          = WebSocketEvent.AirportCheckpointReached(rideId, driverId, clientId, "landed", "Landed", companyId)
            _             <- eventHub.publish(event)
            _             <- TestClock.adjust(200.millis)
            _             <- eventHub.publish(event)
            _             <- TestClock.adjust(200.millis)
            notifs        <- notifRepo.findByPersonId(PersonId(driverId), limit = 10, offset = 0)
          } yield assertTrue(
            notifs.count(_.notificationType == "airport_checkpoint") == 1
          )
        }
      }.provide(baseLayers),

      test("AirportCheckpointReached sends separate push for different checkpointType") {
        ZIO.scoped {
          for {
            _              <- PushNotificationListener.start
            eventHub       <- ZIO.service[EventHub]
            notifRepo      <- ZIO.service[com.shevchyk.notification.repository.NotificationRepository]
            _              <- eventHub.publish(
                                WebSocketEvent.AirportCheckpointReached(rideId, driverId, clientId, "landed", "Landed", companyId)
                              )
            _              <- TestClock.adjust(200.millis)
            _              <- eventHub.publish(
                                WebSocketEvent.AirportCheckpointReached(
                                  rideId,
                                  driverId,
                                  clientId,
                                  "terminal_exit",
                                  "Terminal Exit",
                                  companyId
                                )
                              )
            _              <- TestClock.adjust(200.millis)
            notifs         <- notifRepo.findByPersonId(PersonId(driverId), limit = 10, offset = 0)
          } yield assertTrue(
            notifs.count(_.notificationType == "airport_checkpoint") == 2
          )
        }
      }.provide(baseLayers),

      test("skip-ahead: single AirportCheckpointReached(terminal_exit) produces exactly one push for terminal_exit only") {
        ZIO.scoped {
          publishAndCollect(
            // This is what AirportCheckpointService emits on a None → TerminalExit skip-ahead call:
            // exactly one event for the final checkpoint only.
            WebSocketEvent.AirportCheckpointReached(
              rideId,
              driverId,
              clientId,
              "terminal_exit",
              "Terminal Exit",
              companyId
            ),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(
              notifs.count(_.notificationType == "airport_checkpoint") == 1,
              notifs.exists(n => n.data.exists(_.contains("terminal_exit"))),
              !notifs.exists(n => n.data.exists(d => d.contains("\"landed\"") || d.contains("\"arrivals_hall\"")))
            )
          }
        }
      }.provide(baseLayers)
    )
}
