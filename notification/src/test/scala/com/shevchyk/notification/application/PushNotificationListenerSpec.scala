package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
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

  private val companyId         = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val driverId          = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val rideId            = UUID.fromString("00000003-0000-0000-0000-000000000003")
  private val clientId          = UUID.fromString("00000004-0000-0000-0000-000000000004")
  private val dispatcherId      = UUID.fromString("00000005-0000-0000-0000-000000000005")
  private val otherCompanyId    = UUID.fromString("00000009-0000-0000-0000-000000000009")
  private val otherDispatcherId = UUID.fromString("00000010-0000-0000-0000-000000000010")

  private val testFcmLayer: ZLayer[Any, Nothing, FcmService] =
    InMemoryFcmTokenRepository.layer >>> FcmServiceSpec.testFcmServiceLayer

  // PersonRepository stub: only findByRoleAndCompany is exercised (to resolve a
  // company's dispatchers for EtaAtRisk alerts). One dispatcher in `companyId`.
  private val dispatcher = Person(
    id = PersonId(dispatcherId),
    name = "Dispatcher",
    email = "dispatcher@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(CompanyId(companyId))
  )

  private val otherDispatcher = Person(
    id = PersonId(otherDispatcherId),
    name = "Other Dispatcher",
    email = "other-dispatcher@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(CompanyId(otherCompanyId))
  )

  private val personRepoStub: PersonRepository =
    new PersonRepository:
      def findByRoleAndCompany(role: PersonRole, company: CompanyId): Task[List[Person]]                     = ZIO.succeed(
        if role == PersonRole.Dispatcher && company == CompanyId(companyId) then List(dispatcher)
        else if role == PersonRole.Dispatcher && company == CompanyId(otherCompanyId) then List(otherDispatcher)
        else Nil
      )
      private def nope(m: String): Nothing                                                                   = throw new NotImplementedError(s"unexpected PersonRepository.$m")
      def create(person: Person): Task[Person]                                                               = nope("create")
      def findById(id: PersonId): Task[Option[Person]]                                                       = nope("findById")
      def findByIdAndCompany(id: PersonId, company: CompanyId): Task[Option[Person]]                         = nope("findByIdAndCompany")
      def findByEmail(email: String): Task[Option[Person]]                                                   = nope("findByEmail")
      def findByRole(role: PersonRole): Task[List[Person]]                                                   = nope("findByRole")
      def findByCompanyId(company: CompanyId): Task[List[Person]]                                            = nope("findByCompanyId")
      def findAll(): Task[List[Person]]                                                                      = nope("findAll")
      def update(person: Person): Task[Person]                                                               = nope("update")
      def delete(id: PersonId): Task[Unit]                                                                   = nope("delete")
      def deleteInCompany(id: PersonId, companyId: com.shevchyk.core.domain.CompanyId): Task[Unit]           = nope(
        "deleteInCompany"
      )
      def findByStatus(status: UserStatus): Task[List[Person]]                                               = nope("findByStatus")
      def searchByQuery(query: String): Task[List[Person]]                                                   = nope("searchByQuery")
      def updateLastLogin(id: PersonId): Task[Unit]                                                          = nope("updateLastLogin")
      def findByClientCompany(c: ClientCompanyId): Task[List[Person]]                                        = nope("findByClientCompany")
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit

  private val baseLayers =
    EventHub.layer ++
      InMemoryNotificationRepository.layer ++
      testFcmLayer ++
      ZLayer.succeed(personRepoStub) ++
      InMemoryCheckpointNotificationRepository.layer

  // Publish event, advance clock by 200ms, read notifications for one person.
  private def publishAndCollect(
      event: WebSocketEvent,
      forPerson: PersonId
  ): ZIO[
    EventHub & FcmService & NotificationRepository & PersonRepository & CheckpointNotificationRepository & Scope,
    Throwable,
    List[com.shevchyk.notification.domain.AppNotification]
  ] =
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
      test("GeofenceTriggered alerts the company's dispatcher") {
        ZIO.scoped {
          val geofenceId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.GeofenceTriggered(geofenceId, "Zone A", driverId, "entry", 48.1, 11.5, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "geofence") &&
                notifs.exists(_.title == "Geofence alert") &&
                notifs.exists(n => n.data.exists(_.contains("Zone A")))
            )
          }
        }
      }.provide(baseLayers),
      test("GeofenceTriggered does not alert the driver who triggered it") {
        ZIO.scoped {
          val geofenceId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.GeofenceTriggered(geofenceId, "Zone A", driverId, "entry", 48.1, 11.5, companyId),
            PersonId(driverId)
          ).map(notifs => assertTrue(notifs.isEmpty))
        }
      }.provide(baseLayers),
      test("[TENANT ISOLATION] GeofenceTriggered for another company does not alert this company's dispatcher") {
        val otherCompany = UUID.fromString("00000066-0000-0000-0000-000000000066")
        ZIO.scoped {
          val geofenceId = UUID.randomUUID()
          publishAndCollect(
            WebSocketEvent.GeofenceTriggered(geofenceId, "Zone A", driverId, "entry", 48.1, 11.5, otherCompany),
            PersonId(dispatcherId)
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
      test("EtaAtRisk alerts the company's dispatcher") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 20, 10, -10, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "eta_at_risk") &&
                notifs.exists(_.title == "Ride at risk of delay")
            )
          }
        }
      }.provide(baseLayers),
      test("EtaAtRisk does not alert the client") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 20, 10, -10, companyId),
            PersonId(clientId)
          ).map(notifs => assertTrue(notifs.isEmpty))
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
            _              <- PushNotificationListener.start
            eventHub       <- ZIO.service[EventHub]
            notifRepo      <- ZIO.service[com.shevchyk.notification.repository.NotificationRepository]
            checkpointRepo <- ZIO.service[com.shevchyk.notification.repository.CheckpointNotificationRepository]
            event           = WebSocketEvent.AirportCheckpointReached(rideId, driverId, clientId, "landed", "Landed", companyId)
            _              <- eventHub.publish(event)
            _              <- TestClock.adjust(200.millis)
            _              <- eventHub.publish(event)
            _              <- TestClock.adjust(200.millis)
            notifs         <- notifRepo.findByPersonId(PersonId(driverId), limit = 10, offset = 0)
          } yield assertTrue(
            notifs.count(_.notificationType == "airport_checkpoint") == 1
          )
        }
      }.provide(baseLayers),
      test("AirportCheckpointReached sends separate push for different checkpointType") {
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[com.shevchyk.notification.repository.NotificationRepository]
            _         <- eventHub.publish(
                           WebSocketEvent.AirportCheckpointReached(rideId, driverId, clientId, "landed", "Landed", companyId)
                         )
            _         <- TestClock.adjust(200.millis)
            _         <- eventHub.publish(
                           WebSocketEvent.AirportCheckpointReached(
                             rideId,
                             driverId,
                             clientId,
                             "terminal_exit",
                             "Terminal Exit",
                             companyId
                           )
                         )
            _         <- TestClock.adjust(200.millis)
            notifs    <- notifRepo.findByPersonId(PersonId(driverId), limit = 10, offset = 0)
          } yield assertTrue(
            notifs.count(_.notificationType == "airport_checkpoint") == 2
          )
        }
      }.provide(baseLayers),
      test(
        "skip-ahead: single AirportCheckpointReached(terminal_exit) produces exactly one push for terminal_exit only"
      ) {
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
      }.provide(baseLayers),

      // -- EtaAtRisk branch coverage -------------------------------------------

      test("EtaAtRisk with slackMinutes < 0 body contains 'min late'") {
        // slackMinutes = -5 → lateBy = 5 → body: "Driver is ~5 min late …"
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 20, 15, -5, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            val body = notifs.find(_.notificationType == "eta_at_risk").map(_.body).getOrElse("")
            assertTrue(body.contains("min late"))
          }
        }
      }.provide(baseLayers),
      test("EtaAtRisk with slackMinutes >= 0 body contains 'Tight pickup' and not 'late'") {
        // slackMinutes = 3 → body: "Tight pickup: ETA …"
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 10, 13, 3, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            val body = notifs.find(_.notificationType == "eta_at_risk").map(_.body).getOrElse("")
            assertTrue(body.contains("Tight pickup"), !body.contains("late"))
          }
        }
      }.provide(baseLayers),
      test("EtaAtRisk with zero dispatchers in company saves nothing") {
        // Publish an EtaAtRisk for a company that has no dispatchers.
        // personRepoStub returns Nil for any company != companyId.
        val otherCompany = UUID.fromString("00000099-0000-0000-0000-000000000099")
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            _         <- eventHub.publish(
                           WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 20, 10, -5, otherCompany)
                         )
            _         <- TestClock.adjust(200.millis)
            // dispatcherId belongs to companyId, not otherCompany — no notifications expected
            notifs    <- notifRepo.findByPersonId(PersonId(dispatcherId), limit = 10, offset = 0)
          } yield assertTrue(notifs.isEmpty)
        }
      }.provide(baseLayers),
      test("[TENANT ISOLATION - NEGATIVE] EtaAtRisk dispatcher of a different company receives no notification") {
        // personRepoStub only returns the dispatcher for companyId, not for otherCompany.
        // This is the sole fan-out path in PushNotificationListener that resolves recipients
        // by CompanyId (findByRoleAndCompany). All other events carry explicit IDs from the event.
        val otherCompany    = UUID.fromString("00000088-0000-0000-0000-000000000088")
        val otherDispatcher = UUID.fromString("00000077-0000-0000-0000-000000000077")
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            // Publish for otherCompany; personRepoStub returns Nil for it
            _         <- eventHub.publish(
                           WebSocketEvent.EtaAtRisk(rideId, driverId, clientId, 20, 10, -5, otherCompany)
                         )
            _         <- TestClock.adjust(200.millis)
            // The dispatcher of the correct companyId must NOT receive a cross-tenant alert
            notifs    <- notifRepo.findByPersonId(PersonId(dispatcherId), limit = 10, offset = 0)
            // The hypothetical dispatcher of otherCompany is also not notified (not in repo)
            other     <- notifRepo.findByPersonId(PersonId(otherDispatcher), limit = 10, offset = 0)
          } yield assertTrue(notifs.isEmpty, other.isEmpty)
        }
      }.provide(baseLayers),
      test("daemon fiber resilience: save fails on first event but succeeds on second") {
        // A FailOnceNotificationRepository that rejects the first save, then delegates normally.
        // This tests that .catchAll inside start keeps .forever alive after a transient error.
        // We wire everything through a single ZIO.provide so the Hub instance is shared.
        for {
          failCount                        <- Ref.make(0)
          innerRepo                         = new InMemoryNotificationRepository
          flakyRepo: NotificationRepository =
            new NotificationRepository:
              def save(
                  n: com.shevchyk.notification.domain.AppNotification
              ): Task[com.shevchyk.notification.domain.AppNotification] = failCount.getAndUpdate(_ + 1).flatMap { c =>
                if c == 0 then ZIO.fail(new RuntimeException("flaky save"))
                else innerRepo.save(n)
              }
              def findByPersonId(pid: PersonId, limit: Int, offset: Int)                            = innerRepo.findByPersonId(pid, limit, offset)
              def markAsRead(id: com.shevchyk.notification.domain.AppNotificationId, pid: PersonId) = innerRepo
                .markAsRead(id, pid)
              def markAllAsRead(pid: PersonId)                                                      = innerRepo.markAllAsRead(pid)
              def countUnread(pid: PersonId)                                                        = innerRepo.countUnread(pid)
              def delete(id: com.shevchyk.notification.domain.AppNotificationId, pid: PersonId)     = innerRepo.delete(
                id,
                pid
              )
              def deleteAllForPerson(pid: PersonId)                                                 = innerRepo.deleteAllForPerson(pid)
          flakyLayers                       =
            EventHub.layer ++
              ZLayer.succeed[NotificationRepository](flakyRepo) ++
              testFcmLayer ++
              ZLayer.succeed(personRepoStub) ++
              InMemoryCheckpointNotificationRepository.layer
          result                           <- ZIO
                                                .scoped {
                                                  for {
                                                    _        <- PushNotificationListener.start
                                                    eventHub <- ZIO.service[EventHub]
                                                    notifRepo = flakyRepo
                                                    // First event → flaky save fails; .catchAll logs warning, .forever restarts
                                                    _        <- eventHub.publish(WebSocketEvent.RideCreated(rideId, clientId, companyId))
                                                    _        <- TestClock.adjust(200.millis)
                                                    // Second event → save succeeds
                                                    _        <- eventHub.publish(WebSocketEvent.RideCreated(rideId, clientId, companyId))
                                                    _        <- TestClock.adjust(200.millis)
                                                    notifs   <- notifRepo.findByPersonId(PersonId(clientId), limit = 10, offset = 0)
                                                  } yield assertTrue(notifs.size == 1)
                                                }
                                                .provide(flakyLayers)
        } yield result
      },
      // ── Dispatcher push on Cancelled / Completed (Plan item B) ──────────

      test("RideStatusChanged Cancelled notifies the company dispatcher") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(
              rideId,
              "Cancelled",
              Some(driverId),
              clientId,
              companyId,
              Some("client_request")
            ),
            PersonId(dispatcherId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_status_changed") &&
                notifs.exists(_.title == "Ride Cancelled")
            )
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged Cancelled dispatcher notification body contains cancellation reason") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(
              rideId,
              "Cancelled",
              Some(driverId),
              clientId,
              companyId,
              Some("weather_conditions")
            ),
            PersonId(dispatcherId)
          ).map { notifs =>
            val body = notifs.find(_.notificationType == "ride_status_changed").map(_.body).getOrElse("")
            assertTrue(body.contains("weather_conditions"))
          }
        }
      }.provide(baseLayers),
      test("RideStatusChanged Completed notifies the company dispatcher") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideStatusChanged(rideId, "Completed", Some(driverId), clientId, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_status_changed") &&
                notifs.exists(_.title == "Ride Completed")
            )
          }
        }
      }.provide(baseLayers),
      test("[DEDUP] dispatcher who is also the driver does not receive double push on Cancelled") {
        // Publish a Cancelled event where driverId == dispatcherId.
        // The listener must skip the dispatcher entry to avoid two pushes to the same person.
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            _         <- eventHub.publish(
                           // driverId set to dispatcherId so they are the same person
                           WebSocketEvent.RideStatusChanged(
                             rideId,
                             "Cancelled",
                             Some(dispatcherId),
                             clientId,
                             companyId,
                             Some("test")
                           )
                         )
            _         <- TestClock.adjust(200.millis)
            notifs    <- notifRepo.findByPersonId(PersonId(dispatcherId), limit = 10, offset = 0)
          } yield assertTrue(
            // Exactly one notification: from the driver branch (not doubled by the dispatcher branch)
            notifs.count(_.notificationType == "ride_status_changed") == 1
          )
        }
      }.provide(baseLayers),
      test("[DEDUP] dispatcher who is also the client does not receive double push on Cancelled") {
        // The client's push and the dispatcher's push would be to the same person — must be suppressed.
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            _         <- eventHub.publish(
                           // clientId set to dispatcherId so they are the same person
                           WebSocketEvent.RideStatusChanged(
                             rideId,
                             "Cancelled",
                             Some(driverId),
                             dispatcherId,
                             companyId,
                             Some("test")
                           )
                         )
            _         <- TestClock.adjust(200.millis)
            notifs    <- notifRepo.findByPersonId(PersonId(dispatcherId), limit = 10, offset = 0)
          } yield assertTrue(
            // Exactly one notification: from the client branch (not doubled by the dispatcher branch)
            notifs.count(_.notificationType == "ride_status_changed") == 1
          )
        }
      }.provide(baseLayers),
      test("[TENANT ISOLATION] dispatcher of a different company is NOT notified on Cancelled") {
        // personRepoStub returns otherDispatcher for otherCompanyId, and dispatcher for companyId.
        // The event targets companyId — so only dispatcher is resolved, not otherDispatcher.
        ZIO.scoped {
          for {
            _           <- PushNotificationListener.start
            eventHub    <- ZIO.service[EventHub]
            notifRepo   <- ZIO.service[NotificationRepository]
            _           <- eventHub.publish(
                             WebSocketEvent.RideStatusChanged(
                               rideId,
                               "Cancelled",
                               Some(driverId),
                               clientId,
                               companyId,
                               Some("tenant_test")
                             )
                           )
            _           <- TestClock.adjust(200.millis)
            // The other company's dispatcher must receive nothing
            otherNotifs <- notifRepo.findByPersonId(PersonId(otherDispatcherId), limit = 10, offset = 0)
          } yield assertTrue(otherNotifs.isEmpty)
        }
      }.provide(baseLayers),

      // ── RideDetailsUpdated push (Plan item C) ────────────────────────────

      test("RideDetailsUpdated notifies the assigned driver") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideDetailsUpdated(rideId, Some(driverId), clientId, companyId),
            PersonId(driverId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_updated") &&
                notifs.exists(_.title == "Ride Updated")
            )
          }
        }
      }.provide(baseLayers),
      test("RideDetailsUpdated notifies the company dispatcher") {
        ZIO.scoped {
          publishAndCollect(
            WebSocketEvent.RideDetailsUpdated(rideId, Some(driverId), clientId, companyId),
            PersonId(dispatcherId)
          ).map { notifs =>
            assertTrue(
              notifs.exists(_.notificationType == "ride_updated") &&
                notifs.exists(_.title == "Ride Updated")
            )
          }
        }
      }.provide(baseLayers),
      test("[DEDUP] dispatcher who is also the driver is not notified twice on RideDetailsUpdated") {
        ZIO.scoped {
          for {
            _         <- PushNotificationListener.start
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            _         <- eventHub.publish(
                           // driver is the dispatcher — same UUID
                           WebSocketEvent.RideDetailsUpdated(rideId, Some(dispatcherId), clientId, companyId)
                         )
            _         <- TestClock.adjust(200.millis)
            notifs    <- notifRepo.findByPersonId(PersonId(dispatcherId), limit = 10, offset = 0)
          } yield assertTrue(
            notifs.count(_.notificationType == "ride_updated") == 1
          )
        }
      }.provide(baseLayers),
      test("[TENANT ISOLATION] dispatcher of different company not notified on RideDetailsUpdated") {
        ZIO.scoped {
          for {
            _           <- PushNotificationListener.start
            eventHub    <- ZIO.service[EventHub]
            notifRepo   <- ZIO.service[NotificationRepository]
            _           <- eventHub.publish(
                             WebSocketEvent.RideDetailsUpdated(rideId, Some(driverId), clientId, companyId)
                           )
            _           <- TestClock.adjust(200.millis)
            otherNotifs <- notifRepo.findByPersonId(PersonId(otherDispatcherId), limit = 10, offset = 0)
          } yield assertTrue(otherNotifs.isEmpty)
        }
      }.provide(baseLayers),

      // ── lifecycle: existing test ─────────────────────────────────────────

      test("lifecycle: event published before start is not delivered; event after start is delivered") {
        // The Hub subscription is opened inside start; events published before start is called
        // are not buffered for late subscribers (Hub semantics: only current subscribers receive).
        // After `start` returns (subscribed.await has completed), the next event is delivered.
        ZIO.scoped {
          for {
            _         <- ZIO.service[EventHub] // ensure hub exists before publish
            eventHub  <- ZIO.service[EventHub]
            notifRepo <- ZIO.service[NotificationRepository]
            // Publish BEFORE start — listener is not subscribed yet
            _         <- eventHub.publish(WebSocketEvent.RideCreated(rideId, clientId, companyId))
            _         <- TestClock.adjust(200.millis)
            _         <- PushNotificationListener.start
            // Publish AFTER start — listener is now subscribed (subscribed.await guarantees it)
            _         <- eventHub.publish(WebSocketEvent.RideCreated(rideId, clientId, companyId))
            _         <- TestClock.adjust(200.millis)
            notifs    <- notifRepo.findByPersonId(PersonId(clientId), limit = 10, offset = 0)
          } yield assertTrue(notifs.size == 1)
        }
      }.provide(baseLayers)
    )
}
