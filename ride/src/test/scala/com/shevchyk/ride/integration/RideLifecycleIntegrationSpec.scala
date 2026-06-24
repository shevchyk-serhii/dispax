package com.shevchyk.ride.integration

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  DriverAvailabilityChecker,
  EventHub,
  AuditService,
  EmailSmsService,
  RideConfirmationData,
  GeocodingService,
  ScheduleDayLookup,
  UnavailabilitySlot
}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{RideService, PickupTimeService}
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import com.shevchyk.ride.repository.helpers.{InMemoryExternalDriverRepository, InMemoryPartnerCompanyRepository}
import com.shevchyk.core.repository.SentConfirmationRequestRepository
import zio.*
import zio.test.*
import java.util.UUID

object RideLifecycleIntegrationSpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testDriver2Id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val vipClientId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))

  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val testDriver2 = Person(
    id = testDriver2Id,
    name = "Second Driver",
    email = "driver2@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val clientPerson = Person(
    id = testClientId,
    name = "Client Person",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  val vipClient = Person(
    id = vipClientId,
    name = "VIP Client",
    email = "vip@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId),
    isVip = true,
    preferredDriverId = Some(testDriverId)
  )

  final case class TestPersonRepo(persons: Map[PersonId, Person]) extends PersonRepository:
    override def create(person: Person): Task[Person]         = ZIO.succeed(person)
    override def findById(id: PersonId): Task[Option[Person]] = ZIO.succeed(persons.get(id))

    override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]] = ZIO.succeed(
      persons.get(id).filter(_.companyId.contains(companyId))
    )
    override def findByEmail(email: String): Task[Option[Person]]                             = ZIO.succeed(persons.values.find(_.email == email))

    override def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(_.role == role).toList
    )

    override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList
    )

    override def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                = ZIO.succeed(
      persons.values.filter(_.companyId.contains(companyId)).toList
    )
    override def findAll(): Task[List[Person]]                                                            = ZIO.succeed(persons.values.toList)
    override def update(person: Person): Task[Person]                                                     = ZIO.succeed(person)
    override def delete(id: PersonId): Task[Unit]                                                         = ZIO.unit
    override def deleteInCompany(id: PersonId, companyId: com.shevchyk.core.domain.CompanyId): Task[Unit] = ZIO.unit

    override def findByStatus(status: com.shevchyk.core.domain.UserStatus): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(_.status == status).toList
    )
    override def searchByQuery(query: String): Task[List[Person]]                              = ZIO.succeed(Nil)
    override def updateLastLogin(id: PersonId): Task[Unit]                                     = ZIO.unit

    override def findByClientCompany(clientCompanyId: com.shevchyk.core.domain.ClientCompanyId): Task[List[Person]] =
      ZIO.succeed(Nil)

    override def upsertDriverRow(personId: PersonId): Task[Unit] = ZIO.unit

    override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]] = ZIO.none

    override def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] =
      ZIO.unit
    override def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit

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
      def find(id: ScheduleDayId) = ZIO.none
  )

  val testPersonRepo = TestPersonRepo(
    Map(
      testDriver.id   -> testDriver,
      testDriver2.id  -> testDriver2,
      clientPerson.id -> clientPerson,
      vipClient.id    -> vipClient
    )
  )

  val standardLayers =
    (InMemoryRideRepository.layer ++
      ZLayer.succeed[PersonRepository](testPersonRepo) ++
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

  def createTestRide(service: RideService, clientId: PersonId = testClientId) = service.createRide(
    CreateRideRequest(
      clientId = clientId,
      companyId = testCompanyId,
      pickupLocation = Location("Pickup"),
      dropoffLocation = Location("Dropoff")
    )
  )

  def spec =
    suite("RideLifecycle Integration")(
      test("full lifecycle: create -> assign -> confirm -> start -> complete -> markPayment") {
        for {
          service   <- ZIO.service[RideService]
          ride      <- createTestRide(service)
          assigned  <- service.assignDriver(ride.id, testDriverId)
          confirmed <- service.confirmRide(assigned.id, testDriverId)
          started   <- service.startRide(confirmed.id, testDriverId)
          completed <- service.completeRide(started.id)
          paid      <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
        } yield assertTrue(
          ride.status == RideStatus.Requested &&
            assigned.status == RideStatus.Assigned &&
            confirmed.status == RideStatus.Confirmed &&
            confirmed.confirmedAt.isDefined &&
            started.status == RideStatus.InProgress &&
            started.startTime.isDefined &&
            completed.status == RideStatus.Completed &&
            completed.endTime.isDefined &&
            paid.paymentStatus == PaymentStatus.Paid &&
            paid.paymentMethod.contains(PaymentMethod.Cash) &&
            paid.paidAt.isDefined
        )
      }.provide(standardLayers),
      test("blacklist enforcement: assign fails for blacklisted driver") {
        for {
          service   <- ZIO.service[RideService]
          blacklist <- ZIO.service[BlacklistRepository]
          ride      <- createTestRide(service)
          _         <- blacklist.create(
                         BlacklistEntry(
                           id = BlacklistEntryId(UUID.randomUUID()),
                           companyId = testCompanyId,
                           clientId = testClientId,
                           driverId = testDriverId,
                           reason = Some("test"),
                           createdBy = testClientId
                         )
                       )
          result    <- service.assignDriver(ride.id, testDriverId).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists {
              case RideError.BusinessRuleViolation("blacklist", _) => true
              case _                                               => false
            }
          case _                   => false
        })
      }.provide(standardLayers),
      test("VIP ride: assign sets isVipRide flag") {
        for {
          service  <- ZIO.service[RideService]
          ride     <- createTestRide(service, clientId = vipClientId)
          assigned <- service.assignDriver(ride.id, testDriverId)
        } yield assertTrue(
          assigned.isVipRide &&
            assigned.preferredDriverUsed
        )
      }.provide(standardLayers),
      test("cancellation with reason: audit trail preserved") {
        for {
          service   <- ZIO.service[RideService]
          ride      <- createTestRide(service)
          assigned  <- service.assignDriver(ride.id, testDriverId)
          cancelled <- service.cancelRideWithReason(
                         assigned.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request", Some(BigDecimal(5.00))),
                         testCompanyId
                       )
        } yield assertTrue(
          cancelled.status == RideStatus.Cancelled &&
            cancelled.cancellationReason.contains("client_request") &&
            cancelled.cancellationFee.contains(BigDecimal(5.00)) &&
            cancelled.cancelledBy.contains(testClientId)
        )
      }.provide(standardLayers),
      test("reassignment: create → assign → reassign") {
        for {
          service    <- ZIO.service[RideService]
          ride       <- createTestRide(service)
          assigned   <- service.assignDriver(ride.id, testDriverId)
          reassigned <- service.reassignDriver(assigned.id, testDriver2Id)
        } yield assertTrue(
          assigned.driverId.contains(testDriverId) &&
            reassigned.driverId.contains(testDriver2Id) &&
            reassigned.status == RideStatus.Assigned
        )
      }.provide(standardLayers),
      // Regression: status transitions now persist through the atomic updateIfStatus, which must
      // write the FULL row — start_time/end_time/cancellation_*/paid_at included. An earlier
      // updateIfStatus only set 4 columns, so these transition fields would silently vanish in the
      // DB while the service's returned object still looked correct. Re-read from Postgres (not the
      // returned object) to prove the columns actually landed.
      test("transition fields persist in DB via updateIfStatus (start/end/paid)") {
        for {
          service       <- ZIO.service[RideService]
          ride          <- createTestRide(service)
          assigned      <- service.assignDriver(ride.id, testDriverId)
          confirmed     <- service.confirmRide(assigned.id, testDriverId)
          _             <- service.startRide(confirmed.id, testDriverId)
          afterStart    <- service.getRideById(ride.id)
          _             <- service.completeRide(ride.id)
          afterComplete <- service.getRideById(ride.id)
          _             <- service.markPayment(ride.id, PaymentStatus.Paid, Some(PaymentMethod.Card))
          afterPaid     <- service.getRideById(ride.id)
        } yield assertTrue(
          afterStart.status == RideStatus.InProgress,
          afterStart.startTime.isDefined,
          afterComplete.status == RideStatus.Completed,
          afterComplete.endTime.isDefined,
          afterPaid.paymentStatus == PaymentStatus.Paid,
          afterPaid.paymentMethod.contains(PaymentMethod.Card),
          afterPaid.paidAt.isDefined
        )
      }.provide(standardLayers),
      test("cancellation fields persist in DB via updateIfStatus (reason/fee/cancelledBy)") {
        for {
          service   <- ZIO.service[RideService]
          ride      <- createTestRide(service)
          assigned  <- service.assignDriver(ride.id, testDriverId)
          _         <- service.cancelRideWithReason(
                         assigned.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request", Some(BigDecimal(5.00))),
                         testCompanyId
                       )
          persisted <- service.getRideById(ride.id)
        } yield assertTrue(
          persisted.status == RideStatus.Cancelled,
          persisted.cancellationReason.contains("client_request"),
          persisted.cancellationFee.contains(BigDecimal(5.00)),
          persisted.cancelledBy.contains(testClientId)
        )
      }.provide(standardLayers),
      // ── Stage A AC-A4: cross-company cancel → UnauthorizedAccess ──────────
      test("AC-A4: cancelRideWithReason with wrong companyId → UnauthorizedAccess") {
        val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000099"))
        for {
          service <- ZIO.service[RideService]
          ride    <- createTestRide(service)
          result  <-
            service
              .cancelRideWithReason(
                ride.id,
                testClientId,
                PersonRole.Dispatcher,
                CancelRideRequest("other"),
                otherCompanyId // ← wrong tenant
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
          case _                   => false
        })
      }.provide(standardLayers),
      // ── Stage B AC-B7: cross-company handOff → UnauthorizedAccess ─────────
      test("AC-B7: handOffToExternal with wrong callerCompanyId → UnauthorizedAccess") {
        val otherCompanyId     = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000099"))
        val otherExtDriverId   = ExternalDriverId(UUID.fromString("00000011-0000-0000-0000-000000000099"))
        val otherPartnerCompId = PartnerCompanyId(UUID.fromString("00000012-0000-0000-0000-000000000099"))
        for {
          service <- ZIO.service[RideService]
          ride    <- createTestRide(service)
          result  <-
            service
              .handOffToExternal(
                ride.id,
                otherCompanyId, // ← wrong tenant
                testClientId,
                HandOffRequest(otherExtDriverId, otherPartnerCompId)
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
          case _                   => false
        })
      }.provide(standardLayers),
      // ── Stage B AC-B8: handOff on Assigned ride → InvalidStatusTransition ─
      test("AC-B8: handOffToExternal on Assigned ride → InvalidStatusTransition") {
        val extDriverId   = ExternalDriverId(UUID.fromString("00000011-0000-0000-0000-000000000001"))
        val partnerCompId = PartnerCompanyId(UUID.fromString("00000012-0000-0000-0000-000000000001"))
        for {
          service  <- ZIO.service[RideService]
          ride     <- createTestRide(service)
          assigned <- service.assignDriver(ride.id, testDriverId)
          result   <-
            service
              .handOffToExternal(
                assigned.id,
                testCompanyId,
                testClientId,
                HandOffRequest(extDriverId, partnerCompId)
              )
              .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),
      // ── Stage B: HandedOff status machine predicates ─────────────────────
      // Verifies that the domain predicates on HandedOff are correct:
      // a Requested ride can be handed off; an Assigned ride cannot;
      // a HandedOff ride is still cancellable (not Completed/Cancelled).
      test("HandedOff status machine predicates") {
        for {
          service <- ZIO.service[RideService]
          ride    <- createTestRide(service)
        } yield {
          val handedOffRide = ride.copy(status = RideStatus.HandedOff)
          assertTrue(
            ride.status == RideStatus.Requested,
            ride.canBeHandedOff,
            !ride.copy(status = RideStatus.Assigned).canBeHandedOff,
            ride.canBeCancelled,
            !ride.copy(status = RideStatus.Completed).canBeCancelled,
            handedOffRide.canBeCancelled,
            !handedOffRide.canBeAssigned
          )
        }
      }.provide(standardLayers)
    ) @@ TestAspect.tag("integration")
}
