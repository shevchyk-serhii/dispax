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
import com.shevchyk.core.domain.WebSocketEvent
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{RideService, PickupTimeService}
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import com.shevchyk.ride.repository.helpers.{InMemoryExternalDriverRepository, InMemoryPartnerCompanyRepository}
import com.shevchyk.core.repository.SentConfirmationRequestRepository
import zio.test.*
import zio.*
import java.util.UUID

object RideServiceExtendedSpec extends ZIOSpecDefault {

  // ── Test IDs ──────────────────────────────────────────────────────────
  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testDriver2Id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val vipClientId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))
  val dispatcherId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))

  // ── Test persons ──────────────────────────────────────────────────────
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

  val wrongCompanyDriver = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002")),
    name = "Other Driver",
    email = "other@example.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
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

  /**
   * MockPersonRepository that returns specific persons by ID
   */
  final case class TestPersonRepository(persons: Map[PersonId, Person]) extends PersonRepository {
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
  }

  val testPersonRepo = TestPersonRepository(
    Map(
      testDriver.id         -> testDriver,
      testDriver2.id        -> testDriver2,
      wrongCompanyDriver.id -> wrongCompanyDriver,
      clientPerson.id       -> clientPerson,
      vipClient.id          -> vipClient
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
      def find(id: ScheduleDayId) = ZIO.none
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

  // ── Helpers ───────────────────────────────────────────────────────────
  private def mkRide(clientId: PersonId = testClientId, companyId: CompanyId = testCompanyId) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B")
  )

  /**
   * Create a ride and drive it through to Completed status (must go through Confirmed now)
   */
  private def createCompletedRide(service: RideService, clientId: PersonId = testClientId) =
    for {
      ride      <- service.createRide(mkRide(clientId))
      assigned  <- service.assignDriver(ride.id, testDriverId)
      confirmed <- service.confirmRide(assigned.id, testDriverId)
      started   <- service.startRide(confirmed.id, testDriverId)
      completed <- service.completeRide(started.id)
    } yield completed

  /**
   * Create a ride and assign a driver
   */
  private def createAssignedRide(service: RideService, clientId: PersonId = testClientId) =
    for {
      ride     <- service.createRide(mkRide(clientId))
      assigned <- service.assignDriver(ride.id, testDriverId)
    } yield assigned

  // ── Spec ──────────────────────────────────────────────────────────────
  def spec =
    suite("RideServiceExtended")(
      // ────────────────────────────────────────────────────────────────────
      // 1. cancelRideWithReason
      // ────────────────────────────────────────────────────────────────────
      suite("cancelRideWithReason")(
        test("client can cancel own requested ride") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            cancelled <- service.cancelRideWithReason(
                           ride.id,
                           testClientId,
                           PersonRole.Client,
                           CancelRideRequest("client_request"),
                           testCompanyId
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("client_request") &&
              cancelled.cancelledBy.contains(testClientId)
          )
        }.provide(standardLayers),
        test("driver can cancel assigned ride") {
          for {
            service   <- ZIO.service[RideService]
            assigned  <- createAssignedRide(service)
            cancelled <- service.cancelRideWithReason(
                           assigned.id,
                           testDriverId,
                           PersonRole.Driver,
                           CancelRideRequest("vehicle_issue", Some(BigDecimal(5.00))),
                           testCompanyId
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("vehicle_issue") &&
              cancelled.cancellationFee.contains(BigDecimal(5.00)) &&
              cancelled.cancelledBy.contains(testDriverId)
          )
        }.provide(standardLayers),
        test("dispatcher can cancel any ride") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            cancelled <- service.cancelRideWithReason(
                           ride.id,
                           dispatcherId,
                           PersonRole.Dispatcher,
                           CancelRideRequest("other"),
                           testCompanyId
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("other") &&
              cancelled.cancelledBy.contains(dispatcherId)
          )
        }.provide(standardLayers),
        test("cannot cancel completed ride") {
          for {
            service   <- ZIO.service[RideService]
            completed <- createCompletedRide(service)
            result    <-
              service
                .cancelRideWithReason(
                  completed.id,
                  testClientId,
                  PersonRole.Client,
                  CancelRideRequest("client_request"),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("cannot cancel already cancelled ride") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            _       <- service.cancelRideWithReason(
                         ride.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request"),
                         testCompanyId
                       )
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  testClientId,
                  PersonRole.Client,
                  CancelRideRequest("weather"),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("a client cannot cancel another client's ride") {
          for {
            service <- ZIO.service[RideService]
            // ride owned by testClientId; a different client (vipClientId) tries to cancel
            ride    <- service.createRide(mkRide())
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  vipClientId,
                  PersonRole.Client,
                  CancelRideRequest("client_request"),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("a driver not assigned to the ride cannot cancel it") {
          for {
            service  <- ZIO.service[RideService]
            // assigned to testDriverId; a different driver (testDriver2Id) tries to cancel
            assigned <- createAssignedRide(service)
            result   <-
              service
                .cancelRideWithReason(
                  assigned.id,
                  testDriver2Id,
                  PersonRole.Driver,
                  CancelRideRequest("vehicle_issue"),
                  testCompanyId
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 2. reassignDriver
      // ────────────────────────────────────────────────────────────────────
      suite("reassignDriver")(
        test("happy path: reassign from one driver to another") {
          for {
            service    <- ZIO.service[RideService]
            assigned   <- createAssignedRide(service)
            _          <- assertTrue(assigned.driverId.contains(testDriverId))
            reassigned <- service.reassignDriver(assigned.id, testDriver2Id)
          } yield assertTrue(
            reassigned.driverId.contains(testDriver2Id) &&
              reassigned.status == RideStatus.Assigned
          )
        }.provide(standardLayers),
        test("fails when ride not in assignable state (Completed)") {
          for {
            service   <- ZIO.service[RideService]
            completed <- createCompletedRide(service)
            result    <- service.reassignDriver(completed.id, testDriver2Id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("fails when new driver belongs to different company") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            result   <- service.reassignDriver(assigned.id, wrongCompanyDriver.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 3. markPayment
      // ────────────────────────────────────────────────────────────────────
      suite("markPayment")(
        test("happy path: mark a completed ride as Paid with Cash method") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            assigned  <- service.assignDriver(ride.id, testDriverId)
            confirmed <- service.confirmRide(assigned.id, testDriverId)
            started   <- service.startRide(confirmed.id, testDriverId)
            completed <- service.completeRide(started.id)
            paid      <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
          } yield assertTrue(
            paid.paymentStatus == PaymentStatus.Paid &&
              paid.paymentMethod.contains(PaymentMethod.Cash) &&
              paid.paidAt.isDefined
          )
        }.provide(standardLayers),
        test("mark as Pending does not set paidAt") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            pending <- service.markPayment(ride.id, PaymentStatus.Pending, Some(PaymentMethod.Invoice))
          } yield assertTrue(
            pending.paymentStatus == PaymentStatus.Pending &&
              pending.paymentMethod.contains(PaymentMethod.Invoice) &&
              pending.paidAt.isEmpty
          )
        }.provide(standardLayers),
        test("cannot mark a Requested ride as Paid") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <- service.markPayment(ride.id, PaymentStatus.Paid, Some(PaymentMethod.Cash)).exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("cannot mark an InProgress ride as Paid") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            assigned  <- service.assignDriver(ride.id, testDriverId)
            confirmed <- service.confirmRide(assigned.id, testDriverId)
            started   <- service.startRide(confirmed.id, testDriverId) // InProgress, not Completed
            result    <- service.markPayment(started.id, PaymentStatus.Paid, Some(PaymentMethod.Cash)).exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("re-paying a paid ride is idempotent (paidAt unchanged)") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            assigned  <- service.assignDriver(ride.id, testDriverId)
            confirmed <- service.confirmRide(assigned.id, testDriverId)
            started   <- service.startRide(confirmed.id, testDriverId)
            completed <- service.completeRide(started.id)
            paid1     <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
            paid2     <- service.markPayment(paid1.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
          } yield assertTrue(paid2.paidAt == paid1.paidAt)
        }.provide(standardLayers),
        test("payment updates are persisted") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            assigned  <- service.assignDriver(ride.id, testDriverId)
            confirmed <- service.confirmRide(assigned.id, testDriverId)
            started   <- service.startRide(confirmed.id, testDriverId)
            completed <- service.completeRide(started.id)
            _         <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Card))
            retrieved <- service.getRideById(completed.id)
          } yield assertTrue(
            retrieved.paymentStatus == PaymentStatus.Paid &&
              retrieved.paymentMethod.contains(PaymentMethod.Card)
          )
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 4. updateRideDetails
      // ────────────────────────────────────────────────────────────────────
      suite("updateRideDetails")(
        test("update notes and specialRequirements") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(
                           notes = Some("Updated notes"),
                           specialRequirements = Some("Wheelchair access")
                         ),
                         testClientId,
                         PersonRole.Client,
                         Some(testCompanyId)
                       )
          } yield assertTrue(
            updated.notes.contains("Updated notes") &&
              updated.specialRequirements.contains("Wheelchair access")
          )
        }.provide(standardLayers),
        test("editing the flight number updates it without flipping direction or airport") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         mkRide().copy(specifics =
                           Some(
                             RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH100", isArrival = true)
                           )
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         // The update DTO only carries a flight number — it builds the placeholder
                         // FieldUpdate.Set(AirportTransfer("UNKNOWN", "LH200", isArrival = false)).
                         UpdateRideDetailsRequest(
                           specifics = FieldUpdate.Set(
                             RideSpecifics.AirportTransfer(airportCode = "UNKNOWN", flightNumber = "LH200")
                           )
                         ),
                         testClientId,
                         PersonRole.Dispatcher,
                         Some(testCompanyId)
                       )
          } yield assertTrue(
            updated.specifics.contains(
              RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH200", isArrival = true)
            )
          )
        }.provide(standardLayers),
        test("setting a flight number on a non-airport ride adds airport specifics") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(
                           specifics = FieldUpdate.Set(
                             RideSpecifics.AirportTransfer(airportCode = "UNKNOWN", flightNumber = "LH300")
                           )
                         ),
                         testClientId,
                         PersonRole.Dispatcher,
                         Some(testCompanyId)
                       )
          } yield assertTrue(
            updated.specifics.exists {
              case RideSpecifics.AirportTransfer(_, flight, _) => flight == "LH300"
              case _                                           => false
            }
          )
        }.provide(standardLayers),
        test("clearing the flight number drops the airport specifics") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         mkRide().copy(specifics =
                           Some(
                             RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH100", isArrival = true)
                           )
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(specifics = FieldUpdate.Clear),
                         testClientId,
                         PersonRole.Dispatcher,
                         Some(testCompanyId)
                       )
          } yield assertTrue(updated.specifics.isEmpty)
        }.provide(standardLayers),
        // Regression guard for the previous flight-number fix: an absent update (Unchanged) must NOT
        // be treated like Clear — the existing specifics survive. Collapsing absent into Clear makes
        // this go red.
        test("leaving the flight number untouched preserves the airport specifics") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         mkRide().copy(specifics =
                           Some(
                             RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH100", isArrival = true)
                           )
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(notes = Some("just a note")),
                         testClientId,
                         PersonRole.Dispatcher,
                         Some(testCompanyId)
                       )
          } yield assertTrue(
            updated.specifics.contains(
              RideSpecifics.AirportTransfer(airportCode = "MUC", flightNumber = "LH100", isArrival = true)
            )
          )
        }.provide(standardLayers),
        test("clearing notes with an empty string removes them") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            withNote <- service.updateRideDetails(
                          ride.id,
                          UpdateRideDetailsRequest(notes = Some("call on arrival")),
                          testClientId,
                          PersonRole.Dispatcher,
                          Some(testCompanyId)
                        )
            cleared  <- service.updateRideDetails(
                          ride.id,
                          UpdateRideDetailsRequest(notes = Some("")),
                          testClientId,
                          PersonRole.Dispatcher,
                          Some(testCompanyId)
                        )
          } yield assertTrue(
            withNote.notes.contains("call on arrival") &&
              cleared.notes.forall(_.isEmpty)
          )
        }.provide(standardLayers),
        test("rejects update from a different company") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <-
              service
                .updateRideDetails(
                  ride.id,
                  UpdateRideDetailsRequest(notes = Some("cross-tenant")),
                  testClientId,
                  PersonRole.Dispatcher,
                  Some(otherCompanyId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("rejects update when companyId is absent (no isolation bypass)") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <-
              service
                .updateRideDetails(
                  ride.id,
                  UpdateRideDetailsRequest(notes = Some("no company")),
                  testClientId,
                  PersonRole.Dispatcher,
                  None
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("cannot update completed ride") {
          for {
            service   <- ZIO.service[RideService]
            completed <- createCompletedRide(service)
            result    <-
              service
                .updateRideDetails(
                  completed.id,
                  UpdateRideDetailsRequest(notes = Some("Too late")),
                  testClientId,
                  PersonRole.Client,
                  Some(testCompanyId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("creator can update own ride") {
          for {
            service <- ZIO.service[RideService]
            // creatorId == clientId (set by RideMapper.fromRequest)
            ride    <- service.createRide(mkRide())
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(
                           pickupLocation = Some(Location("New Pickup")),
                           dropoffLocation = Some(Location("New Dropoff"))
                         ),
                         testClientId,
                         PersonRole.Client,
                         Some(testCompanyId)
                       )
          } yield assertTrue(
            updated.pickupLocation == Location("New Pickup") &&
              updated.dropoffLocation == Location("New Dropoff")
          )
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 5. statistics
      // ────────────────────────────────────────────────────────────────────
      suite("statistics")(
        test("getRideCountsByStatus returns correct counts") {
          for {
            service <- ZIO.service[RideService]
            _       <- service.createRide(mkRide())                 // Requested
            _       <- service.createRide(mkRide())                 // Requested
            ride3   <- service.createRide(mkRide())
            _       <- service.assignDriver(ride3.id, testDriverId) // Assigned
            counts  <- service.getRideCountsByStatus(testCompanyId)
          } yield assertTrue(
            counts.getOrElse("Requested", 0) == 2 &&
              counts.getOrElse("Assigned", 0) == 1
          )
        }.provide(standardLayers),
        test("getTotalRevenue sums completed ride prices") {
          for {
            service    <- ZIO.service[RideService]
            ride1      <- service.createRide(mkRide())
            assigned1  <- service.assignDriver(ride1.id, testDriverId)
            confirmed1 <- service.confirmRide(assigned1.id, testDriverId)
            started1   <- service.startRide(confirmed1.id, testDriverId)
            _          <- service.completeRide(started1.id)
            // Mark payment with final price to affect revenue
            _          <- service.markPayment(started1.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
            ride2      <- service.createRide(mkRide())
            assigned2  <- service.assignDriver(ride2.id, testDriverId)
            confirmed2 <- service.confirmRide(assigned2.id, testDriverId)
            started2   <- service.startRide(confirmed2.id, testDriverId)
            _          <- service.completeRide(started2.id)
            revenue    <- service.getTotalRevenue(testCompanyId)
          } yield assertTrue(
            // Both rides completed but have no estimatedPrice/finalPrice by default,
            // so revenue should be 0 (sum of None values)
            revenue == BigDecimal(0)
          )
        }.provide(standardLayers),
        test("getCancellationStats groups by reason") {
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(mkRide())
            ride2   <- service.createRide(mkRide())
            ride3   <- service.createRide(mkRide())
            _       <- service.cancelRideWithReason(
                         ride1.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request"),
                         testCompanyId
                       )
            _       <- service.cancelRideWithReason(
                         ride2.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request"),
                         testCompanyId
                       )
            _       <- service.cancelRideWithReason(
                         ride3.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("weather"),
                         testCompanyId
                       )
            // A completed (non-cancelled) ride must NOT leak into cancellation stats.
            // Its cancellationReason is None, so an unfiltered impl would bucket it as "unknown".
            _       <- createCompletedRide(service)
            stats   <- service.getCancellationStats(testCompanyId)
          } yield assertTrue(
            stats.getOrElse("client_request", 0) == 2 &&
              stats.getOrElse("weather", 0) == 1 &&
              stats.getOrElse("unknown", 0) == 0 &&
              stats.values.sum == 3
          )
        }.provide(standardLayers),
        test("getDailyStats returns per-day breakdown") {
          for {
            service <- ZIO.service[RideService]
            _       <- service.createRide(mkRide())
            ride2   <- service.createRide(mkRide())
            _       <- createCompletedRide(service)
            _       <- service.cancelRideWithReason(
                         ride2.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request"),
                         testCompanyId
                       )
            stats   <- service.getDailyStats(testCompanyId, 7)
          } yield assertTrue(
            stats.nonEmpty && {
              val (_, total, completed, cancelled) = stats.head
              total >= 3 && completed >= 1 && cancelled >= 1
            }
          )
        }.provide(standardLayers),
        test("getUnpaidCompletedRides returns only Completed + Unpaid rides") {
          for {
            service    <- ZIO.service[RideService]
            // Completed + Unpaid (default payment) — should be returned
            unpaidDone <- createCompletedRide(service)
            // Completed + Paid — excluded
            paidDone   <- createCompletedRide(service)
            _          <- service.markPayment(paidDone.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
            // Assigned (not completed) — excluded even though Unpaid
            _          <- createAssignedRide(service)
            unpaid     <- service.getUnpaidCompletedRides(testCompanyId)
          } yield assertTrue(
            unpaid.size == 1 &&
              unpaid.head.id == unpaidDone.id &&
              unpaid.head.status == RideStatus.Completed &&
              unpaid.head.paymentStatus == PaymentStatus.Unpaid
          )
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 6. blacklist
      // ────────────────────────────────────────────────────────────────────
      suite("blacklist")(
        test("assignment fails when driver is blacklisted for client") {
          for {
            blacklistRepo <- ZIO.service[BlacklistRepository]
            _             <- blacklistRepo.create(
                               BlacklistEntry(
                                 id = BlacklistEntryId.generate(),
                                 companyId = testCompanyId,
                                 clientId = testClientId,
                                 driverId = testDriverId,
                                 reason = Some("bad experience"),
                                 createdBy = dispatcherId
                               )
                             )
            service       <- ZIO.service[RideService]
            ride          <- service.createRide(mkRide())
            result        <- service.assignDriver(ride.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("blacklist", _) => true
                case _                                               => false
              }
            case _                   => false
          })
        }.provide(
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
        ),
        test("assignment succeeds when driver is not blacklisted") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(
            assigned.status == RideStatus.Assigned &&
              assigned.driverId.contains(testDriverId)
          )
        }.provide(standardLayers),
        test("reassignment fails when the new driver is blacklisted for the client") {
          for {
            blacklistRepo <- ZIO.service[BlacklistRepository]
            // testDriver2Id is blacklisted for testClientId
            _             <- blacklistRepo.create(
                               BlacklistEntry(
                                 id = BlacklistEntryId.generate(),
                                 companyId = testCompanyId,
                                 clientId = testClientId,
                                 driverId = testDriver2Id,
                                 reason = Some("bad experience"),
                                 createdBy = dispatcherId
                               )
                             )
            service       <- ZIO.service[RideService]
            ride          <- service.createRide(mkRide())
            _             <- service.assignDriver(ride.id, testDriverId) // first driver is fine
            result        <- service.reassignDriver(ride.id, testDriver2Id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("blacklist", _) => true
                case _                                               => false
              }
            case _                   => false
          })
        }.provide(
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
        )
      ),

      // ────────────────────────────────────────────────────────────────────
      // 7. Event publication — cancelRideWithReason / updateRideDetails
      // ────────────────────────────────────────────────────────────────────
      suite("event publication")(
        test("cancelRideWithReason publishes RideStatusChanged with cancellationReason set") {
          ZIO.scoped {
            for {
              hub     <- ZIO.service[EventHub]
              dequeue <- hub.subscribe
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide())
              _       <- service.cancelRideWithReason(
                           ride.id,
                           testClientId,
                           PersonRole.Client,
                           CancelRideRequest("client_request"),
                           testCompanyId
                         )
              _       <- dequeue.take // RideCreated (from createRide)
              event2  <- dequeue.take // RideStatusChanged (from cancelRideWithReason)
            } yield {
              val changed = event2.asInstanceOf[WebSocketEvent.RideStatusChanged]
              assertTrue(
                changed.newStatus == "Cancelled" &&
                  changed.cancellationReason.contains("client_request") &&
                  changed.clientId == testClientId.value &&
                  changed.companyId == testCompanyId.value
              )
            }
          }
        }.provide(standardLayers),
        // Negative: if we remove the cancellationReason from the publish call the assertion below
        // would fail (it checks `contains`). That is exactly the mutation that makes this test
        // meaningful — the production code must pass the reason through.
        test("cancelRideWithReason reason in event is NOT None and matches the request") {
          ZIO.scoped {
            for {
              hub     <- ZIO.service[EventHub]
              dequeue <- hub.subscribe
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide())
              _       <- service.cancelRideWithReason(
                           ride.id,
                           testClientId,
                           PersonRole.Client,
                           CancelRideRequest("other"),
                           testCompanyId
                         )
              _       <- dequeue.take // RideCreated
              event   <- dequeue.take // RideStatusChanged
            } yield {
              val changed = event.asInstanceOf[WebSocketEvent.RideStatusChanged]
              assertTrue(
                changed.cancellationReason.isDefined &&
                  changed.cancellationReason.contains("other")
              )
            }
          }
        }.provide(standardLayers),
        test("updateRideDetails publishes RideDetailsUpdated on success") {
          ZIO.scoped {
            for {
              hub     <- ZIO.service[EventHub]
              dequeue <- hub.subscribe
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide())
              _       <- service.updateRideDetails(
                           ride.id,
                           UpdateRideDetailsRequest(notes = Some("priority pickup")),
                           testClientId,
                           PersonRole.Client,
                           Some(testCompanyId)
                         )
              _       <- dequeue.take // RideCreated
              event   <- dequeue.take // RideDetailsUpdated
            } yield {
              val updated = event.asInstanceOf[WebSocketEvent.RideDetailsUpdated]
              assertTrue(
                updated.rideId == ride.id.value &&
                  updated.clientId == testClientId.value &&
                  updated.companyId == testCompanyId.value
              )
            }
          }
        }.provide(standardLayers),
        // Mutation probe: if updateRideDetails does NOT publish an event the dequeue.take above
        // would hang / timeout — the test catches the missing publish.
        test("updateRideDetails does NOT publish when update fails (completed ride)") {
          ZIO.scoped {
            for {
              hub       <- ZIO.service[EventHub]
              dequeue   <- hub.subscribe
              service   <- ZIO.service[RideService]
              completed <- createCompletedRide(service)
              _         <-
                service
                  .updateRideDetails(
                    completed.id,
                    UpdateRideDetailsRequest(notes = Some("too late")),
                    testClientId,
                    PersonRole.Client,
                    Some(testCompanyId)
                  )
                  .ignore // expected to fail
              // Drain all events published so far (createCompletedRide fires several)
              events    <- dequeue.takeAll
            } yield assertTrue(
              // No RideDetailsUpdated should be in the queue — the failed update must not publish
              !events.exists(_.isInstanceOf[WebSocketEvent.RideDetailsUpdated])
            )
          }
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // 8. updateRideDetails — client ownership (new in this change)
      // ────────────────────────────────────────────────────────────────────
      suite("updateRideDetails ownership")(
        test("client-creator can update own ride in Requested status") {
          for {
            service <- ZIO.service[RideService]
            // createRide sets creatorId = clientId when called directly
            ride    <- service.createRide(mkRide(clientId = testClientId))
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(notes = Some("window seat please")),
                         testClientId,
                         PersonRole.Client,
                         Some(testCompanyId)
                       )
          } yield assertTrue(updated.notes.contains("window seat please"))
        }.provide(standardLayers),
        test("client-creator can update own ride in Assigned status") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide(clientId = testClientId))
            assigned <- service.assignDriver(ride.id, testDriverId)
            updated  <- service.updateRideDetails(
                          assigned.id,
                          UpdateRideDetailsRequest(notes = Some("extra luggage")),
                          testClientId,
                          PersonRole.Client,
                          Some(testCompanyId)
                        )
          } yield assertTrue(updated.notes.contains("extra luggage"))
        }.provide(standardLayers),
        // Negative: a client who did NOT create the ride cannot update it.
        // The RideService checks `ride.creatorId != userId` for non-dispatchers.
        // vipClientId is a valid client in the same company but is NOT the creator
        // (testClientId is). If the ownership check were removed this test would fail.
        test("client who is NOT the ride creator cannot update the ride") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide(clientId = testClientId)) // creator = testClientId
            result  <-
              service
                .updateRideDetails(
                  ride.id,
                  UpdateRideDetailsRequest(notes = Some("should be denied")),
                  vipClientId, // different client, same company
                  PersonRole.Client,
                  Some(testCompanyId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      // ────────────────────────────────────────────────────────────────────
      // getDriverEarnings — period window boundaries (service-level)
      // ────────────────────────────────────────────────────────────────────
      suite("getDriverEarnings window")(
        test("week window spans Monday 00:00 to next Monday for a mid-week anchor") {
          val anchor       = java.time.LocalDate.of(2026, 6, 3) // Wednesday
          val expectedFrom = java.time.LocalDate.of(2026, 6, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          val expectedTo   = java.time.LocalDate.of(2026, 6, 8).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Week, anchor)
          } yield assertTrue(
            report.from == expectedFrom,
            report.to == expectedTo,
            report.period == EarningsPeriod.Week
          )
        }.provide(standardLayers),
        test("day window spans the anchor day only") {
          val anchor       = java.time.LocalDate.of(2026, 6, 3)
          val expectedFrom = anchor.atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          val expectedTo   = anchor.plusDays(1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Day, anchor)
          } yield assertTrue(report.from == expectedFrom, report.to == expectedTo)
        }.provide(standardLayers),
        test("month window spans the 1st to the 1st of next month") {
          val anchor       = java.time.LocalDate.of(2026, 6, 15)
          val expectedFrom = java.time.LocalDate.of(2026, 6, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          val expectedTo   = java.time.LocalDate.of(2026, 7, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Month, anchor)
          } yield assertTrue(report.from == expectedFrom, report.to == expectedTo)
        }.provide(standardLayers),
        test("empty earnings yield zeroed report (no completed rides)") {
          val anchor = java.time.LocalDate.of(2026, 6, 3)
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Week, anchor)
          } yield assertTrue(
            report.grossRevenue == BigDecimal(0),
            report.completedRides == 0,
            report.avgFare == BigDecimal(0),
            report.buckets.isEmpty
          )
        }.provide(standardLayers),
        // -- Boundary cases added by test audit 2026-06 ----------------------
        test("week window for a Sunday anchor starts on the same week's Monday") {
          // 2026-06-07 is a Sunday → Monday of that week is 2026-06-01, next Monday 2026-06-08.
          // Guards against treating ISO day-of-week 7 (Sunday) as start of the next week.
          val anchor       = java.time.LocalDate.of(2026, 6, 7) // Sunday
          val expectedFrom = java.time.LocalDate.of(2026, 6, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          val expectedTo   = java.time.LocalDate.of(2026, 6, 8).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Week, anchor)
          } yield assertTrue(report.from == expectedFrom, report.to == expectedTo)
        }.provide(standardLayers),
        test("month window crosses year boundary December → January") {
          val anchor       = java.time.LocalDate.of(2026, 12, 20)
          val expectedFrom = java.time.LocalDate.of(2026, 12, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          val expectedTo   = java.time.LocalDate.of(2027, 1, 1).atStartOfDay(java.time.ZoneOffset.UTC).toInstant
          for {
            service <- ZIO.service[RideService]
            report  <- service.getDriverEarnings(testDriverId, testCompanyId, EarningsPeriod.Month, anchor)
          } yield assertTrue(report.from == expectedFrom, report.to == expectedTo)
        }.provide(standardLayers)
      )
    )
}
