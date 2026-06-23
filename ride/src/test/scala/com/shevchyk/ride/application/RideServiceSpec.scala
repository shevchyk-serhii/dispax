package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  DriverAvailabilityChecker,
  EventHub,
  AuditService,
  EmailSmsService,
  RideConfirmationData,
  GeocodingService,
  UnavailabilitySlot
}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.{PersonRepository, InMemoryPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{RideService, PickupTimeService}
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

object RideServiceSpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testDriverId       = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testDriver2Id      = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val testClientId       = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val vipClientId        = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))
  val dispatcherDriverId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000050"))
  val pureDispatcherId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000060"))

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
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000003")),
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

  // Client referenced by testClientId — must exist in the person repo and belong to testCompanyId,
  // otherwise createRide rejects it (company-isolation / PersonNotFound).
  val testClient = Person(
    id = testClientId,
    name = "Test Client",
    email = "test-client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  // Client of a different company — used to assert createRide rejects cross-tenant clients.
  val otherCompanyClient = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000300")),
    name = "Other Company Client",
    email = "other-client@example.com",
    role = PersonRole.Client,
    companyId = Some(otherCompanyId)
  )

  // Dispatcher who also has the Driver role — should be assignable to rides.
  val dispatcherDriver = Person(
    id = dispatcherDriverId,
    name = "Dispatcher Driver",
    email = "dispdriver@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId),
    roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
  )

  // Pure dispatcher — has no Driver role, must not be assignable to rides.
  val pureDispatcher = Person(
    id = pureDispatcherId,
    name = "Pure Dispatcher",
    email = "puredisp@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId),
    roles = Set(PersonRole.Dispatcher)
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
      persons.values.filter(p => p.hasRole(role) && p.companyId.contains(companyId)).toList
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
      vipClient.id          -> vipClient,
      testClient.id         -> testClient,
      otherCompanyClient.id -> otherCompanyClient,
      dispatcherDriver.id   -> dispatcherDriver,
      pureDispatcher.id     -> pureDispatcher
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
      noopAvailabilityChecker) >+> RideService.layer

  def spec =
    suite("RideService")(
      suite("getRideById")(
        test("should return RideNotFound error for any ID") {
          for {
            service <- ZIO.service[RideService]
            result  <- service.getRideById(RideId(UUID.fromString("0000007b-0000-0000-0000-000000000123"))).exit
          } yield assertTrue(result.isFailure)
        }.provide(
          InMemoryRideRepository.layer,
          InMemoryPersonRepository.layer,
          EventHub.layer,
          noopEmailSms,
          AuditService.inMemory,
          BlacklistRepository.inMemory,
          GeocodingService.noop,
          ExpenseRepository.inMemory,
          PickupTimeService.noopLayer,
          noopAvailabilityChecker,
          RideService.layer
        )
      ),
      suite("createRide")(
        test("should create ride with generated ID") {
          val request = CreateRideRequest(
            clientId = testClientId,
            companyId = testCompanyId,
            pickupLocation = Location("Start Point"),
            dropoffLocation = Location("End Point"),
            notes = Some("Test ride")
          )

          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(request)
          } yield assertTrue(
            ride.clientId == request.clientId &&
              ride.pickupLocation == request.pickupLocation &&
              ride.dropoffLocation == request.dropoffLocation &&
              ride.notes == request.notes &&
              ride.status == RideStatus.Requested
          )
        }.provide(standardLayers),
        test("should create airport transfer ride") {
          val request = CreateRideRequest(
            clientId = vipClientId,
            companyId = testCompanyId,
            pickupLocation = Location("Airport Terminal 1"),
            dropoffLocation = Location("Hotel"),
            specifics = Some(RideSpecifics.AirportTransfer("KBP", "PS123"))
          )

          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(request)
          } yield assertTrue(
            ride.isAirportTransfer &&
              ride.specifics.exists { case RideSpecifics.AirportTransfer(code, flight, _) =>
                code == "KBP" && flight == "PS123"
              }
          )
        }.provide(standardLayers),
        // ── company isolation ──────────────────────────────────────────────
        test("should reject a client of a different company (company_isolation)") {
          val request = CreateRideRequest(
            clientId = otherCompanyClient.id,
            companyId = testCompanyId,
            pickupLocation = Location("A"),
            dropoffLocation = Location("B")
          )
          for {
            service <- ZIO.service[RideService]
            result  <- service.createRide(request).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("should reject an unknown client (PersonNotFound)") {
          val request = CreateRideRequest(
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000999")),
            companyId = testCompanyId,
            pickupLocation = Location("A"),
            dropoffLocation = Location("B")
          )
          for {
            service <- ZIO.service[RideService]
            result  <- service.createRide(request).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.PersonNotFound])
            case _                   => false
          })
        }.provide(standardLayers),
        // ── price/estimate carry-through (regression: BUG #6) ──────────────
        test("should persist the supplied estimatedPrice") {
          val request = CreateRideRequest(
            clientId = testClientId,
            companyId = testCompanyId,
            pickupLocation = Location("Start Point"),
            dropoffLocation = Location("End Point"),
            estimatedPrice = Some(BigDecimal("42.50"))
          )
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(request)
          } yield assertTrue(ride.estimatedPrice.contains(BigDecimal("42.50")))
        }.provide(standardLayers),
        test("should leave estimatedPrice None when no price is supplied") {
          val request = CreateRideRequest(
            clientId = testClientId,
            companyId = testCompanyId,
            pickupLocation = Location("Start Point"),
            dropoffLocation = Location("End Point")
          )
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(request)
          } yield assertTrue(ride.estimatedPrice.isEmpty)
        }.provide(standardLayers)
      ),
      suite("assignDriver")(
        test("happy path: Requested ride + valid driver same company → Assigned") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(
            assigned.status == RideStatus.Assigned &&
              assigned.driverId.contains(testDriverId)
          )
        }.provide(standardLayers),
        test("concurrent assignment: exactly one of two racing assigns wins") {
          // Two dispatchers assign different drivers to the same Requested ride at the
          // same time. The atomic compare-and-set (updateIfStatus) must let exactly one
          // win; the loser gets InvalidStatusTransition, never a silent overwrite.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            results   <- ZIO.collectAllPar(
                           List(
                             service.assignDriver(ride.id, testDriverId).exit,
                             service.assignDriver(ride.id, testDriver2Id).exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield {
            val failures = results.collect { case Exit.Failure(c) => c }
            assertTrue(
              results.count(_.isSuccess) == 1,
              failures.size == 1,
              failures.head.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition]),
              finalRide.status == RideStatus.Assigned,
              finalRide.driverId.contains(testDriverId) || finalRide.driverId.contains(testDriver2Id)
            )
          }
        }.provide(standardLayers),
        test("should fail when ride is not in Requested status") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.assignDriver(assigned.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when driver not found") {
          val unknownDriverId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.assignDriver(ride.id, unknownDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.DriverNotFound])
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when driver belongs to different company") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.assignDriver(ride.id, wrongCompanyDriver.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("should fail when person is not a Driver role") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.assignDriver(ride.id, clientPerson.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("driver_role", _) => true
                case _                                                 => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        // ── multi-role (dispatcher-can-drive) ──────────────────────────────
        test("dispatcher-driver (roles={Dispatcher,Driver}) can be assigned") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, dispatcherDriverId)
          } yield assertTrue(
            assigned.status == RideStatus.Assigned &&
              assigned.driverId.contains(dispatcherDriverId)
          )
        }.provide(standardLayers),
        test("pure dispatcher (roles={Dispatcher}) cannot be assigned") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.assignDriver(ride.id, pureDispatcherId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("driver_role", _) => true
                case _                                                 => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("company-mismatch still blocks dispatcher-driver") {
          // A dispatcher-driver from a different company must not be assignable.
          val foreignDDId         = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000055"))
          val foreignDD           = Person(
            id = foreignDDId,
            name = "Foreign DD",
            email = "foreign@example.com",
            role = PersonRole.Dispatcher,
            companyId = Some(otherCompanyId),
            roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
          )
          val repoWithForeignDD   = TestPersonRepository(
            Map(
              testDriver.id         -> testDriver,
              testDriver2.id        -> testDriver2,
              wrongCompanyDriver.id -> wrongCompanyDriver,
              clientPerson.id       -> clientPerson,
              vipClient.id          -> vipClient,
              testClient.id         -> testClient,
              dispatcherDriver.id   -> dispatcherDriver,
              pureDispatcher.id     -> pureDispatcher,
              foreignDDId           -> foreignDD
            )
          )
          val layersWithForeignDD =
            (InMemoryRideRepository.layer ++
              ZLayer.succeed[PersonRepository](repoWithForeignDD) ++
              EventHub.layer ++
              noopEmailSms ++
              AuditService.inMemory ++
              BlacklistRepository.inMemory ++
              GeocodingService.noop ++
              ExpenseRepository.inMemory ++
              PickupTimeService.noopLayer ++
              noopAvailabilityChecker) >+> RideService.layer

          (for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.assignDriver(ride.id, foreignDDId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })).provide(layersWithForeignDD)
        }
      ),
      suite("startRide")(
        test("happy path: Assigned → InProgress with startTime") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            started  <- service.startRide(assigned.id, testDriverId)
          } yield assertTrue(
            started.status == RideStatus.InProgress &&
              started.startTime.isDefined
          )
        }.provide(standardLayers),
        test("fails when ride is not Assigned") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.startRide(ride.id, testDriverId).exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("concurrent start: two racing starts, exactly one wins") {
          // Two callers start the same Assigned ride at once. The atomic CAS must let exactly one
          // win; the loser gets InvalidStatusTransition, never a silent overwrite.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            results   <- ZIO.collectAllPar(
                           List(
                             service.startRide(assigned.id, testDriverId).exit,
                             service.startRide(assigned.id, testDriverId).exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield {
            val failures = results.collect { case Exit.Failure(c) => c }
            assertTrue(
              results.count(_.isSuccess) == 1,
              failures.size == 1,
              failures.head.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition]),
              finalRide.status == RideStatus.InProgress
            )
          }
        }.provide(standardLayers),
        test("concurrent start vs cancel: persisted status matches a CAS winner") {
          // A driver starts while a dispatcher cancels the same Assigned ride. Because cancel is
          // legal from both Assigned and InProgress, both can legitimately apply in sequence
          // (Assigned → InProgress → Cancelled) — so this is NOT a one-wins race. What we assert is
          // that the persisted status is one that a *successful* call actually produced — i.e. the
          // DB reflects a real applied transition, not a value no caller reported.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            results   <- ZIO.collectAllPar(
                           List(
                             service.startRide(assigned.id, testDriverId).exit,
                             service.cancelRide(assigned.id, pureDispatcherId, PersonRole.Dispatcher).exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield {
            val succeededStatuses = results.collect { case Exit.Success(r) => r.status }
            assertTrue(
              // at least one applied, and the DB status is one that a successful call produced
              succeededStatuses.nonEmpty,
              succeededStatuses.contains(finalRide.status),
              finalRide.status == RideStatus.InProgress || finalRide.status == RideStatus.Cancelled
            )
          }
        }.provide(standardLayers)
      ),
      suite("completeRide")(
        test("happy path: InProgress → Completed with endTime") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
          } yield assertTrue(
            completed.status == RideStatus.Completed &&
              completed.endTime.isDefined
          )
        }.provide(standardLayers),
        test("fails when ride is not InProgress") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.completeRide(ride.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("fails when already Completed") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            result    <- service.completeRide(completed.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("concurrent complete vs cancel: exactly one wins, no lost write") {
          // A ride is completed while it is being cancelled. The atomic CAS lets exactly one apply;
          // the ride must not 'un-complete' silently — it ends Completed or Cancelled, consistently.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            results   <- ZIO.collectAllPar(
                           List(
                             service.completeRide(started.id).exit,
                             service.cancelRide(started.id, pureDispatcherId, PersonRole.Dispatcher).exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield assertTrue(
            results.count(_.isSuccess) == 1,
            results.count(_.isFailure) == 1,
            finalRide.status == RideStatus.Completed || finalRide.status == RideStatus.Cancelled
          )
        }.provide(standardLayers)
      ),
      suite("cancelRide")(
        test("cancels Requested ride") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            cancelled <- service.cancelRide(ride.id, testClientId, PersonRole.Client)
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(standardLayers),
        test("cancels Assigned ride") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            cancelled <- service.cancelRide(assigned.id, testClientId, PersonRole.Client)
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(standardLayers),
        test("cancels InProgress ride") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            cancelled <- service.cancelRide(started.id, testClientId, PersonRole.Client)
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(standardLayers),
        test("fails when Completed") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            result    <- service.cancelRide(completed.id, testClientId, PersonRole.Client).exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("ClientSecretary can cancel a ride (no MatchError)") {
          val clientSecretaryId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            cancelled <- service.cancelRide(ride.id, clientSecretaryId, PersonRole.ClientSecretary)
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(standardLayers)
      ),
      suite("cancelRideWithReason")(
        test("sets reason, fee, and cancelledBy") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            cancelled <- service.cancelRideWithReason(
                           ride.id,
                           testClientId,
                           PersonRole.Client,
                           CancelRideRequest("client_request", Some(BigDecimal(10.00)))
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("client_request") &&
              cancelled.cancellationFee.contains(BigDecimal(10.00)) &&
              cancelled.cancelledBy.contains(testClientId)
          )
        }.provide(standardLayers),
        // Regression: a negative cancellation fee would credit the client instead
        // of charging them. The service must reject it even when called directly
        // (the ride stays in its original status, not cancelled with a bad fee).
        test("rejects a negative fee") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  testClientId,
                  PersonRole.Client,
                  CancelRideRequest("client_request", Some(BigDecimal(-100.00)))
                )
                .exit
            after   <- service.getRideById(ride.id)
          } yield assertTrue(
            result.isFailure,
            after.status != RideStatus.Cancelled
          )
        }.provide(standardLayers),
        test("concurrent cancellations: winner's reason/fee/cancelledBy are consistent") {
          // Two callers cancel the same ride with different reason/fee/cancelledBy. Exactly one
          // applies; the persisted reason+fee+cancelledBy must all come from the same winner — the
          // loser must not partially overwrite the winner's fields.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            results   <- ZIO.collectAllPar(
                           List(
                             service
                               .cancelRideWithReason(
                                 ride.id,
                                 testClientId,
                                 PersonRole.Client,
                                 CancelRideRequest("client_request", Some(BigDecimal(10.00)))
                               )
                               .exit,
                             service
                               .cancelRideWithReason(
                                 ride.id,
                                 pureDispatcherId,
                                 PersonRole.Dispatcher,
                                 CancelRideRequest("client_no_show", Some(BigDecimal(25.00)))
                               )
                               .exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield {
            // The winner is fully self-consistent: client→client_request/10, dispatcher→client_no_show/25.
            val clientWon     =
              finalRide.cancellationReason.contains("client_request") &&
                finalRide.cancellationFee.contains(BigDecimal(10.00)) &&
                finalRide.cancelledBy.contains(testClientId)
            val dispatcherWon =
              finalRide.cancellationReason.contains("client_no_show") &&
                finalRide.cancellationFee.contains(BigDecimal(25.00)) &&
                finalRide.cancelledBy.contains(pureDispatcherId)
            assertTrue(
              results.count(_.isSuccess) == 1,
              results.count(_.isFailure) == 1,
              finalRide.status == RideStatus.Cancelled,
              clientWon || dispatcherWon
            )
          }
        }.provide(standardLayers),
        test("fails when Completed") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            result    <-
              service
                .cancelRideWithReason(
                  completed.id,
                  testClientId,
                  PersonRole.Client,
                  CancelRideRequest("client_request")
                )
                .exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        // A client may only state client-side reasons. Operational reasons (client no-show, driver
        // unavailable, vehicle issue) are staff-only — a forged client request citing them must be
        // rejected, and the ride must stay in its original status.
        test("rejects a staff-only reason from a client") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  testClientId,
                  PersonRole.Client,
                  CancelRideRequest("client_no_show")
                )
                .exit
            after   <- service.getRideById(ride.id)
          } yield assertTrue(
            result.isFailure,
            after.status != RideStatus.Cancelled
          )
        }.provide(standardLayers),
        // The same operational reason a client is forbidden from stating is allowed for staff.
        test("allows a staff-only reason from a dispatcher") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            cancelled <- service.cancelRideWithReason(
                           ride.id,
                           pureDispatcherId,
                           PersonRole.Dispatcher,
                           CancelRideRequest("client_no_show")
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled,
            cancelled.cancellationReason.contains("client_no_show")
          )
        }.provide(standardLayers),
        // An unknown reason string is rejected for any role, leaving the ride unchanged.
        test("rejects an unknown reason") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <-
              service
                .cancelRideWithReason(
                  ride.id,
                  pureDispatcherId,
                  PersonRole.Dispatcher,
                  CancelRideRequest("not_a_real_reason")
                )
                .exit
            after   <- service.getRideById(ride.id)
          } yield assertTrue(
            result.isFailure,
            after.status != RideStatus.Cancelled
          )
        }.provide(standardLayers)
      ),
      suite("updateRideStatus")(
        test("driver updates own ride to InProgress") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            updated  <- service.updateRideStatus(
                          assigned.id,
                          UpdateRideStatusRequest(RideStatus.InProgress),
                          testDriverId,
                          PersonRole.Driver
                        )
          } yield assertTrue(
            updated.status == RideStatus.InProgress &&
              updated.startTime.isDefined
          )
        }.provide(standardLayers),
        test("concurrent identical updates via updateRideStatus: exactly one wins") {
          // Two callers drive the same Assigned ride to InProgress through updateRideStatus at once.
          // Both transitions share the same expected status {Assigned}, so the atomic CAS must let
          // exactly one apply; the loser gets InvalidStatusTransition, never a silent double-apply.
          // (Two *different* targets like InProgress vs Cancelled are not a race — Assigned →
          //  InProgress → Cancelled is a valid sequential path, so both legitimately succeed.)
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            results   <- ZIO.collectAllPar(
                           List(
                             service
                               .updateRideStatus(
                                 assigned.id,
                                 UpdateRideStatusRequest(RideStatus.InProgress),
                                 testDriverId,
                                 PersonRole.Driver
                               )
                               .exit,
                             service
                               .updateRideStatus(
                                 assigned.id,
                                 UpdateRideStatusRequest(RideStatus.InProgress),
                                 pureDispatcherId,
                                 PersonRole.Dispatcher
                               )
                               .exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield assertTrue(
            results.count(_.isSuccess) == 1,
            results.count(_.isFailure) == 1,
            finalRide.status == RideStatus.InProgress
          )
        }.provide(standardLayers),
        test("driver cannot update another driver's ride") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.InProgress),
                  testDriver2Id,
                  PersonRole.Driver
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("dispatcher can update any ride") {
          val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            updated  <- service.updateRideStatus(
                          assigned.id,
                          UpdateRideStatusRequest(RideStatus.InProgress),
                          dispatcherId,
                          PersonRole.Dispatcher
                        )
          } yield assertTrue(updated.status == RideStatus.InProgress)
        }.provide(standardLayers),
        test("client role rejected") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.InProgress),
                  testClientId,
                  PersonRole.Client
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("invalid transition rejected") {
          val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            // Assigned → Completed is invalid (must go through InProgress first)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.Completed),
                  dispatcherId,
                  PersonRole.Dispatcher
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("sets endTime when completing") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.updateRideStatus(
                           assigned.id,
                           UpdateRideStatusRequest(RideStatus.InProgress),
                           testDriverId,
                           PersonRole.Driver
                         )
            completed <- service.updateRideStatus(
                           started.id,
                           UpdateRideStatusRequest(RideStatus.Completed),
                           testDriverId,
                           PersonRole.Driver
                         )
          } yield assertTrue(
            completed.endTime.isDefined &&
              completed.startTime.isDefined
          )
        }.provide(standardLayers)
      ),
      suite("updateRideDetails")(
        test("updates pickup on editable ride") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(pickupLocation = Some(Location("New Pickup"))),
                         testClientId,
                         PersonRole.Client,
                         Some(testCompanyId)
                       )
          } yield assertTrue(updated.pickupLocation == Location("New Pickup"))
        }.provide(standardLayers),
        test("fails when InProgress") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            started  <- service.startRide(assigned.id, testDriverId)
            result   <-
              service
                .updateRideDetails(
                  started.id,
                  UpdateRideDetailsRequest(pickupLocation = Some(Location("X"))),
                  testClientId,
                  PersonRole.Client,
                  Some(testCompanyId)
                )
                .exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("fails when Completed") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            result    <-
              service
                .updateRideDetails(
                  completed.id,
                  UpdateRideDetailsRequest(pickupLocation = Some(Location("X"))),
                  testClientId,
                  PersonRole.Client,
                  Some(testCompanyId)
                )
                .exit
          } yield assertTrue(result.isFailure)
        }.provide(standardLayers),
        test("creator can update") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(notes = Some("Updated")),
                         testClientId,
                         PersonRole.Client,
                         Some(testCompanyId)
                       )
          } yield assertTrue(updated.notes.contains("Updated"))
        }.provide(standardLayers),
        test("dispatcher can update") {
          val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            updated <- service.updateRideDetails(
                         ride.id,
                         UpdateRideDetailsRequest(notes = Some("Dispatch update")),
                         dispatcherId,
                         PersonRole.Dispatcher,
                         Some(testCompanyId)
                       )
          } yield assertTrue(updated.notes.contains("Dispatch update"))
        }.provide(standardLayers),
        test("non-creator non-dispatcher rejected") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <-
              service
                .updateRideDetails(
                  ride.id,
                  UpdateRideDetailsRequest(notes = Some("X")),
                  testDriverId,
                  PersonRole.Driver,
                  Some(testCompanyId)
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("reassignDriver")(
        test("happy path reassignment") {
          for {
            service    <- ZIO.service[RideService]
            ride       <- service.createRide(
                            CreateRideRequest(
                              clientId = testClientId,
                              companyId = testCompanyId,
                              pickupLocation = Location("A"),
                              dropoffLocation = Location("B")
                            )
                          )
            assigned   <- service.assignDriver(ride.id, testDriverId)
            reassigned <- service.reassignDriver(assigned.id, testDriver2Id)
          } yield assertTrue(
            reassigned.driverId.contains(testDriver2Id) &&
              reassigned.status == RideStatus.Assigned
          )
        }.provide(standardLayers),
        test("fails when ride is not Assigned") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            result  <- service.reassignDriver(ride.id, testDriver2Id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("fails when new driver is wrong company") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.reassignDriver(assigned.id, wrongCompanyDriver.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("fails when new person is not a driver") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.reassignDriver(assigned.id, clientPerson.id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("driver_role", _) => true
                case _                                                 => false
              }
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("markPayment")(
        test("sets payment status and method") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            paid      <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
          } yield assertTrue(
            paid.paymentStatus == PaymentStatus.Paid &&
              paid.paymentMethod.contains(PaymentMethod.Cash)
          )
        }.provide(standardLayers),
        test("sets paidAt for 'paid' status") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            paid      <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Card))
          } yield assertTrue(paid.paidAt.isDefined)
        }.provide(standardLayers),
        test("does not set paidAt for other statuses") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            pending   <- service.markPayment(completed.id, PaymentStatus.Pending, None)
          } yield assertTrue(pending.paidAt.isEmpty)
        }.provide(standardLayers),
        test("fails to mark a non-Completed ride as Paid (atomic CAS)") {
          // Paying is the only status-gated payment transition: the atomic CAS (Set(Completed))
          // rejects `Paid` on a ride that is not Completed, so a cancel racing a payment can never
          // flip a cancelled/in-progress ride to Paid. (Non-Paid statuses stay legal in any status.)
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            started  <- service.startRide(assigned.id, testDriverId)
            result   <- service.markPayment(started.id, PaymentStatus.Paid, Some(PaymentMethod.Cash)).exit
            after    <- service.getRideById(ride.id)
          } yield assertTrue(
            result.isFailure,
            after.paymentStatus != PaymentStatus.Paid
          )
        }.provide(standardLayers),
        test("concurrent complete vs markPayment: payment only applies once Completed") {
          // A ride is completed while a payment is attempted concurrently. The payment must not
          // apply to the still-InProgress ride; if it fails it can be retried after completion.
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            results   <- ZIO.collectAllPar(
                           List(
                             service.completeRide(started.id).exit,
                             service.markPayment(started.id, PaymentStatus.Paid, Some(PaymentMethod.Cash)).exit
                           )
                         )
            finalRide <- service.getRideById(ride.id)
          } yield {
            // Completion always wins (it is the only path to Completed). The payment either raced in
            // before completion and was rejected by the CAS, or it never applied — so the loser does
            // not silently overwrite. If the payment failed, the ride must still be unpaid.
            val completeSucceeded = results.head.isSuccess
            val paymentSucceeded  = results.lift(1).exists(_.isSuccess)
            assertTrue(
              completeSucceeded,
              finalRide.status == RideStatus.Completed,
              paymentSucceeded || finalRide.paymentStatus != PaymentStatus.Paid
            )
          }
        }.provide(standardLayers)
      ),
      suite("getUnpaidCompletedRides")(
        test("returns unpaid completed rides") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            unpaid    <- service.getUnpaidCompletedRides(testCompanyId)
          } yield assertTrue(unpaid.exists(_.id == completed.id))
        }.provide(standardLayers),
        test("excludes paid rides") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            _         <- service.markPayment(completed.id, PaymentStatus.Paid, Some(PaymentMethod.Cash))
            unpaid    <- service.getUnpaidCompletedRides(testCompanyId)
          } yield assertTrue(!unpaid.exists(_.id == completed.id))
        }.provide(standardLayers)
      ),
      suite("assignDriver VIP/preferred")(
        test("sets isVipRide for VIP client") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = vipClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(assigned.isVipRide)
        }.provide(standardLayers),
        test("sets preferredDriverUsed when preferred driver assigned") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = vipClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(assigned.preferredDriverUsed)
        }.provide(standardLayers),
        test("no VIP flags for non-VIP client") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(!assigned.isVipRide && !assigned.preferredDriverUsed)
        }.provide(standardLayers)
      ),
      suite("schedule conflict detection")(
        test("assignDriver fails when driver has overlapping ride") {
          val pickupAt = Instant.now().plusSeconds(7200) // 2 hours from now
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B"),
                           scheduledTime = Some(pickupAt)
                         )
                       )
            _       <- service.assignDriver(ride1.id, testDriverId)
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = vipClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D"),
                           scheduledTime = Some(pickupAt.plusSeconds(600)) // 10 min later
                         )
                       )
            result  <- service.assignDriver(ride2.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ScheduleConflict(_) => true
                case _                             => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("assignDriver succeeds when rides are far enough apart (back-to-back, just past the window)") {
          // Each ride occupies [start, start + 60min duration + 30min buffer) = a 90-min window.
          // A 91-min gap means the windows no longer touch, so back-to-back rides are allowed.
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service  <- ZIO.service[RideService]
            ride1    <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B"),
                            scheduledTime = Some(pickupAt)
                          )
                        )
            _        <- service.assignDriver(ride1.id, testDriverId)
            ride2    <- service.createRide(
                          CreateRideRequest(
                            clientId = vipClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("C"),
                            dropoffLocation = Location("D"),
                            scheduledTime = Some(pickupAt.plusSeconds(91 * 60)) // 91 min later — just past the window
                          )
                        )
            assigned <- service.assignDriver(ride2.id, testDriverId)
          } yield assertTrue(assigned.status == RideStatus.Assigned)
        }.provide(standardLayers),
        test("assignDriver fails when windows genuinely overlap (45 min apart)") {
          // existingEnd = start + 90min; candidateStart = start + 45min < existingEnd → windows overlap → conflict.
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B"),
                           scheduledTime = Some(pickupAt)
                         )
                       )
            _       <- service.assignDriver(ride1.id, testDriverId)
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = vipClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D"),
                           scheduledTime = Some(pickupAt.plusSeconds(45 * 60)) // 45 min later — inside the window
                         )
                       )
            result  <- service.assignDriver(ride2.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ScheduleConflict(_) => true
                case _                             => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("reassignDriver checks conflicts for new driver") {
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B"),
                           scheduledTime = Some(pickupAt)
                         )
                       )
            _       <- service.assignDriver(ride1.id, testDriver2Id)
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = vipClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D"),
                           scheduledTime = Some(pickupAt.plusSeconds(300)) // 5 min later
                         )
                       )
            _       <- service.assignDriver(ride2.id, testDriverId)
            result  <- service.reassignDriver(ride2.id, testDriver2Id).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ScheduleConflict(_) => true
                case _                             => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("reassignDriver with overrideScheduleConflict bypasses the conflict") {
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service    <- ZIO.service[RideService]
            ride1      <- service.createRide(
                            CreateRideRequest(
                              clientId = testClientId,
                              companyId = testCompanyId,
                              pickupLocation = Location("A"),
                              dropoffLocation = Location("B"),
                              scheduledTime = Some(pickupAt)
                            )
                          )
            _          <- service.assignDriver(ride1.id, testDriver2Id)
            ride2      <- service.createRide(
                            CreateRideRequest(
                              clientId = vipClientId,
                              companyId = testCompanyId,
                              pickupLocation = Location("C"),
                              dropoffLocation = Location("D"),
                              scheduledTime = Some(pickupAt.plusSeconds(300)) // 5 min later
                            )
                          )
            _          <- service.assignDriver(ride2.id, testDriverId)
            reassigned <- service.reassignDriver(ride2.id, testDriver2Id, overrideScheduleConflict = true)
          } yield assertTrue(reassigned.driverId.contains(testDriver2Id))
        }.provide(standardLayers),
        test("override does not bypass company isolation") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .reassignDriver(assigned.id, wrongCompanyDriver.id, overrideScheduleConflict = true)
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.BusinessRuleViolation("company_isolation", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("completed rides do not cause conflicts") {
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service   <- ZIO.service[RideService]
            ride1     <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B"),
                             scheduledTime = Some(pickupAt)
                           )
                         )
            assigned  <- service.assignDriver(ride1.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            _         <- service.completeRide(started.id)
            ride2     <- service.createRide(
                           CreateRideRequest(
                             clientId = vipClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("C"),
                             dropoffLocation = Location("D"),
                             scheduledTime = Some(pickupAt)
                           )
                         )
            assigned2 <- service.assignDriver(ride2.id, testDriverId)
          } yield assertTrue(assigned2.status == RideStatus.Assigned)
        }.provide(standardLayers)
      ),
      suite("createRide validation")(
        test("rejects pickup time in the past") {
          val pastTime = Instant.now().minusSeconds(3600)
          for {
            service <- ZIO.service[RideService]
            result  <-
              service
                .createRide(
                  CreateRideRequest(
                    clientId = testClientId,
                    companyId = testCompanyId,
                    pickupLocation = Location("A"),
                    dropoffLocation = Location("B"),
                    scheduledTime = Some(pastTime)
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(msg) => msg.contains("future")
                case _                              => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("rejects same pickup and dropoff address") {
          for {
            service <- ZIO.service[RideService]
            result  <-
              service
                .createRide(
                  CreateRideRequest(
                    clientId = testClientId,
                    companyId = testCompanyId,
                    pickupLocation = Location("Same Place"),
                    dropoffLocation = Location("Same Place")
                  )
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(msg) => msg.contains("different")
                case _                              => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("allows ride without scheduledTime (no time validation)") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
          } yield assertTrue(ride.status == RideStatus.Requested)
        }.provide(standardLayers)
      ),
      suite("ride lifecycle")(
        test("create → assign → start → complete") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
          } yield assertTrue(
            ride.status == RideStatus.Requested &&
              assigned.status == RideStatus.Assigned &&
              started.status == RideStatus.InProgress &&
              completed.status == RideStatus.Completed
          )
        }.provide(standardLayers),
        test("create → assign → cancel") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            cancelled <- service.cancelRide(assigned.id, testClientId, PersonRole.Client)
          } yield assertTrue(cancelled.status == RideStatus.Cancelled)
        }.provide(standardLayers),
        test("create → assign → reassign → start → complete") {
          for {
            service    <- ZIO.service[RideService]
            ride       <- service.createRide(
                            CreateRideRequest(
                              clientId = testClientId,
                              companyId = testCompanyId,
                              pickupLocation = Location("A"),
                              dropoffLocation = Location("B")
                            )
                          )
            assigned   <- service.assignDriver(ride.id, testDriverId)
            reassigned <- service.reassignDriver(assigned.id, testDriver2Id)
            started    <- service.startRide(reassigned.id, testDriver2Id)
            completed  <- service.completeRide(started.id)
          } yield assertTrue(
            completed.status == RideStatus.Completed &&
              completed.driverId.contains(testDriver2Id)
          )
        }.provide(standardLayers)
      ),
      suite("query methods")(
        test("getRidesByCompany isolates by company") {
          for {
            service <- ZIO.service[RideService]
            _       <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            rides   <- service.getRidesByCompany(testCompanyId)
            other   <- service.getRidesByCompany(otherCompanyId)
          } yield assertTrue(rides.nonEmpty && other.isEmpty)
        }.provide(standardLayers),
        test("getDriverRides returns assigned rides") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            _       <- service.assignDriver(ride.id, testDriverId)
            rides   <- service.getDriverRides(testDriverId, testCompanyId)
          } yield assertTrue(rides.nonEmpty && rides.forall(_.driverId.contains(testDriverId)))
        }.provide(standardLayers),
        test("getClientRides returns client's rides") {
          for {
            service <- ZIO.service[RideService]
            _       <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            rides   <- service.getClientRides(testClientId, testCompanyId)
          } yield assertTrue(rides.nonEmpty && rides.forall(_.clientId == testClientId))
        }.provide(standardLayers),
        // Regression for the IDOR: a dispatcher of another company must not see a driver's or
        // client's rides. Querying with the wrong companyId returns nothing, even though the
        // driver/client id is valid.
        test("getDriverRides does not leak rides to another company") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            _       <- service.assignDriver(ride.id, testDriverId)
            mine    <- service.getDriverRides(testDriverId, testCompanyId)
            leaked  <- service.getDriverRides(testDriverId, otherCompanyId)
          } yield assertTrue(mine.nonEmpty && leaked.isEmpty)
        }.provide(standardLayers),
        test("getClientRides does not leak rides to another company") {
          for {
            service <- ZIO.service[RideService]
            _       <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            mine    <- service.getClientRides(testClientId, testCompanyId)
            leaked  <- service.getClientRides(testClientId, otherCompanyId)
          } yield assertTrue(mine.nonEmpty && leaked.isEmpty)
        }.provide(standardLayers),
        test("getCancellationStats groups by reason") {
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D")
                         )
                       )
            _       <- service.cancelRideWithReason(
                         ride1.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request")
                       )
            _       <- service.cancelRideWithReason(
                         ride2.id,
                         testClientId,
                         PersonRole.Client,
                         CancelRideRequest("client_request")
                       )
            stats   <- service.getCancellationStats(testCompanyId)
          } yield assertTrue(stats.getOrElse("client_request", 0) >= 2)
        }.provide(standardLayers)
      ),
      // -- Edge cases added by test audit 2026-06 -------------------------------
      suite("schedule conflict boundary")(
        test("conflict at gap exactly 89 minutes (just under 90 min threshold)") {
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B"),
                           scheduledTime = Some(pickupAt)
                         )
                       )
            _       <- service.assignDriver(ride1.id, testDriverId)
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = vipClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D"),
                           scheduledTime = Some(pickupAt.plusSeconds(89 * 60)) // 89 min later
                         )
                       )
            result  <- service.assignDriver(ride2.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ScheduleConflict(_) => true
                case _                             => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("conflict uses requestTime when scheduledTime is absent") {
          // Both rides created back-to-back without scheduledTime → requestTime gap ≈ 0 → conflict
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(
                         CreateRideRequest(
                           clientId = testClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("A"),
                           dropoffLocation = Location("B")
                         )
                       )
            _       <- service.assignDriver(ride1.id, testDriverId)
            ride2   <- service.createRide(
                         CreateRideRequest(
                           clientId = vipClientId,
                           companyId = testCompanyId,
                           pickupLocation = Location("C"),
                           dropoffLocation = Location("D")
                         )
                       )
            result  <- service.assignDriver(ride2.id, testDriverId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ScheduleConflict(_) => true
                case _                             => false
              }
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("updateRideStatus authorization edge cases")(
        test("secretary role rejected") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.InProgress),
                  testClientId,
                  PersonRole.Secretary
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("rejects target status Assigned via updateRideStatus") {
          val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.Assigned),
                  dispatcherId,
                  PersonRole.Dispatcher
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers),
        test("rejects target status Requested via updateRideStatus") {
          val dispatcherId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(
                          CreateRideRequest(
                            clientId = testClientId,
                            companyId = testCompanyId,
                            pickupLocation = Location("A"),
                            dropoffLocation = Location("B")
                          )
                        )
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <-
              service
                .updateRideStatus(
                  assigned.id,
                  UpdateRideStatusRequest(RideStatus.Requested),
                  dispatcherId,
                  PersonRole.Dispatcher
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
            case _                   => false
          })
        }.provide(standardLayers)
      ),
      suite("markPayment edge cases")(
        test("paymentMethod=None preserves existing method") {
          for {
            service   <- ZIO.service[RideService]
            ride      <- service.createRide(
                           CreateRideRequest(
                             clientId = testClientId,
                             companyId = testCompanyId,
                             pickupLocation = Location("A"),
                             dropoffLocation = Location("B")
                           )
                         )
            assigned  <- service.assignDriver(ride.id, testDriverId)
            started   <- service.startRide(assigned.id, testDriverId)
            completed <- service.completeRide(started.id)
            // First set a method, then update status with None — method must persist
            withCash  <- service.markPayment(completed.id, PaymentStatus.Pending, Some(PaymentMethod.Cash))
            updated   <- service.markPayment(withCash.id, PaymentStatus.Paid, None)
          } yield assertTrue(updated.paymentMethod.contains(PaymentMethod.Cash))
        }.provide(standardLayers)
      )
    )
}
