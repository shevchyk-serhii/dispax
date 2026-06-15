package com.shevchyk.notification.application

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.notification.repository.{
  InMemoryFcmTokenRepository,
  InMemoryNotificationRepository,
  NotificationRepository
}
import zio.*
import zio.test.*
import zio.test.TestClock

import java.time.Instant
import java.util.UUID

object PushNotificationListenerSpec extends ZIOSpecDefault {

  private val companyId   = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val driverId    = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val rideId      = UUID.fromString("00000003-0000-0000-0000-000000000003")
  private val clientId    = UUID.fromString("00000004-0000-0000-0000-000000000004")
  private val dispatcherId = UUID.fromString("00000005-0000-0000-0000-000000000005")

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

  private val personRepoStub: PersonRepository =
    new PersonRepository:
      def findByRoleAndCompany(role: PersonRole, company: CompanyId): Task[List[Person]] =
        ZIO.succeed(
          if role == PersonRole.Dispatcher && company == CompanyId(companyId) then List(dispatcher) else Nil
        )
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected PersonRepository.$m")
      def create(person: Person): Task[Person]                           = nope("create")
      def findById(id: PersonId): Task[Option[Person]]                   = nope("findById")
      def findByEmail(email: String): Task[Option[Person]]               = nope("findByEmail")
      def findByRole(role: PersonRole): Task[List[Person]]               = nope("findByRole")
      def findByCompanyId(company: CompanyId): Task[List[Person]]        = nope("findByCompanyId")
      def findAll(): Task[List[Person]]                                  = nope("findAll")
      def update(person: Person): Task[Person]                           = nope("update")
      def delete(id: PersonId): Task[Unit]                               = nope("delete")
      def findByStatus(status: UserStatus): Task[List[Person]]           = nope("findByStatus")
      def searchByQuery(query: String): Task[List[Person]]               = nope("searchByQuery")
      def updateLastLogin(id: PersonId): Task[Unit]                      = nope("updateLastLogin")
      def findByClientCompany(c: ClientCompanyId): Task[List[Person]]    = nope("findByClientCompany")

  private val baseLayers =
    EventHub.layer ++
      InMemoryNotificationRepository.layer ++
      testFcmLayer ++
      ZLayer.succeed(personRepoStub)

  // Publish event, advance clock by 200ms, read notifications for one person.
  private def publishAndCollect(
      event: WebSocketEvent,
      forPerson: PersonId
  ): ZIO[EventHub & FcmService & NotificationRepository & PersonRepository & Scope, Throwable, List[com.shevchyk.notification.domain.AppNotification]] =
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
      }.provide(baseLayers)
    )
}
