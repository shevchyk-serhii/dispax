package com.shevchyk.schedule.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{PersonRepository, InMemoryPersonRepository}
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.repository.{
  InMemoryDriverScheduleVisibilityRepository,
  InMemoryScheduleDayRepository,
  DriverScheduleVisibilityRepository
}
import zio.test.*
import zio.*
import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

/**
 * Unit tests for the new visibility-related methods of ScheduleService:
 *   - getDriverScheduleAs (all access branches)
 *   - canDriverViewOthers
 *   - setDriverVisibility (including company-ownership check)
 *   - getCompanyVisibility
 *   - getMyVisibility (own flag read, absent-record default, tenant isolation)
 *
 * All tests use in-memory repository doubles — no real database.
 */
object ScheduleServiceVisibilitySpec extends ZIOSpecDefault {

  // ── Test identities ─────────────────────────────────────────────────────────

  val companyA  = CompanyId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  val companyB  = CompanyId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000001"))

  val driverAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000010"))
  val driverBId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000020"))
  // A driver who belongs to companyB — used for cross-tenant checks
  val driverCId = PersonId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000010"))

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

  val dispatcherAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000030"))
  val dispatcherA   = Person(
    id = dispatcherAId,
    name = "Dispatcher A",
    email = "dispatcher@example.com",
    role = PersonRole.Dispatcher,
    companyId = Some(companyA)
  )

  val adminAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000040"))
  val adminA   = Person(
    id = adminAId,
    name = "Admin A",
    email = "admin@example.com",
    role = PersonRole.Admin,
    companyId = Some(companyA)
  )

  val secretaryAId = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000050"))
  val secretaryA   = Person(
    id = secretaryAId,
    name = "Secretary A",
    email = "secretary@example.com",
    role = PersonRole.Secretary,
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
      _    <- repo.create(secretaryA).orDie
    } yield repo
  }

  /** Fresh layers for every test — each test gets its own isolated in-memory state. */
  def layers: ZLayer[Any, Nothing, ScheduleService] =
    InMemoryScheduleDayRepository.layer ++
      InMemoryDriverScheduleVisibilityRepository.layer ++
      personRepoLayer >>>
      ScheduleService.layer

  val futureDate = LocalDate.now().plusDays(10)

  private def makeScheduleForDriver(
      service: ScheduleService,
      driverId: PersonId,
      companyId: CompanyId,
      date: LocalDate
  ) = service.createScheduleDay(
    CreateScheduleDayRequest(
      driverId = driverId,
      companyId = companyId,
      date = date,
      startTime = LocalTime.of(8, 0),
      endTime = LocalTime.of(16, 0)
    )
  )

  // ── Test suite ────────────────────────────────────────────────────────────────

  def spec = suite("ScheduleService — visibility feature")(

    // ─── getDriverScheduleAs ──────────────────────────────────────────────────

    suite("getDriverScheduleAs")(

      test("requester == target → always allowed (driver sees own schedule)") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- makeScheduleForDriver(service, driverAId, companyA, futureDate)
          days    <- service.getDriverScheduleAs(
                       requesterId = driverAId,
                       requesterRole = "DRIVER",
                       targetDriverId = driverAId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty && days.forall(_.driverId == driverAId))
      }.provide(layers),

      test("Dispatcher viewing another driver → always allowed") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(1))
          days    <- service.getDriverScheduleAs(
                       requesterId = dispatcherAId,
                       requesterRole = "DISPATCHER",
                       targetDriverId = driverBId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty && days.forall(_.driverId == driverBId))
      }.provide(layers),

      test("Admin viewing another driver → always allowed") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(2))
          days    <- service.getDriverScheduleAs(
                       requesterId = adminAId,
                       requesterRole = "ADMIN",
                       targetDriverId = driverBId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty && days.forall(_.driverId == driverBId))
      }.provide(layers),

      test("Secretary viewing another driver → always allowed") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(3))
          days    <- service.getDriverScheduleAs(
                       requesterId = secretaryAId,
                       requesterRole = "SECRETARY",
                       targetDriverId = driverBId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty && days.forall(_.driverId == driverBId))
      }.provide(layers),

      test("Driver with canViewOtherSchedules=true → allowed to view colleague") {
        for {
          service <- ZIO.service[ScheduleService]
          // Grant Driver A permission to view others
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          // Create a schedule for Driver B
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(4))
          days    <- service.getDriverScheduleAs(
                       requesterId = driverAId,
                       requesterRole = "DRIVER",
                       targetDriverId = driverBId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty && days.forall(_.driverId == driverBId))
      }.provide(layers),

      test("Driver with canViewOtherSchedules=false (explicit row) → AccessDenied") {
        for {
          service <- ZIO.service[ScheduleService]
          // Explicitly set flag to false
          _       <- service.setDriverVisibility(driverAId, companyA, canView = false)
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(5))
          result  <- service
                       .getDriverScheduleAs(
                         requesterId = driverAId,
                         requesterRole = "DRIVER",
                         targetDriverId = driverBId,
                         companyId = companyA
                       )
                       .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists {
              case ScheduleError.AccessDenied(_) => true
              case _                             => false
            }
          case _                   => false
        })
      }.provide(layers),

      test("Driver with no visibility row (absent = false) → AccessDenied") {
        for {
          service <- ZIO.service[ScheduleService]
          // No setDriverVisibility call — row is absent → defaults to false
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(6))
          result  <- service
                       .getDriverScheduleAs(
                         requesterId = driverAId,
                         requesterRole = "DRIVER",
                         targetDriverId = driverBId,
                         companyId = companyA
                       )
                       .exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) =>
            cause.failureOption.exists {
              case ScheduleError.AccessDenied(_) => true
              case _                             => false
            }
          case _                   => false
        })
      }.provide(layers),

      test("Role comparison is case-insensitive — 'driver' (lowercase) with flag=true → allowed") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          _       <- makeScheduleForDriver(service, driverBId, companyA, futureDate.plusDays(7))
          days    <- service.getDriverScheduleAs(
                       requesterId = driverAId,
                       requesterRole = "driver", // lowercase — must still work
                       targetDriverId = driverBId,
                       companyId = companyA
                     )
        } yield assertTrue(days.nonEmpty)
      }.provide(layers)

    ),

    // ─── canDriverViewOthers ──────────────────────────────────────────────────

    suite("canDriverViewOthers")(

      test("returns false when no row exists") {
        for {
          service <- ZIO.service[ScheduleService]
          result  <- service.canDriverViewOthers(driverAId, companyA)
        } yield assertTrue(!result)
      }.provide(layers),

      test("returns false when row exists with flag=false") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = false)
          result  <- service.canDriverViewOthers(driverAId, companyA)
        } yield assertTrue(!result)
      }.provide(layers),

      test("returns true after flag is set to true") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          result  <- service.canDriverViewOthers(driverAId, companyA)
        } yield assertTrue(result)
      }.provide(layers),

      test("returns false when row belongs to a different company (tenant safety)") {
        for {
          service <- ZIO.service[ScheduleService]
          // Store a visibility row under companyB for driverC
          _       <- service.setDriverVisibility(driverCId, companyB, canView = true)
          // Query with companyA context — must see false
          result  <- service.canDriverViewOthers(driverCId, companyA)
        } yield assertTrue(!result)
      }.provide(layers),

      test("toggle: set true, then false, result is false") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          _       <- service.setDriverVisibility(driverAId, companyA, canView = false)
          result  <- service.canDriverViewOthers(driverAId, companyA)
        } yield assertTrue(!result)
      }.provide(layers)

    ),

    // ─── setDriverVisibility ──────────────────────────────────────────────────

    suite("setDriverVisibility")(

      test("persists the visibility record and returns it") {
        for {
          service <- ZIO.service[ScheduleService]
          v       <- service.setDriverVisibility(driverAId, companyA, canView = true)
        } yield assertTrue(
          v.driverId == driverAId &&
            v.companyId == companyA &&
            v.canViewOtherSchedules
        )
      }.provide(layers),

      test("upsert behaviour — second call overrides the first") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          v       <- service.setDriverVisibility(driverAId, companyA, canView = false)
        } yield assertTrue(!v.canViewOtherSchedules)
      }.provide(layers),

      test("fails with DriverNotFound when driver does not exist") {
        val unknownId = PersonId(UUID.fromString("00000000-0000-0000-0000-000000000099"))
        for {
          service <- ZIO.service[ScheduleService]
          result  <- service.setDriverVisibility(unknownId, companyA, canView = true).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.DriverNotFound])
          case _                   => false
        })
      }.provide(layers),

      test("fails with CompanyMismatch when driver belongs to a different company") {
        for {
          service <- ZIO.service[ScheduleService]
          // driverC belongs to companyB; requesting with companyA must fail
          result  <- service.setDriverVisibility(driverCId, companyA, canView = true).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[ScheduleError.CompanyMismatch])
          case _                   => false
        })
      }.provide(layers)

    ),

    // ─── getMyVisibility ──────────────────────────────────────────────────────

    suite("getMyVisibility")(

      test("returns record with canViewOtherSchedules=true when flag was set to true") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          result  <- service.getMyVisibility(driverAId, companyA)
        } yield assertTrue(
          result.driverId == driverAId &&
            result.companyId == companyA &&
            result.canViewOtherSchedules
        )
      }.provide(layers),

      test("returns safe default (canViewOtherSchedules=false) when no record exists") {
        for {
          service <- ZIO.service[ScheduleService]
          // No visibility record is created — row is absent
          result  <- service.getMyVisibility(driverAId, companyA)
        } yield assertTrue(
          result.driverId == driverAId &&
            result.companyId == companyA &&
            !result.canViewOtherSchedules
        )
      }.provide(layers),

      test("tenant isolation: row belonging to another company returns safe default") {
        for {
          service <- ZIO.service[ScheduleService]
          // driverC belongs to companyB; her visibility row is stored under companyB
          _       <- service.setDriverVisibility(driverCId, companyB, canView = true)
          // Request the same driverId but with companyA's context — must not leak cross-tenant data
          result  <- service.getMyVisibility(driverCId, companyA)
        } yield assertTrue(
          result.driverId == driverCId &&
            result.companyId == companyA &&
            !result.canViewOtherSchedules
        )
      }.provide(layers),

      test("returns record with canViewOtherSchedules=false when flag was explicitly set to false") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = false)
          result  <- service.getMyVisibility(driverAId, companyA)
        } yield assertTrue(
          result.driverId == driverAId &&
            result.companyId == companyA &&
            !result.canViewOtherSchedules
        )
      }.provide(layers)

    ),

    // ─── getCompanyVisibility ─────────────────────────────────────────────────

    suite("getCompanyVisibility")(

      test("returns empty list when no visibility records exist") {
        for {
          service <- ZIO.service[ScheduleService]
          list    <- service.getCompanyVisibility(companyA)
        } yield assertTrue(list.isEmpty)
      }.provide(layers),

      test("returns only records belonging to the requested company (tenant isolation)") {
        for {
          service <- ZIO.service[ScheduleService]
          // Create records for both companies
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          _       <- service.setDriverVisibility(driverCId, companyB, canView = true)
          listA   <- service.getCompanyVisibility(companyA)
          listB   <- service.getCompanyVisibility(companyB)
        } yield assertTrue(
          listA.size == 1 &&
            listA.head.driverId == driverAId &&
            listA.head.companyId == companyA &&
            listB.size == 1 &&
            listB.head.driverId == driverCId
        )
      }.provide(layers),

      test("reflects multiple drivers in the same company") {
        for {
          service <- ZIO.service[ScheduleService]
          _       <- service.setDriverVisibility(driverAId, companyA, canView = true)
          _       <- service.setDriverVisibility(driverBId, companyA, canView = false)
          list    <- service.getCompanyVisibility(companyA)
        } yield assertTrue(
          list.size == 2 &&
            list.map(_.driverId).toSet == Set(driverAId, driverBId)
        )
      }.provide(layers)

    )

  )
}
