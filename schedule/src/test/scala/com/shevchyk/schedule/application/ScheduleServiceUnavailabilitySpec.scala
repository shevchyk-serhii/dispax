package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{InMemoryPersonRepository, PersonRepository}
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.repository.{
  InMemoryDriverScheduleVisibilityRepository,
  InMemoryDriverUnavailabilityRepository,
  InMemoryScheduleDayRepository
}
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

/**
 * Unit tests for ScheduleService unavailability methods (new in driver-busy-time-assign-guard).
 *
 * Covers all business branches with negative tests (AccessDenied, ValidationError, tenant isolation). All tests use
 * in-memory doubles — no real database.
 */
object ScheduleServiceUnavailabilitySpec extends ZIOSpecDefault {

  // ── Test identities ─────────────────────────────────────────────────────────

  val companyA = CompanyId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  val companyB = CompanyId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000001"))

  val driverAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000010"))
  val driverBId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000020"))
  // Driver belonging to companyB — used for cross-tenant checks
  val driverCId = PersonId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000030"))

  val dispatcherAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000040"))
  val adminAId      = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000050"))

  val driverA = Person(
    id = driverAId,
    name = "Driver A",
    email = "driverA@example.com",
    role = PersonRole.Driver,
    companyId = Some(companyA)
  )

  val driverB = Person(
    id = driverBId,
    name = "Driver B",
    email = "driverB@example.com",
    role = PersonRole.Driver,
    companyId = Some(companyA)
  )

  val driverC = Person(
    id = driverCId,
    name = "Driver C",
    email = "driverC@example.com",
    role = PersonRole.Driver,
    companyId = Some(companyB)
  )

  val dispatcherA = Person(
    id = dispatcherAId,
    name = "Dispatcher A",
    email = "dispatcherA@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(companyA)
  )

  val adminA = Person(
    id = adminAId,
    name = "Admin A",
    email = "adminA@example.com",
    role = PersonRole.Admin,
    companyId = Some(companyA)
  )

  // ── Layers ───────────────────────────────────────────────────────────────────

  val personRepoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer {
    for {
      repo <- ZIO.succeed(new InMemoryPersonRepository)
      _    <- repo.create(driverA).orDie
      _    <- repo.create(driverB).orDie
      _    <- repo.create(driverC).orDie
      _    <- repo.create(dispatcherA).orDie
      _    <- repo.create(adminA).orDie
    } yield repo
  }

  /**
   * Fresh in-memory layers for every test.
   */
  def layers: ZLayer[Any, Nothing, ScheduleService] =
    InMemoryScheduleDayRepository.layer ++
      InMemoryDriverScheduleVisibilityRepository.layer ++
      InMemoryDriverUnavailabilityRepository.layer ++
      personRepoLayer >>>
      ScheduleService.layer

  // Anchor: 1 hour from now.
  val baseTime: Instant      = Instant.now().plusSeconds(3600)
  val oneHourLater: Instant  = baseTime.plusSeconds(3600)
  val twoHoursLater: Instant = baseTime.plusSeconds(7200)

  private def makeReq(
      driverId: PersonId = driverAId,
      companyId: CompanyId = companyA,
      from: Instant = baseTime,
      to: Instant = oneHourLater,
      reason: DriverUnavailabilityReason = DriverUnavailabilityReason.Lunch,
      note: Option[String] = None
  ) = CreateDriverUnavailabilityRequest(
    driverId = driverId,
    companyId = companyId,
    fromTime = from,
    toTime = to,
    reason = reason,
    note = note
  )

  // ── Test suites ──────────────────────────────────────────────────────────────

  def spec =
    suite("ScheduleService — unavailability")(
      // ─── createUnavailability ────────────────────────────────────────────────

      suite("createUnavailability")(
        test("driver creates own unavailability — happy path") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
          } yield assertTrue(
            result.driverId == driverAId &&
              result.companyId == companyA &&
              result.reason == DriverUnavailabilityReason.Lunch &&
              result.fromTime == baseTime &&
              result.toTime == oneHourLater
          )
        }.provide(layers),
        // Negative: a driver trying to create unavailability for ANOTHER driver must be denied.
        test("DRIVER creating unavailability for a different driver → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            // requesterId is driverBId but the request targets driverAId
            result  <-
              service
                .createUnavailability(
                  makeReq(driverId = driverAId),
                  requesterId = driverBId, // different person
                  requesterRole = "DRIVER"
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.AccessDenied])
            case _                   => false
          })
        }.provide(layers),
        // Negative: a DISPATCHER must not be able to create unavailability on behalf of a driver.
        test("DISPATCHER creating unavailability for driver → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createUnavailability(
                  makeReq(driverId = driverAId),
                  requesterId = dispatcherAId,
                  requesterRole = "DISPATCHER"
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.AccessDenied])
            case _                   => false
          })
        }.provide(layers),
        // Negative: a driver with correct ID but wrong role string must also be denied.
        test("ADMIN role (not DRIVER) even when requesterId == driverId → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createUnavailability(
                  makeReq(driverId = driverAId),
                  requesterId = driverAId, // same person
                  requesterRole = "ADMIN"  // but role is admin, not driver
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.AccessDenied])
            case _                   => false
          })
        }.provide(layers),
        // Negative: fromTime == toTime violates the invariant from < to.
        test("fromTime == toTime → ValidationError") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createUnavailability(
                  makeReq(from = baseTime, to = baseTime), // equal instants
                  requesterId = driverAId,
                  requesterRole = "DRIVER"
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(layers),
        // Negative: fromTime > toTime.
        test("fromTime after toTime → ValidationError") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .createUnavailability(
                  makeReq(from = oneHourLater, to = baseTime), // inverted
                  requesterId = driverAId,
                  requesterRole = "DRIVER"
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                case ScheduleError.ValidationError(msg) => msg.contains("before")
                case _                                  => false
              }
            case _                   => false
          })
        }.provide(layers),
        // Role comparison must be case-insensitive.
        test("role string 'driver' (lowercase) is accepted as DRIVER") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "driver")
          } yield assertTrue(result.driverId == driverAId)
        }.provide(layers),
        test("optional note is persisted when provided") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <- service.createUnavailability(
                         makeReq(note = Some("Doctor appointment")),
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
          } yield assertTrue(result.note.contains("Doctor appointment"))
        }.provide(layers)
      ),

      // ─── getDriverUnavailability (access control) ────────────────────────────

      suite("getDriverUnavailability")(
        test("driver reading own unavailability — always allowed") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <- service.getDriverUnavailability(
                         driverId = driverAId,
                         companyId = companyA,
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
          } yield assertTrue(result.nonEmpty && result.forall(_.driverId == driverAId))
        }.provide(layers),
        test("DISPATCHER reading another driver's unavailability — always allowed") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <- service.getDriverUnavailability(
                         driverId = driverAId,
                         companyId = companyA,
                         requesterId = dispatcherAId,
                         requesterRole = "DISPATCHER"
                       )
          } yield assertTrue(result.nonEmpty)
        }.provide(layers),
        test("ADMIN reading another driver's unavailability — always allowed") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <- service.getDriverUnavailability(
                         driverId = driverAId,
                         companyId = companyA,
                         requesterId = adminAId,
                         requesterRole = "ADMIN"
                       )
          } yield assertTrue(result.nonEmpty)
        }.provide(layers),
        // Negative: a driver without the canViewOtherSchedules flag cannot see other driver's unavailability.
        test("DRIVER without canViewOthers reading another driver's unavailability → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <-
              service
                .getDriverUnavailability(
                  driverId = driverAId,
                  companyId = companyA,
                  requesterId = driverBId, // different driver, no visibility granted
                  requesterRole = "DRIVER"
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.AccessDenied])
            case _                   => false
          })
        }.provide(layers),
        test("DRIVER with canViewOtherSchedules=true can read another driver's unavailability") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.setDriverVisibility(driverBId, companyA, canView = true)
            _       <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <- service.getDriverUnavailability(
                         driverId = driverAId,
                         companyId = companyA,
                         requesterId = driverBId,
                         requesterRole = "DRIVER"
                       )
          } yield assertTrue(result.nonEmpty)
        }.provide(layers)
      ),

      // ─── getCompanyUnavailability (tenant isolation) ─────────────────────────

      suite("getCompanyUnavailability")(
        test("returns records in the given time range") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(
                         makeReq(from = baseTime, to = oneHourLater),
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
            result  <- service.getCompanyUnavailability(
                         companyId = companyA,
                         from = baseTime.minusSeconds(1),
                         to = twoHoursLater
                       )
          } yield assertTrue(result.nonEmpty && result.forall(_.companyId == companyA))
        }.provide(layers),
        // Negative tenant isolation: querying with companyB must not return companyA records.
        test("tenant isolation: companyB query never returns companyA records") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(
                         makeReq(companyId = companyA),
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
            result  <- service.getCompanyUnavailability(
                         companyId = companyB,
                         from = baseTime.minusSeconds(1),
                         to = twoHoursLater
                       )
          } yield assertTrue(result.isEmpty)
        }.provide(layers),
        test("returns empty list when no records exist in range") {
          for {
            service <- ZIO.service[ScheduleService]
            result  <- service.getCompanyUnavailability(
                         companyId = companyA,
                         from = twoHoursLater.plusSeconds(3600),
                         to = twoHoursLater.plusSeconds(7200)
                       )
          } yield assertTrue(result.isEmpty)
        }.provide(layers)
      ),

      // ─── deleteUnavailability (owner-only + tenant-scoped) ──────────────────

      suite("deleteUnavailability")(
        test("owning driver can delete own unavailability") {
          for {
            service   <- ZIO.service[ScheduleService]
            created   <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            _         <- service.deleteUnavailability(
                           id = created.id,
                           requesterId = driverAId,
                           requesterRole = "DRIVER",
                           companyId = companyA
                         )
            remaining <- service.getDriverUnavailability(
                           driverId = driverAId,
                           companyId = companyA,
                           requesterId = driverAId,
                           requesterRole = "DRIVER"
                         )
          } yield assertTrue(remaining.isEmpty)
        }.provide(layers),
        test("DISPATCHER can delete any driver's unavailability") {
          for {
            service   <- ZIO.service[ScheduleService]
            created   <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            _         <- service.deleteUnavailability(
                           id = created.id,
                           requesterId = dispatcherAId,
                           requesterRole = "DISPATCHER",
                           companyId = companyA
                         )
            remaining <- service.getDriverUnavailability(
                           driverId = driverAId,
                           companyId = companyA,
                           requesterId = driverAId,
                           requesterRole = "DRIVER"
                         )
          } yield assertTrue(remaining.isEmpty)
        }.provide(layers),
        test("ADMIN can delete any driver's unavailability") {
          for {
            service   <- ZIO.service[ScheduleService]
            created   <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            _         <- service.deleteUnavailability(
                           id = created.id,
                           requesterId = adminAId,
                           requesterRole = "ADMIN",
                           companyId = companyA
                         )
            remaining <- service.getDriverUnavailability(
                           driverId = driverAId,
                           companyId = companyA,
                           requesterId = driverAId,
                           requesterRole = "DRIVER"
                         )
          } yield assertTrue(remaining.isEmpty)
        }.provide(layers),
        // Negative: a different driver (non-owner, non-dispatcher) must be denied.
        test("non-owning DRIVER cannot delete another driver's unavailability → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            created <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <-
              service
                .deleteUnavailability(
                  id = created.id,
                  requesterId = driverBId, // not the owner
                  requesterRole = "DRIVER",
                  companyId = companyA
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.AccessDenied])
            case _                   => false
          })
        }.provide(layers),
        // Negative: deleting with a wrong companyId must be denied even if the owner is correct.
        test("deleting with wrong companyId (cross-tenant attempt) → AccessDenied") {
          for {
            service <- ZIO.service[ScheduleService]
            created <- service.createUnavailability(makeReq(), requesterId = driverAId, requesterRole = "DRIVER")
            result  <-
              service
                .deleteUnavailability(
                  id = created.id,
                  requesterId = driverAId, // correct owner
                  requesterRole = "DRIVER",
                  companyId = companyB     // wrong company
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) =>
              cause.failureOption.exists {
                // Either UnavailabilityNotFound (record not visible cross-tenant) or AccessDenied.
                case ScheduleError.UnavailabilityNotFound(_) => true
                case ScheduleError.AccessDenied(_)           => true
                case _                                       => false
              }
            case _                   => false
          })
        }.provide(layers),
        test("deleting non-existent id → UnavailabilityNotFound") {
          val unknownId = DriverUnavailabilityId(UUID.randomUUID())
          for {
            service <- ZIO.service[ScheduleService]
            result  <-
              service
                .deleteUnavailability(
                  id = unknownId,
                  requesterId = driverAId,
                  requesterRole = "DRIVER",
                  companyId = companyA
                )
                .exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.UnavailabilityNotFound])
            case _                   => false
          })
        }.provide(layers)
      ),

      // ─── tenant isolation (explicit negative: two companies, separate state) ──

      suite("tenant isolation")(
        test("companyA records are not visible when querying with companyB range") {
          for {
            service <- ZIO.service[ScheduleService]
            // Create a record in companyA via driver A
            _       <- service.createUnavailability(
                         makeReq(driverId = driverAId, companyId = companyA),
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
            // Query with companyB context — must see nothing
            resultB <- service.getCompanyUnavailability(companyId = companyB, from = baseTime, to = twoHoursLater)
            // Query with companyA context — must see the record
            resultA <- service.getCompanyUnavailability(companyId = companyA, from = baseTime, to = twoHoursLater)
          } yield assertTrue(resultB.isEmpty && resultA.nonEmpty)
        }.provide(layers),
        test("getDriverUnavailability filters by both driverId and companyId") {
          for {
            service <- ZIO.service[ScheduleService]
            _       <- service.createUnavailability(
                         makeReq(driverId = driverAId, companyId = companyA),
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
            // Query the right driver but wrong company — must return empty.
            result  <- service.getDriverUnavailability(
                         driverId = driverAId,
                         companyId = companyB, // wrong company
                         requesterId = driverAId,
                         requesterRole = "DRIVER"
                       )
          } yield assertTrue(result.isEmpty)
        }.provide(layers)
      )
    )
}
