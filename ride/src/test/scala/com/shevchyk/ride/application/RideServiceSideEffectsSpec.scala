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
 * Verifies the side-effects createRide fires after persistence — the WebSocket RideCreated event, the audit-log entry,
 * and the ride-confirmation email payload — plus the clock-skew boundary of the pickup-in-the-past check.
 *
 * These paths are fire-and-forget in production (`.ignore`), so a wrong id or a swapped address would go unnoticed
 * without an explicit assertion. The email test also pins the currently hard-coded clientName = "Client" (see
 * RideService.createRide) as a documented, suspicious value.
 */
object RideServiceSideEffectsSpec extends ZIOSpecDefault {

  private val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))

  private val testClient = Person(
    id = testClientId,
    name = "Test Client",
    email = "test-client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  /**
   * Minimal in-module PersonRepository holding just the one client createRide needs.
   */
  private val testPersonRepo: PersonRepository =
    new PersonRepository {
      private val persons                                                                                             = Map(testClientId -> testClient)
      override def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      override def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(persons.get(id))
      override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.succeed(
        persons.get(id).filter(_.companyId.contains(companyId))
      )
      override def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.succeed(persons.values.find(_.email == email))
      override def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(
        persons.values.filter(_.role == role).toList
      )
      override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]                   = ZIO.succeed(
        persons.values.filter(p => p.hasRole(role) && p.companyId.contains(companyId)).toList
      )
      override def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                          = ZIO.succeed(
        persons.values.filter(_.companyId.contains(companyId)).toList
      )
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

  /**
   * EmailSmsService double that captures every ride-confirmation payload.
   */
  final private class CapturingEmailSmsService(val confirmations: Ref[List[RideConfirmationData]])
      extends EmailSmsService {
    override def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = confirmations.update(_ :+ data)
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

  // The same concrete instances back both the RideService dependency (AuditService /
  // EmailSmsService) and the test's read-back (InMemoryAuditService /
  // CapturingEmailSmsService), so assertions see exactly what createRide produced.
  // Each instance is published under its concrete type and then re-exposed under the
  // trait the service depends on, keeping the Tags simple (no intersection types).
  private val auditConcrete: ULayer[InMemoryAuditService] = ZLayer.succeed(new InMemoryAuditService)

  private val auditAsService: URLayer[InMemoryAuditService, AuditService] = ZLayer.fromFunction(
    (a: InMemoryAuditService) => a: AuditService
  )

  private val emailConcrete: ULayer[CapturingEmailSmsService] = ZLayer.fromZIO(
    Ref.make(List.empty[RideConfirmationData]).map(new CapturingEmailSmsService(_))
  )

  private val emailAsService: URLayer[CapturingEmailSmsService, EmailSmsService] = ZLayer.fromFunction(
    (e: CapturingEmailSmsService) => e: EmailSmsService
  )

  private val baseLayers =
    ZLayer.succeed[PersonRepository](testPersonRepo) ++
      InMemoryRideRepository.layer ++
      EventHub.layer ++
      ZLayer.succeed(noopAvailabilityChecker) ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++
      ExpenseRepository.inMemory ++
      PickupTimeService.noopLayer ++
      ZLayer.succeed(noopScheduleDayLookup) ++
      auditConcrete ++ (auditConcrete >>> auditAsService) ++
      emailConcrete ++ (emailConcrete >>> emailAsService) ++
      InMemoryExternalDriverRepository.layer ++
      InMemoryPartnerCompanyRepository.layer ++
      SentConfirmationRequestRepository.inMemory ++
      InMemoryRideShareTokenRepository.layer

  private val fullLayers = baseLayers >+> RideService.layer

  private def request(
      pickup: String = "Marienplatz 1",
      dropoff: String = "Flughafen MUC",
      scheduled: Option[Instant] = None
  ) = CreateRideRequest(
    clientId = testClientId,
    companyId = testCompanyId,
    pickupLocation = Location(pickup),
    dropoffLocation = Location(dropoff),
    scheduledTime = scheduled,
    estimatedPrice = Some(BigDecimal("42.50"))
  )

  override def spec = suite("RideService.createRide side-effects")(
    test("publishes a RideCreated WebSocket event with the persisted ids") {
      for {
        hub        <- ZIO.service[EventHub]
        result     <- ZIO.scoped {
                        for {
                          sub  <- hub.subscribe
                          svc  <- ZIO.service[RideService]
                          ride <- svc.createRide(request())
                          // The EventHub is shared across the suite and tests run
                          // concurrently, so skip any events from sibling tests and
                          // keep taking until this ride's own RideCreated arrives.
                          evt  <- sub.take.repeatUntil {
                                    case WebSocketEvent.RideCreated(rideId, _, _, _) => rideId == ride.id.value
                                    case _                                           => false
                                  }
                        } yield (ride, evt)
                      }
        (ride, evt) = result
      } yield assertTrue(
        evt match {
          case WebSocketEvent.RideCreated(rideId, clientId, companyId, _) =>
            rideId == ride.id.value &&
            clientId == ride.clientId.value &&
            companyId == ride.companyId.value
          case _                                                          => false
        }
      )
    },
    test("writes an audit-log entry tying the actor (client) to the new ride") {
      for {
        svc     <- ZIO.service[RideService]
        audit   <- ZIO.service[InMemoryAuditService]
        ride    <- svc.createRide(request())
        entries <- audit.findByEntity("ride", ride.id.value)
      } yield assertTrue(
        entries.size == 1 &&
          entries.head.action == AuditAction.RideCreated &&
          entries.head.actorId == ride.clientId &&
          entries.head.companyId == ride.companyId &&
          entries.head.entityId == ride.id.value
      )
    },
    test("sends a ride-confirmation email carrying the ride addresses and price") {
      for {
        svc   <- ZIO.service[RideService]
        email <- ZIO.service[CapturingEmailSmsService]
        ride  <- svc.createRide(request(pickup = "Marienplatz 1", dropoff = "Flughafen MUC"))
        sent  <- email.confirmations.get
        // The layer is shared across the suite, so locate this ride's confirmation
        // by id rather than asserting on the accumulated list size.
        mine   = sent.filter(_.rideId == ride.id.value.toString)
      } yield assertTrue(
        mine.size == 1 &&
          mine.head.pickupAddress == "Marienplatz 1" &&
          mine.head.dropoffAddress == "Flughafen MUC" &&
          mine.head.estimatedPrice.contains(BigDecimal("42.50")) &&
          // Documents the current hard-coded value — update this assertion when the
          // real client name is wired through (see RideService.createRide ~line 255).
          mine.head.clientName == "Client"
      )
    },
    test("accepts a pickup time inside the clock-skew tolerance (now - 200s)") {
      // RidePolicy.isInThePast compares against wall-clock Instant.now(), so use the
      // real clock here rather than ZIO's TestClock (which starts at the epoch).
      for {
        svc  <- ZIO.service[RideService]
        now  <- ZIO.succeed(Instant.now())
        exit <- svc.createRide(request(scheduled = Some(now.minusSeconds(200)))).exit
      } yield assertTrue(exit.isSuccess)
    },
    test("rejects a pickup time well in the past (now - 3600s)") {
      for {
        svc    <- ZIO.service[RideService]
        now    <- ZIO.succeed(Instant.now())
        result <- svc.createRide(request(scheduled = Some(now.minusSeconds(3600)))).exit
      } yield assertTrue(result match {
        case Exit.Failure(cause) =>
          cause.failureOption.exists {
            case RideError.ValidationError(msg) => msg.contains("future")
            case _                              => false
          }
        case _                   => false
      })
    }
  ).provideSomeShared[Any](fullLayers)
}
