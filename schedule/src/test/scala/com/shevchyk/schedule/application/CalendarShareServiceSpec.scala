package com.shevchyk.schedule.application

import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.core.application.{BusySlot, DriverBusySlots}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{InMemoryCompanyRepository, InMemoryPersonRepository}
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.SharedCalendarDto
import com.shevchyk.schedule.repository.{
  InMemoryCalendarShareGrantRepository,
  InMemoryCalendarShareInviteRepository,
  InMemoryDriverUnavailabilityRepository,
  InMemoryScheduleDayRepository
}
import zio.*
import zio.json.*
import zio.test.*

import java.time.{Instant, LocalDate, LocalTime}
import java.util.UUID

object CalendarShareServiceSpec extends ZIOSpecDefault {

  private val companyAId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val companyBId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  private val grantorId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  private val granteeId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))
  private val strangerId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000003"))

  private val grantor = Person(
    id = grantorId,
    name = "Anna Grantor",
    email = "anna@company-a.de",
    role = PersonRole.Driver,
    companyId = Some(companyAId)
  )

  private val grantee = Person(
    id = granteeId,
    name = "Boris Grantee",
    email = "boris@company-b.de",
    role = PersonRole.Dispatcher,
    companyId = Some(companyBId)
  )

  private val companyA = Company(companyAId, "Company A", "a@a.de", "+491", "Street A", CompanyStatus.Active)
  private val companyB = Company(companyBId, "Company B", "b@b.de", "+492", "Street B", CompanyStatus.Active)

  private val testNow = Instant.parse("2026-07-01T10:00:00Z")

  /**
   * Configurable stub for the ride-side port: returns the preset slots, no ride module involved.
   */
  final private class StubBusySlots(preset: List[BusySlot]) extends DriverBusySlots:
    def slots(driverId: PersonId, from: Instant, to: Instant): Task[List[BusySlot]] = ZIO.succeed(preset)

  final private case class Fixture(
      service: CalendarShareService,
      inviteRepo: InMemoryCalendarShareInviteRepository,
      grantRepo: InMemoryCalendarShareGrantRepository,
      scheduleRepo: InMemoryScheduleDayRepository,
      unavailRepo: InMemoryDriverUnavailabilityRepository,
      personRepo: InMemoryPersonRepository
  )

  private def makeFixture(
      busySlots: List[BusySlot] = Nil,
      limiterMax: Int = 1000
  ): UIO[Fixture] =
    for {
      inviteStore <- Ref.Synchronized.make(Map.empty[CalendarShareInviteId, CalendarShareInvite])
      grantStore  <- Ref.Synchronized.make(Map.empty[CalendarShareGrantId, CalendarShareGrant])
      inviteRepo   = InMemoryCalendarShareInviteRepository(inviteStore)
      grantRepo    = InMemoryCalendarShareGrantRepository(grantStore)
      personRepo   = new InMemoryPersonRepository
      companyRepo  = new InMemoryCompanyRepository
      scheduleRepo = new InMemoryScheduleDayRepository
      unavailRepo  = new InMemoryDriverUnavailabilityRepository
      _           <- personRepo.create(grantor).orDie
      _           <- personRepo.create(grantee).orDie
      _           <- companyRepo.create(companyA).orDie
      _           <- companyRepo.create(companyB).orDie
      limiter     <- RateLimiter.make(maxRequests = limiterMax, windowSeconds = 60)
      service      = CalendarShareServiceImpl(
                       inviteRepo,
                       grantRepo,
                       personRepo,
                       companyRepo,
                       scheduleRepo,
                       unavailRepo,
                       StubBusySlots(busySlots),
                       limiter
                     )
    } yield Fixture(service, inviteRepo, grantRepo, scheduleRepo, unavailRepo, personRepo)

  private def createAndRedeem(f: Fixture): IO[CalendarShareError, CalendarShareGrantView] =
    for {
      invite <- f.service.createInvite(grantorId, companyAId, None)
      view   <- f.service.redeem(invite.token, granteeId, companyBId)
    } yield view

  def spec =
    suite("CalendarShareServiceSpec")(
      suite("createInvite")(
        test("mints an invite with a plausible token and the default 7-day expiry") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, None)
          } yield assertTrue(
            CalendarShareInvite.isPlausibleToken(invite.token),
            invite.grantorPersonId == grantorId,
            invite.grantorCompanyId == companyAId,
            invite.expiresAt == testNow.plusSeconds(7L * 24 * 3600)
          )
        },
        test("clamps a requested expiry above the maximum down to 30 days") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, Some(365))
          } yield assertTrue(invite.expiresAt == testNow.plusSeconds(30L * 24 * 3600))
        },
        test("fails with TooManyActiveInvites above the cap") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            _      <-
              ZIO.foreachDiscard(1 to CalendarShareServiceImpl.MaxActiveInvites)(_ =>
                f.service.createInvite(grantorId, companyAId, None)
              )
            result <- f.service.createInvite(grantorId, companyAId, None).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.TooManyActiveInvites))
        }
      ),
      suite("redeem")(
        test("creates a cross-company grant bound to the redeeming user, enriched with names") {
          for {
            _    <- TestClock.setTime(testNow)
            f    <- makeFixture()
            view <- createAndRedeem(f)
          } yield assertTrue(
            view.grant.grantorPersonId == grantorId,
            view.grant.grantorCompanyId == companyAId,
            view.grant.granteePersonId == granteeId,
            view.grant.granteeCompanyId == companyBId,
            view.grant.revokedAt.isEmpty,
            view.grantorName == "Anna Grantor",
            view.grantorCompanyName == "Company A",
            view.granteeName == "Boris Grantee",
            view.granteeCompanyName == "Company B"
          )
        },
        test("unknown, garbage and expired tokens all collapse to InviteInvalid") {
          for {
            _       <- TestClock.setTime(testNow)
            f       <- makeFixture()
            unknown <- f.service.redeem(CalendarShareInvite.generateTokenValue(), granteeId, companyBId).exit
            garbage <- f.service.redeem("../../etc/passwd", granteeId, companyBId).exit
            invite  <- f.service.createInvite(grantorId, companyAId, Some(1))
            _       <- TestClock.adjust(25.hours)
            expired <- f.service.redeem(invite.token, granteeId, companyBId).exit
          } yield assertTrue(
            unknown == Exit.fail(CalendarShareError.InviteInvalid),
            garbage == Exit.fail(CalendarShareError.InviteInvalid),
            expired == Exit.fail(CalendarShareError.InviteInvalid)
          )
        },
        test("a revoked invite no longer redeems") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, None)
            _      <- f.service.revokeInvite(invite.id, grantorId)
            result <- f.service.redeem(invite.token, granteeId, companyBId).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.InviteInvalid))
        },
        test("self-redeem is rejected") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, None)
            result <- f.service.redeem(invite.token, grantorId, companyAId).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.SelfShareNotAllowed))
        },
        test("redeeming twice is idempotent — returns the same grant") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, None)
            first  <- f.service.redeem(invite.token, granteeId, companyBId)
            second <- f.service.redeem(invite.token, granteeId, companyBId)
          } yield assertTrue(first.grant.id == second.grant.id)
        },
        test("redeem attempts beyond the rate limit fail with RateLimited") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture(limiterMax = 2)
            _      <- f.service.redeem(CalendarShareInvite.generateTokenValue(), granteeId, companyBId).exit
            _      <- f.service.redeem(CalendarShareInvite.generateTokenValue(), granteeId, companyBId).exit
            result <- f.service.redeem(CalendarShareInvite.generateTokenValue(), granteeId, companyBId).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.RateLimited))
        }
      ),
      suite("revocation")(
        test("the grantor can revoke and the grant disappears from both lists") {
          for {
            _       <- TestClock.setTime(testNow)
            f       <- makeFixture()
            view    <- createAndRedeem(f)
            _       <- f.service.revokeGrant(view.grant.id, grantorId)
            granted <- f.service.listGranted(grantorId)
            shared  <- f.service.listSharedWithMe(granteeId)
          } yield assertTrue(granted.isEmpty, shared.isEmpty)
        },
        test("the grantee can unlink (revoke from their side)") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            view   <- createAndRedeem(f)
            _      <- f.service.revokeGrant(view.grant.id, granteeId)
            shared <- f.service.listSharedWithMe(granteeId)
          } yield assertTrue(shared.isEmpty)
        },
        test("a third party cannot revoke — collapses to GrantNotFound") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            view   <- createAndRedeem(f)
            result <- f.service.revokeGrant(view.grant.id, strangerId).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.GrantNotFound(view.grant.id)))
        },
        test("revoking someone else's invite collapses to InviteNotFound") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            invite <- f.service.createInvite(grantorId, companyAId, None)
            result <- f.service.revokeInvite(invite.id, strangerId).exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.InviteNotFound(invite.id)))
        }
      ),
      suite("getSharedCalendar")(
        test("returns the grantor's shifts and busy slots (rides + unavailability) in range") {
          val rideSlot = BusySlot(Instant.parse("2026-07-02T08:00:00Z"), Instant.parse("2026-07-02T09:00:00Z"))
          for {
            _        <- TestClock.setTime(testNow)
            f        <- makeFixture(busySlots = List(rideSlot))
            view     <- createAndRedeem(f)
            _        <- f.scheduleRepo.create(
                          ScheduleDay(
                            id = ScheduleDayId.generate(),
                            driverId = grantorId,
                            companyId = companyAId,
                            date = LocalDate.parse("2026-07-02"),
                            startTime = LocalTime.of(8, 0),
                            endTime = LocalTime.of(16, 0),
                            status = ScheduleDayStatus.Scheduled,
                            notes = Some("VIP client Mueller, Maximilianstr. 12"),
                            createdAt = testNow,
                            updatedAt = testNow
                          )
                        )
            _        <- f.unavailRepo.create(
                          DriverUnavailability(
                            id = DriverUnavailabilityId.generate(),
                            driverId = grantorId,
                            companyId = companyAId,
                            fromTime = Instant.parse("2026-07-02T12:00:00Z"),
                            toTime = Instant.parse("2026-07-02T13:00:00Z"),
                            reason = DriverUnavailabilityReason.Lunch,
                            note = Some("private note"),
                            createdAt = testNow
                          )
                        )
            calendar <- f.service.getSharedCalendar(
                          view.grant.id,
                          granteeId,
                          LocalDate.parse("2026-07-01"),
                          LocalDate.parse("2026-07-07")
                        )
          } yield assertTrue(
            calendar.grantorName == "Anna Grantor",
            calendar.shifts.map(_.date) == List(LocalDate.parse("2026-07-02")),
            calendar.busy.exists(b => b.kind == SharedBusyKind.Ride && b.start == rideSlot.start),
            calendar.busy.exists(b =>
              b.kind == SharedBusyKind.Unavailability && b.start == Instant.parse("2026-07-02T12:00:00Z")
            )
          )
        },
        test("the DTO strips PII: shift notes and unavailability notes never reach the wire") {
          for {
            _        <- TestClock.setTime(testNow)
            f        <- makeFixture()
            view     <- createAndRedeem(f)
            _        <- f.scheduleRepo.create(
                          ScheduleDay(
                            id = ScheduleDayId.generate(),
                            driverId = grantorId,
                            companyId = companyAId,
                            date = LocalDate.parse("2026-07-02"),
                            startTime = LocalTime.of(8, 0),
                            endTime = LocalTime.of(16, 0),
                            status = ScheduleDayStatus.Scheduled,
                            notes = Some("SECRET-CLIENT-PII"),
                            createdAt = testNow,
                            updatedAt = testNow
                          )
                        )
            calendar <- f.service.getSharedCalendar(
                          view.grant.id,
                          granteeId,
                          LocalDate.parse("2026-07-01"),
                          LocalDate.parse("2026-07-07")
                        )
            json      = SharedCalendarDto.fromDomain(calendar).toJson
          } yield assertTrue(!json.contains("SECRET-CLIENT-PII"), json.contains("2026-07-02"))
        },
        test("only the grantee may read — grantor and third party collapse to GrantNotFound") {
          for {
            _         <- TestClock.setTime(testNow)
            f         <- makeFixture()
            view      <- createAndRedeem(f)
            from       = LocalDate.parse("2026-07-01")
            to         = LocalDate.parse("2026-07-07")
            asGrantor <- f.service.getSharedCalendar(view.grant.id, grantorId, from, to).exit
            asOther   <- f.service.getSharedCalendar(view.grant.id, strangerId, from, to).exit
          } yield assertTrue(
            asGrantor == Exit.fail(CalendarShareError.GrantNotFound(view.grant.id)),
            asOther == Exit.fail(CalendarShareError.GrantNotFound(view.grant.id))
          )
        },
        test("a revoked grant no longer reads") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            view   <- createAndRedeem(f)
            _      <- f.service.revokeGrant(view.grant.id, grantorId)
            result <-
              f.service
                .getSharedCalendar(
                  view.grant.id,
                  granteeId,
                  LocalDate.parse("2026-07-01"),
                  LocalDate.parse("2026-07-07")
                )
                .exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.GrantNotFound(view.grant.id)))
        },
        test("a deactivated grantor's calendar goes dark with the same 404") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            view   <- createAndRedeem(f)
            _      <- f.personRepo.update(grantor.copy(status = UserStatus.SUSPENDED)).orDie
            result <-
              f.service
                .getSharedCalendar(
                  view.grant.id,
                  granteeId,
                  LocalDate.parse("2026-07-01"),
                  LocalDate.parse("2026-07-07")
                )
                .exit
          } yield assertTrue(result == Exit.fail(CalendarShareError.GrantNotFound(view.grant.id)))
        },
        test("an oversized date range is rejected") {
          for {
            _      <- TestClock.setTime(testNow)
            f      <- makeFixture()
            view   <- createAndRedeem(f)
            result <-
              f.service
                .getSharedCalendar(
                  view.grant.id,
                  granteeId,
                  LocalDate.parse("2026-01-01"),
                  LocalDate.parse("2026-12-31")
                )
                .exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.flatMap(_.failureOption).exists {
              case CalendarShareError.ValidationError(_) => true
              case _                                     => false
            }
          )
        }
      )
    )
}
