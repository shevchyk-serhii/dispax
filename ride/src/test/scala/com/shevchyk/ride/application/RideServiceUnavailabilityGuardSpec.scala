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
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

/**
 * Unit tests for the new DriverAvailabilityChecker integration in RideService.assignDriver.
 *
 * Uses a configurable stub DriverAvailabilityChecker backed by a Ref so each test can inject a
 * fixed overlap list without touching the schedule module.
 *
 * Every blocking branch has a corresponding "succeeds if guard is absent" companion test so that the
 * tests are mutation-aware — they would fail if the guard were removed.
 */
object RideServiceUnavailabilityGuardSpec extends ZIOSpecDefault {

  // ── Test identities ──────────────────────────────────────────────────────────

  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testDriver2Id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000004"))
  val testClientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))
  val vipClientId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000200"))

  // ── Test persons ─────────────────────────────────────────────────────────────

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

  val wrongCompanyDriver = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002")),
    name = "Other Driver",
    email = "other@example.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
  )

  // ── TestPersonRepository ─────────────────────────────────────────────────────

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
      clientPerson.id       -> clientPerson,
      vipClient.id          -> vipClient,
      wrongCompanyDriver.id -> wrongCompanyDriver
    )
  )

  private val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendInvoiceEmail(data: com.shevchyk.core.application.InvoiceEmailData): Task[Unit] = ZIO.unit
  )

  /** A noop checker that always reports no overlap. */
  private val noopAvailabilityChecker: ZLayer[Any, Nothing, DriverAvailabilityChecker] = ZLayer.succeed(
    new DriverAvailabilityChecker:
      def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
  )

  /**
   * Builds a ZLayer[Any, Nothing, DriverAvailabilityChecker] that always returns the supplied slots.
   * This lets each test inject an exact conflict scenario without involving the schedule module.
   */
  private def stubbedChecker(slots: List[UnavailabilitySlot]): ZLayer[Any, Nothing, DriverAvailabilityChecker] =
    ZLayer.succeed(new DriverAvailabilityChecker:
      def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: Instant,
          to: Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(slots)
    )

  private def buildLayers(
      availabilityChecker: ZLayer[Any, Nothing, DriverAvailabilityChecker] = noopAvailabilityChecker
  ) =
    (InMemoryRideRepository.layer ++
      ZLayer.succeed[PersonRepository](testPersonRepo) ++
      EventHub.layer ++
      noopEmailSms ++
      AuditService.inMemory ++
      BlacklistRepository.inMemory ++
      GeocodingService.noop ++
      ExpenseRepository.inMemory ++
      availabilityChecker) >+> RideService.layer

  val standardLayers = buildLayers()

  private def mkRide(
      clientId: PersonId = testClientId,
      companyId: CompanyId = testCompanyId,
      scheduledTime: Option[Instant] = None
  ) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("Pickup"),
    dropoffLocation = Location("Dropoff"),
    scheduledTime = scheduledTime
  )

  // ── Sample slot ──────────────────────────────────────────────────────────────

  private val lunchSlot = UnavailabilitySlot(
    from = Instant.now().plusSeconds(3600),
    to = Instant.now().plusSeconds(7200),
    reason = "Lunch"
  )

  // ── Spec ─────────────────────────────────────────────────────────────────────

  def spec =
    suite("RideService — unavailability guard")(
      // ─── Unavailability overlap blocks primary assign ─────────────────────────

      suite("assignDriver — unavailability check")(
        // Negative: the stub returns an overlapping slot → assignDriver must fail with ScheduleConflict.
        test("assign BLOCKED when unavailability overlaps (no override)") {
          val pickupAt = Instant.now().plusSeconds(7200)
          buildLayers(stubbedChecker(List(lunchSlot))).build.flatMap { env =>
            (for {
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide(scheduledTime = Some(pickupAt)))
              result  <- service.assignDriver(ride.id, testDriverId).exit
            } yield assertTrue(result match {
              case Exit.Failure(cause) =>
                cause.failureOption.exists {
                  case RideError.ScheduleConflict(_) => true
                  case _                             => false
                }
              case _                   => false
            })).provideEnvironment(env)
          }
        },
        // Positive companion: same scenario WITH override must SUCCEED.
        test("assign SUCCEEDS with overrideScheduleConflict=true even when unavailability overlaps") {
          val pickupAt = Instant.now().plusSeconds(7200)
          buildLayers(stubbedChecker(List(lunchSlot))).build.flatMap { env =>
            (for {
              service  <- ZIO.service[RideService]
              ride     <- service.createRide(mkRide(scheduledTime = Some(pickupAt)))
              assigned <- service.assignDriver(ride.id, testDriverId, overrideScheduleConflict = true)
            } yield assertTrue(
              assigned.status == RideStatus.Assigned &&
                assigned.driverId.contains(testDriverId)
            )).provideEnvironment(env)
          }
        },
        // Positive: no overlap → assign succeeds without any override flag.
        test("assign SUCCEEDS when no unavailability overlap (noop checker)") {
          for {
            service  <- ZIO.service[RideService]
            ride     <- service.createRide(mkRide(scheduledTime = Some(Instant.now().plusSeconds(7200))))
            assigned <- service.assignDriver(ride.id, testDriverId)
          } yield assertTrue(
            assigned.status == RideStatus.Assigned &&
              assigned.driverId.contains(testDriverId)
          )
        }.provide(standardLayers),
        // The override must NOT bypass company-isolation or the Requested guard.
        test("override does NOT bypass company isolation") {
          buildLayers(stubbedChecker(List(lunchSlot))).build.flatMap { env =>
            (for {
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide())
              result  <-
                service
                  .assignDriver(ride.id, wrongCompanyDriver.id, overrideScheduleConflict = true)
                  .exit
            } yield assertTrue(result match {
              case Exit.Failure(cause) =>
                cause.failureOption.exists {
                  case RideError.BusinessRuleViolation("company_isolation", _) => true
                  case _                                                       => false
                }
              case _                   => false
            })).provideEnvironment(env)
          }
        },
        // The Requested-status CAS guard must remain intact even with override=true.
        test("override does NOT bypass Requested-status guard") {
          buildLayers(stubbedChecker(List(lunchSlot))).build.flatMap { env =>
            (for {
              service  <- ZIO.service[RideService]
              ride     <- service.createRide(mkRide())
              // First assign (succeeds)
              _        <- service.assignDriver(ride.id, testDriverId, overrideScheduleConflict = true)
              // Second assign on the now-Assigned ride (must fail)
              result   <- service.assignDriver(ride.id, testDriver2Id, overrideScheduleConflict = true).exit
            } yield assertTrue(result match {
              case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
              case _                   => false
            })).provideEnvironment(env)
          }
        },
        // Multiple overlapping slots — conflict is reported on the first slot.
        test("multiple overlapping slots → ScheduleConflict (first slot wins)") {
          val slots = List(
            UnavailabilitySlot(Instant.now().plusSeconds(3600), Instant.now().plusSeconds(7200), "Lunch"),
            UnavailabilitySlot(Instant.now().plusSeconds(7200), Instant.now().plusSeconds(10800), "Personal")
          )
          buildLayers(stubbedChecker(slots)).build.flatMap { env =>
            (for {
              service <- ZIO.service[RideService]
              ride    <- service.createRide(mkRide(scheduledTime = Some(Instant.now().plusSeconds(7200))))
              result  <- service.assignDriver(ride.id, testDriverId).exit
            } yield assertTrue(result match {
              case Exit.Failure(cause) =>
                cause.failureOption.exists {
                  case RideError.ScheduleConflict(msg) => msg.contains("Lunch")
                  case _                               => false
                }
              case _                   => false
            })).provideEnvironment(env)
          }
        }
      ),

      // ─── Ride-vs-ride conflict still intact ──────────────────────────────────

      suite("existing ride-vs-ride conflict still blocks")(
        test("ride-vs-ride overlap still yields ScheduleConflict when noop checker is used") {
          // The noop checker returns no unavailability. The ride-vs-ride path must still block.
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(mkRide(scheduledTime = Some(pickupAt)))
            _       <- service.assignDriver(ride1.id, testDriverId)
            ride2   <- service.createRide(mkRide(scheduledTime = Some(pickupAt.plusSeconds(600)))) // 10 min gap — inside 90-min window
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
        test("reassign also checks ride-vs-ride conflict (overlap path)") {
          val pickupAt = Instant.now().plusSeconds(7200)
          for {
            service <- ZIO.service[RideService]
            ride1   <- service.createRide(mkRide(scheduledTime = Some(pickupAt)))
            _       <- service.assignDriver(ride1.id, testDriver2Id)
            ride2   <- service.createRide(mkRide(scheduledTime = Some(pickupAt.plusSeconds(300))))
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
        }.provide(standardLayers)
      ),

      // ─── Tenant isolation invariant ───────────────────────────────────────────

      suite("tenant isolation in conflict check")(
        // Verify that the availability checker is called with the candidateRide.companyId,
        // not with a caller-supplied one. We do this by stub-checking that assignments on
        // rides from testCompanyA with no overlap succeed even when the checker always reports
        // no overlaps for that company.
        test("checker is called with the ride's companyId (not caller-supplied)") {
          // The checker below will fail the effect if called with otherCompanyId — that would
          // indicate a tenant isolation bug.
          val guardedChecker: ZLayer[Any, Nothing, DriverAvailabilityChecker] = ZLayer.succeed(
            new DriverAvailabilityChecker:
              def overlappingUnavailability(
                  driverId: PersonId,
                  companyId: CompanyId,
                  from: Instant,
                  to: Instant
              ): Task[List[UnavailabilitySlot]] =
                if companyId == otherCompanyId then
                  ZIO.fail(new RuntimeException("checker was called with a foreign companyId — tenant isolation breach"))
                else ZIO.succeed(Nil)
          )
          buildLayers(guardedChecker).build.flatMap { env =>
            (for {
              service  <- ZIO.service[RideService]
              ride     <- service.createRide(mkRide(companyId = testCompanyId))
              assigned <- service.assignDriver(ride.id, testDriverId)
            } yield assertTrue(assigned.status == RideStatus.Assigned)).provideEnvironment(env)
          }
        }
      )
    )
}
