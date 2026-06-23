package com.shevchyk.ride.application

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
import com.shevchyk.core.repository.{BlacklistRepository, PersonRepository, SentConfirmationRequestRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{RideService, PickupTimeService}
import com.shevchyk.ride.repository.{
  ExpenseRepository,
  ExternalDriverRepository,
  InMemoryRideRepository,
  PartnerCompanyRepository
}
import com.shevchyk.ride.repository.helpers.{InMemoryExternalDriverRepository, InMemoryPartnerCompanyRepository}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

/**
 * Unit tests for `handOffToExternal` (AC-B1..B6) and the Stage-A `cancelRideWithReason` cross-company tenant-isolation
 * guard (AC-A1, AC-A2).
 *
 * Uses in-memory repository doubles only — no Testcontainers.
 *
 * Mutation-check notes (for the reviewer): AC-A2: remove the `ride.companyId != callerCompanyId` guard in
 * cancelRideWithReason → test fails. AC-B2: remove the `!ride.canBeHandedOff` guard in handOffToExternal → test fails.
 * AC-B3: change externalDriverRepo.findById to ignore callerCompanyId → test fails. AC-B4: change
 * partnerCompanyRepo.findById to ignore callerCompanyId → test fails.
 */
object RideServiceHandOffSpec extends ZIOSpecDefault {

  // ── Test IDs ──────────────────────────────────────────────────────────────
  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testClientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val testDriverId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))

  // ── Test persons ──────────────────────────────────────────────────────────
  val testClient = Person(
    id = testClientId,
    name = "Test Client",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val dispatcher = Person(
    id = dispatcherId,
    name = "Dispatcher",
    email = "disp@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId)
  )

  // ── Minimal PersonRepository stub ─────────────────────────────────────────
  final case class TestPersonRepo(persons: Map[PersonId, Person]) extends PersonRepository:
    def create(p: Person): Task[Person]              = ZIO.succeed(p)
    def findById(id: PersonId): Task[Option[Person]] = ZIO.succeed(persons.get(id))

    def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]] = ZIO.succeed(
      persons.get(id).filter(_.companyId.contains(companyId))
    )
    def findByEmail(email: String): Task[Option[Person]]                             = ZIO.succeed(persons.values.find(_.email == email))

    def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(_.role == role).toList
    )

    def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(p => p.role == role && p.companyId.contains(companyId)).toList
    )

    def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                 = ZIO.succeed(
      persons.values.filter(_.companyId.contains(companyId)).toList
    )
    def findAll(): Task[List[Person]]                                                             = ZIO.succeed(persons.values.toList)
    def update(p: Person): Task[Person]                                                           = ZIO.succeed(p)
    def delete(id: PersonId): Task[Unit]                                                          = ZIO.unit
    def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                           = ZIO.unit
    def findByStatus(s: UserStatus): Task[List[Person]]                                           = ZIO.succeed(Nil)
    def searchByQuery(q: String): Task[List[Person]]                                              = ZIO.succeed(Nil)
    def updateLastLogin(id: PersonId): Task[Unit]                                                 = ZIO.unit
    def findByClientCompany(cid: ClientCompanyId): Task[List[Person]]                             = ZIO.succeed(Nil)
    def upsertDriverRow(personId: PersonId): Task[Unit]                                           = ZIO.unit
    def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                              = ZIO.succeed(None)
    def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], ct: String): Task[Unit] = ZIO.unit
    def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                              = ZIO.unit

  // ── No-op stubs ───────────────────────────────────────────────────────────
  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendInvoiceEmail(data: com.shevchyk.core.application.InvoiceEmailData): Task[Unit] = ZIO.unit
  )

  private val noopAvailability: ZLayer[Any, Nothing, DriverAvailabilityChecker] = ZLayer.succeed(
    new DriverAvailabilityChecker:
      def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
  )

  private val noopScheduleDayLookup: ZLayer[Any, Nothing, ScheduleDayLookup] = ZLayer.succeed(
    new ScheduleDayLookup:
      def find(id: ScheduleDayId) = ZIO.succeed(None)
  )

  private val personRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed[PersonRepository](
    TestPersonRepo(Map(testClient.id -> testClient, testDriver.id -> testDriver, dispatcher.id -> dispatcher))
  )

  // ── Directory fixtures ────────────────────────────────────────────────────
  private val extDriverId        = ExternalDriverId(UUID.fromString("00000011-0000-0000-0000-000000000001"))
  private val partnerCompId      = PartnerCompanyId(UUID.fromString("00000012-0000-0000-0000-000000000001"))
  private val otherExtDriverId   = ExternalDriverId(UUID.fromString("00000011-0000-0000-0000-000000000002"))
  private val otherPartnerCompId = PartnerCompanyId(UUID.fromString("00000012-0000-0000-0000-000000000002"))

  private def makeExtDriver(id: ExternalDriverId, companyId: CompanyId, pcId: Option[PartnerCompanyId] = None) =
    ExternalDriver(
      id = id,
      name = s"Driver-${id.value}",
      taxiCompanyId = companyId,
      partnerCompanyId = pcId,
      createdAt = Instant.now(),
      updatedAt = Instant.now()
    )

  private def makePartnerComp(id: PartnerCompanyId, companyId: CompanyId) = PartnerCompany(
    id = id,
    name = s"Partner-${id.value}",
    taxiCompanyId = companyId,
    createdAt = Instant.now(),
    updatedAt = Instant.now()
  )

  // ── Layer builder: seeds in-memory repos before handing them to RideService ──
  private def buildLayers(
      eds: ExternalDriver*
  )(
      pcs: PartnerCompany*
  ): ZLayer[Any, Throwable, RideService] = {
    val edLayer: ZLayer[Any, Throwable, ExternalDriverRepository] = ZLayer.fromZIO(for {
      repo <- ZIO.succeed(new InMemoryExternalDriverRepository())
      _    <- ZIO.foreachDiscard(eds)(repo.create)
    } yield repo.asInstanceOf[ExternalDriverRepository])
    val pcLayer: ZLayer[Any, Throwable, PartnerCompanyRepository] = ZLayer.fromZIO(for {
      repo <- ZIO.succeed(new InMemoryPartnerCompanyRepository())
      _    <- ZIO.foreachDiscard(pcs)(repo.create)
    } yield repo.asInstanceOf[PartnerCompanyRepository])
    (InMemoryRideRepository.layer ++
      personRepoLayer ++
      EventHub.layer ++
      noopEmailSms ++
      AuditService.inMemory ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++
      ExpenseRepository.inMemory ++
      PickupTimeService.noopLayer ++
      noopAvailability ++
      noopScheduleDayLookup ++
      edLayer ++
      pcLayer ++
      SentConfirmationRequestRepository.inMemory) >+> RideService.layer
  }

  // ── Ride factory ──────────────────────────────────────────────────────────
  private def mkRide(companyId: CompanyId = testCompanyId) = CreateRideRequest(
    clientId = testClientId,
    companyId = companyId,
    pickupLocation = Location("Pickup"),
    dropoffLocation = Location("Dropoff")
  )

  // ── Spec ──────────────────────────────────────────────────────────────────
  def spec =
    suite("RideServiceHandOff")(
      // ── Stage A: cancelRideWithReason tenant-isolation ─────────────────────
      suite("cancelRideWithReason — Stage A tenant fix")(
        // AC-A1: dispatcher from own company cancels Requested ride with driver_unavailable
        test(
          "AC-A1: dispatcher cancels own-company Requested ride with driver_unavailable → Cancelled, reason stored"
        ) {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            cancelled <- service.cancelRideWithReason(
                           ride.id,
                           dispatcherId,
                           PersonRole.Dispatcher,
                           CancelRideRequest("driver_unavailable"),
                           testCompanyId
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled,
            cancelled.cancellationReason.contains("driver_unavailable"),
            cancelled.cancelledBy.contains(dispatcherId)
          )
        }.provide(buildLayers()()), // no directory entries needed for cancel

        // AC-A2 [CRITICAL]: dispatcher from company B cannot cancel a ride belonging to company A
        // Mutation check: removing the `ride.companyId != callerCompanyId` guard makes this test fail.
        test("AC-A2 [CRITICAL]: dispatcher with wrong companyId cannot cancel a ride → UnauthorizedAccess") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide(testCompanyId))
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  dispatcherId,
                  PersonRole.Dispatcher,
                  CancelRideRequest("other"),
                  otherCompanyId // ← wrong tenant
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(buildLayers()())
      ),

      // ── Stage B: handOffToExternal ─────────────────────────────────────────
      suite("handOffToExternal")(
        // AC-B1: happy path
        test("AC-B1: Requested ride + valid driver + partner company → HandedOff, IDs set") {
          val extDriver   = makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId))
          val partnerComp = makePartnerComp(partnerCompId, testCompanyId)
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            handedOff <- service.handOffToExternal(
                           ride.id,
                           testCompanyId,
                           dispatcherId,
                           HandOffRequest(extDriverId, partnerCompId)
                         )
          } yield assertTrue(
            handedOff.status == RideStatus.HandedOff,
            handedOff.externalDriverId.contains(extDriverId),
            handedOff.partnerCompanyId.contains(partnerCompId)
          )
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        ),

        // AC-B2: non-Requested ride → InvalidStatusTransition
        // Mutation check: removing the `!ride.canBeHandedOff` guard makes this test fail.
        test("AC-B2: handOffToExternal on Assigned ride → InvalidStatusTransition") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .handOffToExternal(
                  assigned.id,
                  testCompanyId,
                  dispatcherId,
                  HandOffRequest(extDriverId, partnerCompId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        ),

        // AC-B3 [CRITICAL]: external driver from different company → ExternalDriverNotFound
        // Mutation check: changing findById to ignore callerCompanyId makes this test fail.
        test("AC-B3 [CRITICAL]: external driver from another company → ExternalDriverNotFound") {
          // otherExtDriver has taxiCompanyId = otherCompanyId; caller's companyId = testCompanyId
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <-
              service
                .handOffToExternal(
                  ride.id,
                  testCompanyId,
                  dispatcherId,
                  HandOffRequest(otherExtDriverId, partnerCompId) // ← driver from other tenant
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.ExternalDriverNotFound])
            case _                   => false
          })
        }.provide(
          buildLayers(makeExtDriver(otherExtDriverId, otherCompanyId))(makePartnerComp(partnerCompId, testCompanyId))
        ),

        // AC-B4 [CRITICAL]: partner company from different company → PartnerCompanyNotFound
        // Mutation check: changing findById to ignore callerCompanyId makes this test fail.
        test("AC-B4 [CRITICAL]: partner company from another company → PartnerCompanyNotFound") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <-
              service
                .handOffToExternal(
                  ride.id,
                  testCompanyId,
                  dispatcherId,
                  HandOffRequest(extDriverId, otherPartnerCompId) // ← partner from other tenant
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.PartnerCompanyNotFound])
            case _                   => false
          })
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId))(makePartnerComp(otherPartnerCompId, otherCompanyId))
        ),

        // AC-B5: HandedOff ride can be cancelled
        test("AC-B5: a HandedOff ride can be cancelled by a dispatcher") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            handedOff <- service.handOffToExternal(
                           ride.id,
                           testCompanyId,
                           dispatcherId,
                           HandOffRequest(extDriverId, partnerCompId)
                         )
            _         <- assertTrue(handedOff.status == RideStatus.HandedOff)
            cancelled <- service.cancelRideWithReason(
                           handedOff.id,
                           dispatcherId,
                           PersonRole.Dispatcher,
                           CancelRideRequest("other"),
                           testCompanyId
                         )
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        ),

        // AC-B6: HandedOff ride cannot be assigned to a driver
        test("AC-B6: a HandedOff ride cannot be assigned to a driver (canBeAssigned == false)") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            handedOff <- service.handOffToExternal(
                           ride.id,
                           testCompanyId,
                           dispatcherId,
                           HandOffRequest(extDriverId, partnerCompId)
                         )
            result    <- service.assignDriver(handedOff.id, testDriverId).exit
          } yield assertTrue(
            !handedOff.canBeAssigned,
            result.isFailure
          )
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        ),

        // Ride cross-company tenant-isolation for handOff itself
        test("[CRITICAL]: caller with wrong companyId cannot hand off a ride → UnauthorizedAccess") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide(testCompanyId))
            result  <-
              service
                .handOffToExternal(
                  ride.id,
                  otherCompanyId, // ← wrong tenant
                  dispatcherId,
                  HandOffRequest(extDriverId, partnerCompId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        ),

        // Persisted fields round-trip through the in-memory repo
        test("handOffToExternal: getRideById after hand-off returns correct IDs and HandedOff status") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            _         <- service.handOffToExternal(
                           ride.id,
                           testCompanyId,
                           dispatcherId,
                           HandOffRequest(extDriverId, partnerCompId)
                         )
            persisted <- service.getRideById(ride.id)
          } yield assertTrue(
            persisted.status == RideStatus.HandedOff,
            persisted.externalDriverId.contains(extDriverId),
            persisted.partnerCompanyId.contains(partnerCompId)
          )
        }.provide(
          buildLayers(makeExtDriver(extDriverId, testCompanyId, Some(partnerCompId)))(
            makePartnerComp(partnerCompId, testCompanyId)
          )
        )
      )
    )
}
