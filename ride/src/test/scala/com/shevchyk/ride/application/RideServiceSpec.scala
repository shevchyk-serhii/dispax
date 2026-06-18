package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService, EmailSmsService, RideConfirmationData, GeocodingService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.{PersonRepository, InMemoryPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
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

    override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
      persons.values.filter(_.companyId.contains(companyId)).toList
    )
    override def findAll(): Task[List[Person]]                             = ZIO.succeed(persons.values.toList)
    override def update(person: Person): Task[Person]                      = ZIO.succeed(person)
    override def delete(id: PersonId): Task[Unit]                          = ZIO.unit

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
      dispatcherDriver.id   -> dispatcherDriver,
      pureDispatcher.id     -> pureDispatcher
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
        }.provide(
          InMemoryRideRepository.layer,
          InMemoryPersonRepository.layer,
          EventHub.layer,
          noopEmailSms,
          AuditService.inMemory,
          BlacklistRepository.inMemory,
          GeocodingService.noop,
          ExpenseRepository.inMemory,
          RideService.layer
        ),
        test("should create airport transfer ride") {
          val request = CreateRideRequest(
            clientId = PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200")),
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
        }.provide(
          InMemoryRideRepository.layer,
          InMemoryPersonRepository.layer,
          EventHub.layer,
          noopEmailSms,
          AuditService.inMemory,
          BlacklistRepository.inMemory,
          GeocodingService.noop,
          ExpenseRepository.inMemory,
          RideService.layer
        )
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
              GeocodingService.noop ++ ExpenseRepository.inMemory) >+> RideService.layer

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
                           CancelRideRequest("no_show", Some(BigDecimal(10.00)))
                         )
          } yield assertTrue(
            cancelled.status == RideStatus.Cancelled &&
              cancelled.cancellationReason.contains("no_show") &&
              cancelled.cancellationFee.contains(BigDecimal(10.00)) &&
              cancelled.cancelledBy.contains(testClientId)
          )
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
                .cancelRideWithReason(completed.id, testClientId, PersonRole.Client, CancelRideRequest("late"))
                .exit
          } yield assertTrue(result.isFailure)
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
                case RideError.BusinessRuleViolation("schedule_conflict", _) => true
                case _                                                       => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("assignDriver succeeds when rides are far enough apart") {
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
                            scheduledTime = Some(pickupAt.plusSeconds(5400)) // 90 min later
                          )
                        )
            assigned <- service.assignDriver(ride2.id, testDriverId)
          } yield assertTrue(assigned.status == RideStatus.Assigned)
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
                case RideError.BusinessRuleViolation("schedule_conflict", _) => true
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
            rides   <- service.getDriverRides(testDriverId)
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
            rides   <- service.getClientRides(testClientId)
          } yield assertTrue(rides.nonEmpty && rides.forall(_.clientId == testClientId))
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
            _       <- service.cancelRideWithReason(ride1.id, testClientId, PersonRole.Client, CancelRideRequest("no_show"))
            _       <- service.cancelRideWithReason(ride2.id, testClientId, PersonRole.Client, CancelRideRequest("no_show"))
            stats   <- service.getCancellationStats(testCompanyId)
          } yield assertTrue(stats.getOrElse("no_show", 0) >= 2)
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
                case RideError.BusinessRuleViolation("schedule_conflict", _) => true
                case _                                                       => false
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
                case RideError.BusinessRuleViolation("schedule_conflict", _) => true
                case _                                                       => false
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
