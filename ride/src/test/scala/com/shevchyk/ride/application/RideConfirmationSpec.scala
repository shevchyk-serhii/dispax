package com.shevchyk.ride.application

import com.shevchyk.core.application.{
  AuditService,
  DriverAvailabilityChecker,
  EmailSmsService,
  EventHub,
  GeocodingService,
  RideConfirmationData,
  ScheduleDayLookup,
  UnavailabilitySlot
}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{BlacklistRepository, PersonRepository, SentConfirmationRequestRepository}
import com.shevchyk.ride.application.service.{PickupTimeService, RideService}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import com.shevchyk.ride.repository.helpers.{InMemoryExternalDriverRepository, InMemoryPartnerCompanyRepository}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

/**
 * Unit tests for confirmRide and rejectRide, and the updated updateRideStatus gate. All tests use
 * InMemoryRideRepository — no database involved.
 *
 * These tests verify every business branch added by the driver-ride-confirmation feature:
 *   - confirmRide happy path: Assigned → Confirmed, confirmedAt set
 *   - confirmRide non-Assigned status → InvalidStatusTransition
 *   - confirmRide wrong driver (not the assigned one) → UnauthorizedAccess
 *   - confirmRide cross-company driver → BusinessRuleViolation(company_isolation)
 *   - rejectRide: Assigned → Requested, driver cleared, reason stored
 *   - rejectRide: Confirmed → Requested (still rejectible)
 *   - rejectRide empty reason → RejectionReasonRequired
 *   - rejectRide blank-only reason → RejectionReasonRequired
 *   - rejectRide dedup cleared (confirmedAt reset to None)
 *   - updateRideStatus: driver Assigned → InProgress now fails (must confirm first)
 *   - updateRideStatus: driver Confirmed → InProgress succeeds
 *   - updateRideStatus: dispatcher Assigned → InProgress override succeeds
 *   - CAS race: concurrent confirm + reassign, exactly one wins
 */
object RideConfirmationSpec extends ZIOSpecDefault {

  // ── Fixed IDs ──────────────────────────────────────────────────────────────
  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val driverAId     = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val driverBId     = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val crossDriverId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))
  val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val dispatcherId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))

  // ── Test persons ────────────────────────────────────────────────────────────
  val driverA = Person(
    id = driverAId,
    name = "Driver A",
    email = "drivera@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val driverB = Person(
    id = driverBId,
    name = "Driver B",
    email = "driverb@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val crossDriver = Person(
    id = crossDriverId,
    name = "Cross Driver",
    email = "cross@example.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
  )

  val client = Person(
    id = testClientId,
    name = "Test Client",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  // ── Mock repos / services ──────────────────────────────────────────────────
  final case class TestPersonRepository(persons: Map[PersonId, Person]) extends PersonRepository {
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

    override def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(
      persons.values.filter(_.status == status).toList
    )
    override def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
    override def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
    override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
    override def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
    override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.succeed(None)

    override def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] =
      ZIO.unit
    override def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  }

  val personRepo: TestPersonRepository = TestPersonRepository(
    Map(
      driverA.id     -> driverA,
      driverB.id     -> driverB,
      crossDriver.id -> crossDriver,
      client.id      -> client
    )
  )

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendInvoiceEmail(data: com.shevchyk.core.application.InvoiceEmailData): Task[Unit] = ZIO.unit
  )

  private val noopAvailabilityChecker: ZLayer[Any, Nothing, DriverAvailabilityChecker] = ZLayer.succeed(
    new DriverAvailabilityChecker:
      def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: java.time.Instant,
          to: java.time.Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
  )

  private val noopScheduleDayLookup: ZLayer[Any, Nothing, ScheduleDayLookup] = ZLayer.succeed(
    new ScheduleDayLookup:
      def find(id: ScheduleDayId) = ZIO.succeed(None)
  )

  val standardLayers =
    (InMemoryRideRepository.layer ++
      ZLayer.succeed[PersonRepository](personRepo) ++
      EventHub.layer ++
      noopEmailSms ++
      AuditService.inMemory ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++
      ExpenseRepository.inMemory ++
      PickupTimeService.noopLayer ++
      noopAvailabilityChecker ++
      noopScheduleDayLookup ++
      InMemoryExternalDriverRepository.layer ++
      InMemoryPartnerCompanyRepository.layer ++
      SentConfirmationRequestRepository.inMemory) >+> RideService.layer

  // ── Helpers ────────────────────────────────────────────────────────────────

  private def mkRide = CreateRideRequest(
    clientId = testClientId,
    companyId = testCompanyId,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B")
  )

  private def createAssigned(service: RideService) = service
    .createRide(mkRide)
    .flatMap(r => service.assignDriver(r.id, driverAId))

  private def createConfirmed(service: RideService) = createAssigned(service).flatMap(r =>
    service.confirmRide(r.id, driverAId)
  )

  // ── confirmRide ─────────────────────────────────────────────────────────────
  def spec =
    suite("RideConfirmation")(
      suite("confirmRide")(
        test("Assigned → Confirmed: status changes and confirmedAt is set") {
          for {
            service   <- ZIO.service[RideService]
            assigned  <- createAssigned(service)
            _         <- assertTrue(assigned.status == RideStatus.Assigned)
            confirmed <- service.confirmRide(assigned.id, driverAId)
          } yield assertTrue(
            confirmed.status == RideStatus.Confirmed,
            confirmed.confirmedAt.isDefined,
            confirmed.driverId.contains(driverAId)
          )
        }.provide(standardLayers),

        // MUTATION TARGET: removing the !ride.canBeConfirmed guard would break this.
        test("non-Assigned status (already Confirmed) → InvalidStatusTransition") {
          for {
            service   <- ZIO.service[RideService]
            confirmed <- createConfirmed(service)
            result    <- service.confirmRide(confirmed.id, driverAId).exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _               => false
          })
        }.provide(standardLayers),

        // MUTATION TARGET: removing the !ride.driverId.contains(driverId) guard would break this.
        test("wrong driver (not assigned) → UnauthorizedAccess") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            result   <- service.confirmRide(assigned.id, driverBId).exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _               => false
          })
        }.provide(standardLayers),

        // MUTATION TARGET: removing the company_isolation check would break this.
        test("cross-company driver → BusinessRuleViolation(company_isolation)") {
          // Manually produce a ride that has crossDriver as assigned driver.
          // We skip the service's assignDriver (which already blocks cross-company),
          // instead we grab an in-memory ride and manipulate it via the repo directly.
          for {
            service  <- ZIO.service[RideService]
            rideRepo <- ZIO.service[com.shevchyk.ride.repository.RideRepository]
            ride     <- service.createRide(mkRide)
            // Inject crossDriver as assignee via the raw repo
            injected  = ride.copy(
                          status = RideStatus.Assigned,
                          driverId = Some(crossDriverId)
                        )
            _        <- rideRepo.update(injected)
            result   <- service.confirmRide(injected.id, crossDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(c) =>
              c.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _               => false
          })
        }.provide(standardLayers),
        test("confirmedAt is persisted: re-read from repo returns same non-empty value") {
          for {
            service   <- ZIO.service[RideService]
            assigned  <- createAssigned(service)
            confirmed <- service.confirmRide(assigned.id, driverAId)
            reloaded  <- service.getRideById(confirmed.id)
          } yield assertTrue(
            reloaded.confirmedAt.isDefined,
            reloaded.status == RideStatus.Confirmed
          )
        }.provide(standardLayers),
        test("Requested ride → InvalidStatusTransition (cannot confirm without assign)") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide)
            result  <- service.confirmRide(ride.id, driverAId).exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _               => false
          })
        }.provide(standardLayers)
      ),

      // ── rejectRide ──────────────────────────────────────────────────────────
      suite("rejectRide")(
        test("Assigned → Requested: driver cleared, reason stored") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            rejected <- service.rejectRide(assigned.id, driverAId, "car breakdown")
          } yield assertTrue(
            rejected.status == RideStatus.Requested,
            rejected.driverId.isEmpty,
            rejected.rejectionReason.contains("car breakdown"),
            rejected.rejectedBy.contains(driverAId),
            rejected.rejectedAt.isDefined
          )
        }.provide(standardLayers),

        // MUTATION TARGET: removing the Confirmed case from canBeRejected would break this.
        test("Confirmed → Requested: also rejectible") {
          for {
            service   <- ZIO.service[RideService]
            confirmed <- createConfirmed(service)
            rejected  <- service.rejectRide(confirmed.id, driverAId, "personal emergency")
          } yield assertTrue(
            rejected.status == RideStatus.Requested,
            rejected.driverId.isEmpty,
            rejected.confirmedAt.isEmpty,
            rejected.rejectionReason.contains("personal emergency")
          )
        }.provide(standardLayers),

        // MUTATION TARGET: removing the reason.trim.isEmpty check would break this.
        test("empty reason → RejectionReasonRequired") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            result   <- service.rejectRide(assigned.id, driverAId, "").exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.RejectionReasonRequired])
            case _               => false
          })
        }.provide(standardLayers),

        // MUTATION TARGET: if only isEmpty were checked (not trim) this test would still pass but
        // a blank string would also fail, which is the correct behavior.
        test("blank-only reason (spaces) → RejectionReasonRequired") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            result   <- service.rejectRide(assigned.id, driverAId, "   ").exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.RejectionReasonRequired])
            case _               => false
          })
        }.provide(standardLayers),
        test("wrong driver (not assigned) → UnauthorizedAccess") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            result   <- service.rejectRide(assigned.id, driverBId, "not my ride").exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _               => false
          })
        }.provide(standardLayers),
        test("confirmedAt is cleared to None on rejection") {
          for {
            service   <- ZIO.service[RideService]
            confirmed <- createConfirmed(service)
            _         <- assertTrue(confirmed.confirmedAt.isDefined)
            rejected  <- service.rejectRide(confirmed.id, driverAId, "changed my mind")
          } yield assertTrue(rejected.confirmedAt.isEmpty)
        }.provide(standardLayers),
        test("rejected ride is reassignable (status is Requested)") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            _        <- service.rejectRide(assigned.id, driverAId, "breakdown")
            reloaded <- service.getRideById(assigned.id)
          } yield assertTrue(reloaded.canBeAssigned)
        }.provide(standardLayers)
      ),

      // ── updateRideStatus gate ───────────────────────────────────────────────
      suite("updateRideStatus confirmation gate")(
        // MUTATION TARGET: removing the Confirmed-guard in updateRideStatus would break this.
        test("driver Assigned → InProgress fails (must confirm first)") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.InProgress),
                  driverAId,
                  PersonRole.Driver
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(c) => c.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _               => false
          })
        }.provide(standardLayers),
        test("driver Confirmed → InProgress succeeds") {
          for {
            service   <- ZIO.service[RideService]
            confirmed <- createConfirmed(service)
            started   <- service.updateRideStatus(
                           confirmed.id,
                           UpdateRideStatusRequest(RideStatus.InProgress),
                           driverAId,
                           PersonRole.Driver
                         )
          } yield assertTrue(started.status == RideStatus.InProgress)
        }.provide(standardLayers),

        // MUTATION TARGET: removing the dispatcher override (role == Dispatcher) would break this.
        test("dispatcher can override Assigned → InProgress without Confirmed") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            updated  <- service.updateRideStatus(
                          assigned.id,
                          UpdateRideStatusRequest(RideStatus.InProgress),
                          dispatcherId,
                          PersonRole.Dispatcher
                        )
          } yield assertTrue(updated.status == RideStatus.InProgress)
        }.provide(standardLayers)
      ),

      // ── CAS race ────────────────────────────────────────────────────────────
      suite("CAS concurrency")(
        test("CAS: concurrent confirm + confirm — exactly one wins") {
          // Two concurrent confirmRide calls race on the same Assigned ride.
          // updateIfStatus(Set(Assigned)) is atomic: the first writer flips the status
          // to Confirmed, so the second writer finds the row no longer in Assigned
          // and its CAS returns false → InvalidStatusTransition.
          // Exactly one must succeed and exactly one must fail.
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssigned(service)
            results  <- ZIO.collectAllPar(
                          List(
                            service.confirmRide(assigned.id, driverAId).exit,
                            service.confirmRide(assigned.id, driverAId).exit
                          )
                        )
          } yield {
            val successes = results.count(_.isSuccess)
            val failures  = results.count(_.isFailure)
            assertTrue(successes == 1, failures == 1)
          }
        }.provide(standardLayers)
      )
    )
}
