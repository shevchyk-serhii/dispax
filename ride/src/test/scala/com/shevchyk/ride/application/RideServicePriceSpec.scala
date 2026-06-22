package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  EventHub,
  AuditService,
  EmailSmsService,
  RideConfirmationData,
  GeocodingService,
  DriverAvailabilityChecker,
  UnavailabilitySlot
}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

/**
 * Unit tests for RideService.setRidePrice, getDriverRides (company-isolation), and getRidesByDrivers.
 *
 * All tests use InMemoryRideRepository — no database, no containers.
 */
object RideServicePriceSpec extends ZIOSpecDefault {

  // ── IDs ────────────────────────────────────────────────────────────────────
  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testDriver2Id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val dispatcherId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000099"))

  // ── Persons ────────────────────────────────────────────────────────────────
  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@test.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val testDriver2 = Person(
    id = testDriver2Id,
    name = "Second Driver",
    email = "driver2@test.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val wrongCompanyDriver = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002")),
    name = "Other Driver",
    email = "other@test.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
  )

  val testClient = Person(
    id = testClientId,
    name = "Test Client",
    email = "client@test.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  val testDispatcher = Person(
    id = dispatcherId,
    name = "Test Dispatcher",
    email = "disp@test.com",
    role = PersonRole.Dispatcher,
    companyId = Some(testCompanyId)
  )

  // ── Person repo ────────────────────────────────────────────────────────────
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

    override def findByCompanyId(companyId: CompanyId): Task[List[Person]]       = ZIO.succeed(
      persons.values.filter(_.companyId.contains(companyId)).toList
    )
    override def findAll(): Task[List[Person]]                                   = ZIO.succeed(persons.values.toList)
    override def update(person: Person): Task[Person]                            = ZIO.succeed(person)
    override def delete(id: PersonId): Task[Unit]                                = ZIO.unit
    override def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit] = ZIO.unit

    override def findByStatus(status: UserStatus): Task[List[Person]]                         = ZIO.succeed(
      persons.values.filter(_.status == status).toList
    )
    override def searchByQuery(query: String): Task[List[Person]]                             = ZIO.succeed(Nil)
    override def updateLastLogin(id: PersonId): Task[Unit]                                    = ZIO.unit
    override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]    = ZIO.succeed(Nil)
    override def upsertDriverRow(personId: PersonId): Task[Unit]                              = ZIO.unit
    override def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                 = ZIO.succeed(None)
    override def setAvatar(id: PersonId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
    override def deleteAvatar(id: PersonId): Task[Unit]                                       = ZIO.unit
  }

  val testPersonRepo = TestPersonRepository(
    Map(
      testDriver.id         -> testDriver,
      testDriver2.id        -> testDriver2,
      wrongCompanyDriver.id -> wrongCompanyDriver,
      testClient.id         -> testClient,
      testDispatcher.id     -> testDispatcher
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
      noopAvailabilityChecker) >+> RideService.layer

  // ── Helpers ────────────────────────────────────────────────────────────────

  private def mkRide(
      clientId: PersonId = testClientId,
      companyId: CompanyId = testCompanyId
  ) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B")
  )

  /**
   * Create a ride and assign testDriver to it.
   */
  private def createAssignedRide(service: RideService) =
    for {
      ride     <- service.createRide(mkRide())
      assigned <- service.assignDriver(ride.id, testDriverId)
    } yield assigned

  // ── Spec ───────────────────────────────────────────────────────────────────
  def spec =
    suite("RideService.setRidePrice")(
      // ── Happy path ─────────────────────────────────────────────────────────
      suite("success cases")(
        test("dispatcher sets price → finalPrice is persisted as Some(price)") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            result   <- service.setRidePrice(assigned.id, 42.50, dispatcherId, PersonRole.Dispatcher, testCompanyId)
          } yield assertTrue(result.finalPrice.contains(BigDecimal("42.5")))
        }.provide(standardLayers),
        test("zero price is accepted (clear disputed charge)") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            result   <- service.setRidePrice(assigned.id, 0.0, dispatcherId, PersonRole.Dispatcher, testCompanyId)
          } yield assertTrue(result.finalPrice.contains(BigDecimal(0)))
        }.provide(standardLayers),
        test("assigned driver sets price on own ride → accepted") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            result   <- service.setRidePrice(assigned.id, 25.00, testDriverId, PersonRole.Driver, testCompanyId)
          } yield assertTrue(result.finalPrice.contains(BigDecimal("25.0")))
        }.provide(standardLayers),
        test("setRidePrice result is reflected in subsequent getRideById") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            _        <- service.setRidePrice(assigned.id, 99.99, dispatcherId, PersonRole.Dispatcher, testCompanyId)
            fetched  <- service.getRideById(assigned.id)
          } yield assertTrue(fetched.finalPrice.exists(_ == BigDecimal("99.99")))
        }.provide(standardLayers)
      ),
      // ── Negative price ──────────────────────────────────────────────────────
      suite("negative price validation")(
        test("negative price is rejected with ValidationError") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            result   <- service.setRidePrice(assigned.id, -1.0, dispatcherId, PersonRole.Dispatcher, testCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(_) => true
                case _                            => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("ride price remains unset after a rejected negative-price attempt") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            _        <- service.setRidePrice(assigned.id, -5.0, dispatcherId, PersonRole.Dispatcher, testCompanyId).exit
            fetched  <- service.getRideById(assigned.id)
          } yield assertTrue(fetched.finalPrice.isEmpty)
        }.provide(standardLayers)
      ),
      // ── Tenant isolation ───────────────────────────────────────────────────
      suite("tenant isolation")(
        test("companyId mismatch → UnauthorizedAccess") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            // Caller claims to be from otherCompanyId, but ride belongs to testCompanyId.
            result   <-
              service
                .setRidePrice(assigned.id, 50.0, dispatcherId, PersonRole.Dispatcher, otherCompanyId)
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("companyId mismatch does not mutate finalPrice") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            _        <-
              service
                .setRidePrice(assigned.id, 50.0, dispatcherId, PersonRole.Dispatcher, otherCompanyId)
                .exit
            fetched  <- service.getRideById(assigned.id)
          } yield assertTrue(fetched.finalPrice.isEmpty)
        }.provide(standardLayers)
      ),
      // ── Driver authorization ────────────────────────────────────────────────
      suite("driver ownership authorization")(
        test("driver not assigned to the ride is rejected with UnauthorizedAccess") {
          for {
            service  <- ZIO.service[RideService]
            // assigned to testDriverId; testDriver2 tries to set price
            assigned <- createAssignedRide(service)
            result   <- service.setRidePrice(assigned.id, 30.0, testDriver2Id, PersonRole.Driver, testCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("unassigned ride (no driverId) rejects a driver caller") {
          for {
            service <- ZIO.service[RideService]
            // Ride is Requested — no driver assigned yet.
            ride    <- service.createRide(mkRide())
            result  <- service.setRidePrice(ride.id, 20.0, testDriverId, PersonRole.Driver, testCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.UnauthorizedAccess])
            case _                   => false
          })
        }.provide(standardLayers),
        test("driver cannot set price on another driver's assigned ride — price is not mutated") {
          for {
            service  <- ZIO.service[RideService]
            assigned <- createAssignedRide(service)
            _        <- service.setRidePrice(assigned.id, 30.0, testDriver2Id, PersonRole.Driver, testCompanyId).exit
            fetched  <- service.getRideById(assigned.id)
          } yield assertTrue(fetched.finalPrice.isEmpty)
        }.provide(standardLayers)
      ),
      // ── getRidesByDrivers ──────────────────────────────────────────────────
      suite("getRidesByDrivers")(
        test("single valid driver returns their rides") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.getRidesByDrivers(List(testDriverId), None, None, testCompanyId)
          } yield assertTrue(result.exists(_.id == assigned.id))
        }.provide(standardLayers),
        test("foreign driverId (other company) returns empty list — no data leak") {
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            _       <- service.assignDriver(ride.id, testDriverId)
            // wrongCompanyDriver belongs to otherCompanyId; queried under testCompanyId → empty.
            result  <- service.getRidesByDrivers(List(wrongCompanyDriver.id), None, None, testCompanyId)
          } yield assertTrue(result.isEmpty)
        }.provide(standardLayers),
        test("malformed 'from' date string fails with ValidationError") {
          for {
            service <- ZIO.service[RideService]
            result  <- service.getRidesByDrivers(List(testDriverId), Some("not-a-date"), None, testCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(_) => true
                case _                            => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("malformed 'to' date string fails with ValidationError") {
          for {
            service <- ZIO.service[RideService]
            result  <- service.getRidesByDrivers(List(testDriverId), None, Some("bad"), testCompanyId).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case RideError.ValidationError(_) => true
                case _                            => false
              }
            case _                   => false
          })
        }.provide(standardLayers),
        test("date range filter excludes rides outside the window") {
          import java.time.LocalDate
          for {
            service <- ZIO.service[RideService]
            ride    <- service.createRide(mkRide())
            _       <- service.assignDriver(ride.id, testDriverId)
            // A past date range that excludes a future ride (pickupDateTime is in the future by default).
            result  <- service.getRidesByDrivers(
                         List(testDriverId),
                         Some("2000-01-01"),
                         Some("2000-01-02"),
                         testCompanyId
                       )
          } yield assertTrue(result.isEmpty)
        }.provide(standardLayers),
        test("two drivers — rides are returned for both") {
          for {
            service   <- ZIO.service[RideService]
            ride1     <- service.createRide(mkRide())
            assigned1 <- service.assignDriver(ride1.id, testDriverId)
            ride2     <- service.createRide(mkRide())
            assigned2 <- service.assignDriver(ride2.id, testDriver2Id)
            result    <- service.getRidesByDrivers(List(testDriverId, testDriver2Id), None, None, testCompanyId)
          } yield assertTrue(
            result.exists(_.id == assigned1.id),
            result.exists(_.id == assigned2.id)
          )
        }.provide(standardLayers),
        test("empty driverIds list returns empty result") {
          for {
            service <- ZIO.service[RideService]
            result  <- service.getRidesByDrivers(Nil, None, None, testCompanyId)
          } yield assertTrue(result.isEmpty)
        }.provide(standardLayers)
      ),
      // ── getDriverRides tenant isolation ────────────────────────────────────
      suite("getDriverRides tenant isolation")(
        test("foreign driverId from other company returns empty list — no data leak") {
          for {
            service <- ZIO.service[RideService]
            // Create a ride for testCompanyId assigned to testDriver.
            ride    <- service.createRide(mkRide())
            _       <- service.assignDriver(ride.id, testDriverId)
            // Query wrongCompanyDriver's rides but scoped to testCompanyId.
            // The driver is from otherCompanyId; companyId filter must yield empty.
            result  <- service.getDriverRides(wrongCompanyDriver.id, testCompanyId)
          } yield assertTrue(result.isEmpty)
        }.provide(standardLayers),
        test("same driverId with own companyId returns rides") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.getDriverRides(testDriverId, testCompanyId)
          } yield assertTrue(result.exists(_.id == assigned.id))
        }.provide(standardLayers),
        test("driver from testCompany is invisible when queried under otherCompanyId") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide())
            assigned <- service.assignDriver(ride.id, testDriverId)
            result   <- service.getDriverRides(testDriverId, otherCompanyId)
          } yield assertTrue(result.isEmpty)
        }.provide(standardLayers),
        test("two rides for different drivers — each driver sees only their own rides") {
          for {
            service   <- ZIO.service[RideService]
            ride1     <- service.createRide(mkRide())
            assigned1 <- service.assignDriver(ride1.id, testDriverId)
            ride2     <- service.createRide(mkRide())
            assigned2 <- service.assignDriver(ride2.id, testDriver2Id)
            driver1   <- service.getDriverRides(testDriverId, testCompanyId)
            driver2   <- service.getDriverRides(testDriver2Id, testCompanyId)
          } yield assertTrue(
            driver1.exists(_.id == assigned1.id),
            !driver1.exists(_.id == assigned2.id),
            driver2.exists(_.id == assigned2.id),
            !driver2.exists(_.id == assigned1.id)
          )
        }.provide(standardLayers)
      )
    )
}
