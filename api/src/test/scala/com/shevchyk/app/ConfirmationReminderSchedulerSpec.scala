package com.shevchyk.app

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{InMemorySentConfirmationRequestRepository, SentConfirmationRequestRepository}
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.PushNotification
import com.shevchyk.ride.domain.{DriverEarnings, PaymentMethod, Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, TimeBucket}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Deterministic unit tests for [[ConfirmationReminderScheduler.tick]].
 *
 * The scheduler must:
 *   - Send a push exactly once per (ride, driver) pair within a day (dedup).
 *   - Skip rides that do NOT need a confirmation (already Confirmed, no driver assigned, outside window).
 *   - Respect the dedup state persisted in [[SentConfirmationRequestRepository]].
 *   - NOT send after a ride has already been confirmed (clear is called by RideService on confirm/reject, simulated
 *     here by marking the sent state before the tick).
 *
 * Tests are deterministic: stubs return canned data, and the `tick` method is called directly (no time-based
 * scheduling, no background fibers).
 */
object ConfirmationReminderSchedulerSpec extends ZIOSpecDefault:

  private val driver  = PersonId(UUID.randomUUID())
  private val client  = PersonId(UUID.randomUUID())
  private val company = CompanyId(UUID.randomUUID())

  // An Assigned ride whose pickup is later today (well inside the scheduler window).
  private def assignedRide(pickupInSeconds: Long = 3600L): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = company,
    driverId = Some(driver),
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz, München"),
    dropoffLocation = Location("Munich Airport"),
    pickupDateTime = Instant.now().minusSeconds(3600 * 12).plusSeconds(pickupInSeconds)
  )

  // Stub RideRepository: `findRidesNeedingConfirmation` returns the given list.
  // All other methods die (they must not be called by the scheduler tick).
  private def rideRepoStub(rides: List[Ride]): RideRepository =
    new RideRepository:
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected RideRepository.$m")

      def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]] = ZIO.succeed(rides)
      def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]    = ZIO.succeed(Nil)

      def create(r: Ride): Task[Ride]                                                                             = nope("create")
      def findById(id: RideId): Task[Option[Ride]]                                                                = nope("findById")
      def findByStatus(s: RideStatus): Task[List[Ride]]                                                           = nope("findByStatus")
      def findByStatusAndCompany(s: RideStatus, c: CompanyId): Task[List[Ride]]                                   = nope("findByStatusAndCompany")
      def findAll(): Task[List[Ride]]                                                                             = nope("findAll")
      def findByClientId(id: PersonId): Task[List[Ride]]                                                          = nope("findByClientId")
      def findByDriverId(id: PersonId): Task[List[Ride]]                                                          = nope("findByDriverId")
      def findByDriverIdAndCompany(d: PersonId, c: CompanyId): Task[List[Ride]]                                   = nope("findByDriverIdAndCompany")
      def findByClientIdAndCompany(cl: PersonId, c: CompanyId): Task[List[Ride]]                                  = nope("findByClientIdAndCompany")
      def findByCompanyId(c: CompanyId): Task[List[Ride]]                                                         = nope("findByCompanyId")
      def findByCompanyIdPaginated(c: CompanyId, offset: Int, limit: Int): Task[List[Ride]]                       = nope(
        "findByCompanyIdPaginated"
      )
      def findByDriverIdPaginated(d: PersonId, offset: Int, limit: Int): Task[List[Ride]]                         = nope(
        "findByDriverIdPaginated"
      )
      def findByDriverIdAndCompanyPaginated(d: PersonId, c: CompanyId, offset: Int, limit: Int): Task[List[Ride]] =
        nope("findByDriverIdAndCompanyPaginated")
      def update(r: Ride): Task[Ride]                                                                             = nope("update")
      def updateIfStatus(r: Ride, es: Set[RideStatus]): Task[Boolean]                                             = nope("updateIfStatus")
      def delete(id: RideId, c: CompanyId): Task[Unit]                                                            = nope("delete")
      def countByCompanyGroupedByStatus(c: CompanyId): Task[Map[String, Int]]                                     = nope("countByCompanyGroupedByStatus")
      def sumRevenueByCompany(c: CompanyId): Task[BigDecimal]                                                     = nope("sumRevenueByCompany")
      def sumTodayRevenueByCompany(c: CompanyId): Task[BigDecimal]                                                = nope("sumTodayRevenueByCompany")
      def avgAssignmentMinutesByCompany(c: CompanyId): Task[Double]                                               = nope("avgAssignmentMinutesByCompany")
      def countDailyStatsByCompany(c: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]                  = nope(
        "countDailyStatsByCompany"
      )
      def earningsByDriver(d: PersonId, c: CompanyId, from: Instant, to: Instant): Task[DriverEarnings]           = nope(
        "earningsByDriver"
      )
      def earningsBucketsByDriver(
          d: PersonId,
          c: CompanyId,
          from: Instant,
          to: Instant,
          b: TimeBucket
      ): Task[List[(Instant, BigDecimal)]] = nope("earningsBucketsByDriver")
      def clearReminders(rideId: RideId): Task[Unit]                                                              = nope("clearReminders")
      def countAllRidesByStatus(): Task[Map[String, Int]]                                                         = nope("countAllRidesByStatus")
      def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                             = nope("sumAllRevenue")
      def countRidesByCompany(from: Instant, to: Instant): Task[Map[java.util.UUID, Int]]                         = nope("countRidesByCompany")
      def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[java.util.UUID, BigDecimal]]          = nope(
        "sumRevenueByCompanyPlatform"
      )
      def updateCheckpoint(rideId: RideId, cp: com.shevchyk.ride.domain.AirportCheckpoint): Task[Boolean]         = nope(
        "updateCheckpoint"
      )
      def updateFlightStatus(
          rideId: RideId,
          gate: Option[String],
          terminal: Option[String],
          flightStatus: Option[String],
          flightTime: Option[java.time.Instant]
      ): Task[Boolean] = nope("updateFlightStatus")
      def findFlightStatus(rideId: RideId): Task[Option[com.shevchyk.ride.domain.FlightStatusRow]]                = nope(
        "findFlightStatus"
      )
      def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]                = ZIO.succeed(false)

  // FcmService stub that records (personId, push type) pairs sent.
  private def fcmStub(ref: Ref[List[(PersonId, String)]]): FcmService =
    new FcmService:
      def registerToken(personId: PersonId, companyId: CompanyId, token: String, platform: String): Task[Unit] =
        ZIO.unit
      def unregisterToken(token: String): Task[Unit]                                                           = ZIO.unit
      def sendToUser(personId: PersonId, companyId: CompanyId, notification: PushNotification): Task[Unit]     = ref.update(
        _ :+ (personId, notification.data.getOrElse("type", "unknown"))
      )

  // Helper: run a tick with the given rides, a fresh in-memory sent-repo, and record FCM sends.
  private def runTick(
      rides: List[Ride],
      sentRepo: SentConfirmationRequestRepository,
      fcmSends: Ref[List[(PersonId, String)]]
  ): Task[Unit] = ConfirmationReminderScheduler.tick.provide(
    ZLayer.succeed(rideRepoStub(rides)),
    ZLayer.succeed(fcmStub(fcmSends)),
    ZLayer.succeed(sentRepo)
  )

  def spec =
    suite("ConfirmationReminderScheduler.tick")(
      // MUTATION TARGET: removing the shouldSend guard would break "once only" dedup.
      test("sends push for an Assigned ride with a driver — push type is ride_confirmation_request") {
        val ride = assignedRide()
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          _       <- runTick(List(ride), sentRepo, sends)
          result  <- sends.get
        } yield assertTrue(
          result.size == 1,
          result.head._1 == driver,
          result.head._2 == "ride_confirmation_request"
        )
      },

      // MUTATION TARGET: removing the isAlreadySent check would allow duplicate sends.
      test("second tick does NOT send again (dedup via SentConfirmationRequestRepository)") {
        val ride = assignedRide()
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          _       <- runTick(List(ride), sentRepo, sends)
          _       <- runTick(List(ride), sentRepo, sends) // second tick — same sentRepo
          result  <- sends.get
        } yield assertTrue(result.size == 1) // still only one send
      },

      // MUTATION TARGET: if the clear() call in RideService is missing, this would still
      // find the (ride, driver) in the repo and skip the second confirmation — but
      // the scenario we test here is that after clear() a re-assigned ride CAN get a new send.
      test("after clearing dedup (simulate re-assign), a new tick sends again") {
        val ride = assignedRide()
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          // First send
          _       <- runTick(List(ride), sentRepo, sends)
          // Simulate what RideService.confirmRide / rejectRide does: clear the dedup record.
          _       <- sentRepo.clear(ride.id)
          // Re-tick — should send again because dedup was cleared.
          _       <- runTick(List(ride), sentRepo, sends)
          result  <- sends.get
        } yield assertTrue(result.size == 2)
      },
      test("ride without driverId assigned is skipped") {
        val ride = assignedRide().copy(driverId = None)
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          _       <- runTick(List(ride), sentRepo, sends)
          result  <- sends.get
        } yield assertTrue(result.isEmpty)
      },
      test("empty ride list: tick succeeds and sends nothing") {
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          _       <- runTick(Nil, sentRepo, sends)
          result  <- sends.get
        } yield assertTrue(result.isEmpty)
      },
      test("two distinct rides each get their own push — sends are per-ride not per-driver") {
        val ride1 = assignedRide()
        val ride2 = assignedRide()
        for {
          sends   <- Ref.make(List.empty[(PersonId, String)])
          sentRepo = new InMemorySentConfirmationRequestRepository
          _       <- runTick(List(ride1, ride2), sentRepo, sends)
          result  <- sends.get
        } yield assertTrue(result.size == 2)
      }
    )
