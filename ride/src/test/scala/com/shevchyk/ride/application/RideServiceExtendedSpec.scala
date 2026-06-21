package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService, EmailSmsService, RideConfirmationData, GeocodingService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import zio.test.*
import zio.*
import java.time.Instant
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

    override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                 = ZIO.succeed(None)
    override def setAvatar(id: PersonId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
    override def deleteAvatar(id: PersonId): Task[Unit]                                       = ZIO.unit
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

  val standardLayers =
    (InMemoryRideRepository.layer ++
      ZLayer.succeed[PersonRepository](testPersonRepo) ++
      EventHub.layer ++
      noopEmailSms ++
      AuditService.inMemory ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++ ExpenseRepository.inMemory) >+> RideService.layer

  // ── Helpers ───────────────────────────────────────────────────────────
  private def mkRide(clientId: PersonId = testClientId, companyId: CompanyId = testCompanyId) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B")
  )

  private def mkRideWithPrice(
      price: BigDecimal,
      clientId: PersonId = testClientId,
      companyId: CompanyId = testCompanyId
  ) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B")
  )

  /**
   * Create a ride and drive it through to Completed status
   */
  private def createCompletedRide(service: RideService, clientId: PersonId = testClientId) =
    for {
      ride      <- service.createRide(mkRide(clientId))
      assigned  <- service.assignDriver(ride.id, testDriverId)
      started   <- service.startRide(assigned.id, testDriverId)
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
                           CancelRideRequest("changed_mind")
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("changed_mind") &&
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
                           CancelRideRequest("vehicle_breakdown", Some(BigDecimal(5.00)))
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("vehicle_breakdown") &&
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
                           CancelRideRequest("duplicate_request")
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("duplicate_request") &&
              cancelled.cancelledBy.contains(dispatcherId)
          )
        }.provide(standardLayers),
        test("cannot cancel completed ride") {
          for {
            service   <- ZIO.service[RideService]
            completed <- createCompletedRide(service)
            result    <-
              service
                .cancelRideWithReason(completed.id, testClientId, PersonRole.Client, CancelRideRequest("late"))
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
            _       <- service.cancelRideWithReason(ride.id, testClientId, PersonRole.Client, CancelRideRequest("first"))
            result  <-
              service
                .cancelRideWithReason(ride.id, testClientId, PersonRole.Client, CancelRideRequest("second"))
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
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
            started   <- service.startRide(assigned.id, testDriverId)
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
        test("cannot mark a non-completed ride as Paid") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            result  <- service.markPayment(ride.id, PaymentStatus.Paid, Some(PaymentMethod.Cash)).exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("re-paying a paid ride is idempotent (paidAt unchanged)") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(mkRide())
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
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
            started   <- service.startRide(assigned.id, testDriverId)
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
            service   <- ZIO.service[RideService]
            ride1     <- service.createRide(mkRide())
            assigned1 <- service.assignDriver(ride1.id, testDriverId)
            started1  <- service.startRide(assigned1.id, testDriverId)
            _         <- service.completeRide(started1.id)
            // Mark payment with final price to affect revenue
            _         <- service.markPayment(started1.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
            ride2     <- service.createRide(mkRide())
            assigned2 <- service.assignDriver(ride2.id, testDriverId)
            started2  <- service.startRide(assigned2.id, testDriverId)
            _         <- service.completeRide(started2.id)
            revenue   <- service.getTotalRevenue(testCompanyId)
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
                         CancelRideRequest("no_show")
                       )
            _       <- service.cancelRideWithReason(
                         ride2.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("no_show")
                       )
            _       <- service.cancelRideWithReason(
                         ride3.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("changed_mind")
                       )
            stats   <- service.getCancellationStats(testCompanyId)
          } yield assertTrue(
            stats.getOrElse("no_show", 0) == 2 &&
              stats.getOrElse("changed_mind", 0) == 1
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
                         CancelRideRequest("test")
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
            GeocodingService.noop ++ ExpenseRepository.inMemory) >+> RideService.layer
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
