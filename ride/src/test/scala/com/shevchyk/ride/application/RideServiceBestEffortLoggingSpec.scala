package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  AuditService,
  DriverAvailabilityChecker,
  EmailSmsService,
  EventHub,
  GeocodingService,
  InMemoryAuditService,
  InvoiceEmailData,
  RideConfirmationData,
  ScheduleDayLookup,
  UnavailabilitySlot
}
import com.shevchyk.core.repository.{BlacklistRepository, PersonRepository, SentConfirmationRequestRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{PickupTimeService, RideService}
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository, InMemoryRideShareTokenRepository}
import com.shevchyk.ride.repository.helpers.{InMemoryExternalDriverRepository, InMemoryPartnerCompanyRepository}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

/**
 * Regression coverage for the "silent best-effort" audit findings: side-effects around a ride operation (WebSocket
 * event publication, confirmation-dedup cleanup) are fire-and-forget, but their failures must be VISIBLE — a bare
 * `.ignore` (or a discarded `publish == false`) hid them completely.
 *
 * Asserts both halves of the contract: the ride operation still succeeds when the side-effect fails (best-effort stays
 * best-effort) AND a warning is logged (failures become visible).
 */
object RideServiceBestEffortLoggingSpec extends ZIOSpecDefault {

  private val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  private val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))

  private val testClient = Person(
    id = testClientId,
    name = "Test Client",
    email = "test-client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  private val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "test-driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  private val testPersonRepo: PersonRepository =
    new PersonRepository {
      private val persons                                                                                             = Map(testClientId -> testClient, testDriverId -> testDriver)
      override def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      override def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(persons.get(id))
      override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.succeed(
        persons.get(id).filter(_.companyId.contains(companyId))
      )
      override def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.succeed(persons.values.find(_.email == email))
      override def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]                   = ZIO.succeed(Nil)
      override def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                          = ZIO.succeed(Nil)
      override def findAll(): Task[List[Person]]                                                                      = ZIO.succeed(persons.values.toList)
      override def update(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      override def delete(id: PersonId): Task[Unit]                                                                   = ZIO.unit
      override def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                                    = ZIO.unit
      override def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(Nil)
      override def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      override def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
      override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      override def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      override def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] =
        ZIO.unit
      override def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
    }

  private val noopEmail: EmailSmsService =
    new EmailSmsService {
      override def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
      override def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
      override def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit]         = ZIO.unit
    }

  private val noopAvailabilityChecker: DriverAvailabilityChecker =
    new DriverAvailabilityChecker {
      override def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
    }

  private val noopScheduleDayLookup: ScheduleDayLookup = _ => ZIO.none

  /**
   * An EventHub that is effectively shut down: publish reports the event was NOT delivered.
   */
  private val closedEventHub: EventHub =
    new EventHub {
      override def publish(event: WebSocketEvent): UIO[Boolean]            = ZIO.succeed(false)
      override def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] = ZIO.die(
        new NotImplementedError("not used in this spec")
      )
    }

  /**
   * A confirmation-dedup repository whose cleanup always fails (e.g. the DB is briefly down).
   */
  private val failingClearRepo: SentConfirmationRequestRepository =
    new SentConfirmationRequestRepository {
      override def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean] = ZIO.succeed(false)
      override def markSent(rideId: RideId, personId: PersonId): Task[Unit]         = ZIO.unit
      override def markSentIfNew(rideId: RideId, personId: PersonId): Task[Boolean] = ZIO.succeed(true)
      override def clear(rideId: RideId): Task[Unit]                                = ZIO.fail(
        new RuntimeException("dedup table unavailable")
      )
    }

  private val baseLayers =
    ZLayer.succeed[PersonRepository](testPersonRepo) ++
      InMemoryRideRepository.layer ++
      ZLayer.succeed[EventHub](closedEventHub) ++
      ZLayer.succeed(noopAvailabilityChecker) ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++
      ExpenseRepository.inMemory ++
      PickupTimeService.noopLayer ++
      ZLayer.succeed(noopScheduleDayLookup) ++
      ZLayer.succeed[AuditService](new InMemoryAuditService) ++
      ZLayer.succeed[EmailSmsService](noopEmail) ++
      InMemoryExternalDriverRepository.layer ++
      InMemoryPartnerCompanyRepository.layer ++
      ZLayer.succeed[SentConfirmationRequestRepository](failingClearRepo) ++
      InMemoryRideShareTokenRepository.layer

  private val fullLayers = baseLayers >+> RideService.layer

  private def request() = CreateRideRequest(
    clientId = testClientId,
    companyId = testCompanyId,
    pickupLocation = Location("Marienplatz 1"),
    dropoffLocation = Location("Flughafen MUC"),
    scheduledTime = None,
    estimatedPrice = Some(BigDecimal("42.50"))
  )

  override def spec =
    suite("RideService best-effort side-effects are logged, not swallowed")(
      test("createRide succeeds when the event hub drops the event AND logs a warning naming the event") {
        for {
          svc     <- ZIO.service[RideService]
          ride    <- svc.createRide(request())
          logs    <- ZTestLogger.logOutput
          warnings = logs.filter(_.logLevel == LogLevel.Warning).map(_.message())
        } yield assertTrue(
          ride.status == RideStatus.Requested,
          warnings.exists(m => m.contains("RideCreated") && m.contains("not published"))
        )
      },
      test("confirmRide succeeds when the dedup cleanup fails AND logs a warning") {
        for {
          svc       <- ZIO.service[RideService]
          ride      <- svc.createRide(request())
          assigned  <- svc.assignDriver(ride.id, testDriverId)
          confirmed <- svc.confirmRide(ride.id, testDriverId)
          logs      <- ZTestLogger.logOutput
          warnings   = logs.filter(_.logLevel == LogLevel.Warning).map(_.message())
        } yield assertTrue(
          assigned.status == RideStatus.Assigned,
          confirmed.status == RideStatus.Confirmed,
          warnings.exists(_.contains("Failed to clear confirmation-request dedup"))
        )
      }
    ).provideSomeShared[Any](fullLayers) @@ TestAspect.sequential
}
