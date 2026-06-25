package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.RideShareTokenServiceImpl
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{InMemoryRideRepository, InMemoryRideShareTokenRepository}
import zio.*
import zio.test.*
import zio.test.Assertion.*

import java.time.{Duration, Instant}
import java.util.UUID

object RideShareTokenServiceSpec extends ZIOSpecDefault {

  private val companyId      = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000001"))
  private val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-0000000000ff"))
  private val clientId       = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  private val driverId       = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000004"))

  private val buffer = Duration.ofMinutes(90)

  // `now` is threaded explicitly from the SAME clock the service reads (ZIO Test's clock starts at the epoch, not
  // wall-clock), so ride end times line up with what `resolve` compares against.
  private def ride(
      now: Instant,
      status: RideStatus = RideStatus.InProgress,
      endTime: Option[Instant] = None
  ): Ride = Ride(
    id = RideId.generate(),
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = status,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B"),
    pickupDateTime = now.plusSeconds(3600),
    endTime = endTime
  )

  /**
   * A fresh service over in-memory doubles, with the given ride pre-seeded (id preserved via update/upsert).
   */
  private def freshFor(r: Ride): UIO[(RideShareTokenServiceImpl, InMemoryRideShareTokenRepository)] =
    val shareRepo = new InMemoryRideShareTokenRepository
    val rideRepo  = new InMemoryRideRepository
    rideRepo.update(r).orDie.as((new RideShareTokenServiceImpl(shareRepo, rideRepo, buffer), shareRepo))

  def spec =
    suite("RideShareTokenServiceSpec")(
      test("resolve of an unknown token fails with ShareTokenInvalid") {
        for {
          now        <- Clock.instant
          svcAndRepo <- freshFor(ride(now))
          exit       <- svcAndRepo._1.resolve("does-not-exist").exit
        } yield assert(exit)(fails(equalTo(RideError.ShareTokenInvalid)))
      },
      test("resolve succeeds for an active (InProgress) ride") {
        for {
          now        <- Clock.instant
          r           = ride(now, status = RideStatus.InProgress)
          svcAndRepo <- freshFor(r)
          token      <- svcAndRepo._1.generateForRide(r.id, companyId)
          resolved   <- svcAndRepo._1.resolve(token)
        } yield assert(resolved.rideId)(equalTo(r.id)) && assert(resolved.companyId)(equalTo(companyId))
      },
      test("resolve succeeds for a Completed ride within the buffer") {
        for {
          now        <- Clock.instant
          r           = ride(now, status = RideStatus.Completed, endTime = Some(now.minusSeconds(30 * 60)))
          svcAndRepo <- freshFor(r)
          token      <- svcAndRepo._1.generateForRide(r.id, companyId)
          resolved   <- svcAndRepo._1.resolve(token)
        } yield assert(resolved.rideId)(equalTo(r.id))
      },
      test("resolve fails for a Completed ride past the buffer") {
        for {
          now        <- Clock.instant
          r           = ride(now, status = RideStatus.Completed, endTime = Some(now.minusSeconds(3 * 3600)))
          svcAndRepo <- freshFor(r)
          token      <- svcAndRepo._1.generateForRide(r.id, companyId)
          exit       <- svcAndRepo._1.resolve(token).exit
        } yield assert(exit)(fails(equalTo(RideError.ShareTokenInvalid)))
      },
      test("resolve fails for a DB-expired token") {
        for {
          now        <- Clock.instant
          r           = ride(now)
          svcAndRepo <- freshFor(r)
          svc         = svcAndRepo._1
          shareRepo   = svcAndRepo._2
          expired     = RideShareToken(
                          id = RideShareTokenId.generate(),
                          token = "expired-token",
                          rideId = r.id,
                          companyId = companyId,
                          createdAt = now.minusSeconds(7200),
                          expiresAt = now.minusSeconds(60)
                        )
          _          <- shareRepo.create(expired).orDie
          exit       <- svc.resolve("expired-token").exit
        } yield assert(exit)(fails(equalTo(RideError.ShareTokenInvalid)))
      },
      test("generateForRide twice on a live ride returns the SAME token (reuse)") {
        for {
          now        <- Clock.instant
          r           = ride(now)
          svcAndRepo <- freshFor(r)
          t1         <- svcAndRepo._1.generateForRide(r.id, companyId)
          t2         <- svcAndRepo._1.generateForRide(r.id, companyId)
        } yield assert(t1)(equalTo(t2))
      },
      test("generateForRide with a mismatched companyId fails (tenant gate)") {
        for {
          now        <- Clock.instant
          r           = ride(now)
          svcAndRepo <- freshFor(r)
          exit       <- svcAndRepo._1.generateForRide(r.id, otherCompanyId).exit
        } yield assert(exit)(fails(isSubtype[RideError.UnauthorizedAccess](anything)))
      },
      test("isWithinTrackingWindow: active statuses are always trackable") {
        val now = Instant.now()
        check(
          Gen.fromIterable(
            List(RideStatus.Requested, RideStatus.Assigned, RideStatus.Confirmed, RideStatus.InProgress)
          )
        ) { status =>
          assertTrue(RideShareToken.isWithinTrackingWindow(ride(now, status = status), now, buffer))
        }
      },
      test("isWithinTrackingWindow: terminal at exactly the buffer boundary") {
        val now    = Instant.now()
        val atEdge = ride(now, status = RideStatus.Completed, endTime = Some(now.minus(buffer)))
        val past   = ride(now, status = RideStatus.Completed, endTime = Some(now.minus(buffer).minusSeconds(1)))
        assertTrue(
          RideShareToken.isWithinTrackingWindow(atEdge, now, buffer), // exactly at edge: still in
          !RideShareToken.isWithinTrackingWindow(past, now, buffer)   // one second past: out
        )
      },
      test("generateTokenValue is URL-safe, long, and unique across calls") {
        val tokens  = (1 to 200).map(_ => RideShareToken.generateTokenValue())
        val urlSafe = "^[A-Za-z0-9_-]+$".r
        assertTrue(
          tokens.forall(t => t.length >= 40),
          tokens.forall(t => urlSafe.matches(t)),
          tokens.toSet.size == tokens.size
        )
      }
      // Use the live clock: the service reads `Clock.instant` while the in-memory token repo filters on
      // `Instant.now()`; under ZIO Test's epoch clock the two disagree and the reuse/expiry checks misfire.
    ) @@ TestAspect.withLiveClock
}
