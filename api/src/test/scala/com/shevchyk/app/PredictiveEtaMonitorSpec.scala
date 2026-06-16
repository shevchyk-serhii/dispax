package com.shevchyk.app

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.driver.application.EtaService
import com.shevchyk.notification.repository.EtaAlertRepository
import com.shevchyk.ride.domain.{DriverEarnings, Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, TimeBucket}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

object PredictiveEtaMonitorSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.randomUUID())
  private val companyB = CompanyId(UUID.randomUUID())
  private val driver   = PersonId(UUID.randomUUID())
  private val client   = PersonId(UUID.randomUUID())

  // A ride assigned to `driver`, picking up `pickupInMinutes` from now.
  private def assignedRide(pickupInMinutes: Long, company: CompanyId = companyA): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = company,
    driverId = Some(driver),
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz, München"),
    dropoffLocation = Location("Munich Airport"),
    pickupDateTime = Instant.now().plusSeconds(pickupInMinutes * 60L)
  )

  // RideRepository stub: only the window query is exercised.
  private def rideRepoStub(rides: List[Ride]): RideRepository =
    new RideRepository:
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected RideRepository.$m")

      def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = ZIO.succeed(rides)

      def create(ride: Ride): Task[Ride]                                                                          = nope("create")
      def findById(id: RideId): Task[Option[Ride]]                                                                = nope("findById")
      def findByStatus(status: RideStatus): Task[List[Ride]]                                                      = nope("findByStatus")
      def findAll(): Task[List[Ride]]                                                                             = nope("findAll")
      def findByClientId(clientId: PersonId): Task[List[Ride]]                                                    = nope("findByClientId")
      def findByDriverId(driverId: PersonId): Task[List[Ride]]                                                    = nope("findByDriverId")
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                                 = nope("findByCompanyId")
      def update(ride: Ride): Task[Ride]                                                                          = nope("update")
      def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                            = nope("updateIfStatus")
      def delete(id: RideId): Task[Unit]                                                                          = nope("delete")
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
          bucket: TimeBucket
      ): Task[List[(Instant, BigDecimal)]] = nope("earningsBucketsByDriver")
      def clearReminders(rideId: RideId): Task[Unit]                                                              = nope("clearReminders")
      def countAllRidesByStatus(): Task[Map[String, Int]]                                                         = nope("countAllRidesByStatus")
      def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                             = nope("sumAllRevenue")
      def countRidesByCompany(from: Instant, to: Instant): Task[Map[java.util.UUID, Int]]                         = nope(
        "countRidesByCompany"
      )
      def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[java.util.UUID, BigDecimal]]          = nope(
        "sumRevenueByCompanyPlatform"
      )
      def updateCheckpoint(rideId: RideId, checkpoint: com.shevchyk.ride.domain.AirportCheckpoint): Task[Boolean] =
        nope(
          "updateCheckpoint"
        )

  // EtaService stub returning a fixed ETA.
  private def etaServiceStub(eta: Option[Int]): EtaService =
    new EtaService:
      def etaForRide(ride: Ride): Task[Option[Int]] = ZIO.succeed(eta)

  // In-memory EtaAlertRepository tracking the (ride, driver) pairs already alerted.
  private def alertRepoStub(ref: Ref[Set[(RideId, PersonId)]]): EtaAlertRepository =
    new EtaAlertRepository:
      def isAlreadyAlerted(rideId: RideId, driverId: PersonId): Task[Boolean] = ref.get.map(
        _.contains((rideId, driverId))
      )
      def markAlerted(rideId: RideId, driverId: PersonId): Task[Unit]         = ref.update(_ + ((rideId, driverId)))
      def clear(rideId: RideId): Task[Unit]                                   = ref.update(_.filterNot(_._1 == rideId))

  // EventHub stub recording published events.
  private def eventHubStub(ref: Ref[List[WebSocketEvent]]): EventHub =
    new EventHub:
      def publish(event: WebSocketEvent): UIO[Boolean]            = ref.update(_ :+ event).as(true)
      def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] =
        throw new NotImplementedError("unexpected EventHub.subscribe")

  private def runTick(
      rides: List[Ride],
      eta: Option[Int],
      events: Ref[List[WebSocketEvent]],
      alerts: Ref[Set[(RideId, PersonId)]]
  ): Task[Unit] = PredictiveEtaMonitor.tick.provide(
    ZLayer.succeed(rideRepoStub(rides)),
    ZLayer.succeed(etaServiceStub(eta)),
    ZLayer.succeed(alertRepoStub(alerts)),
    ZLayer.succeed(eventHubStub(events))
  )

  def spec =
    suite("PredictiveEtaMonitor.tick")(
      test("publishes EtaAtRisk when slack is below threshold (driver will be late)") {
        // Pickup in 10 min, ETA 20 min → slack = -10 → at risk.
        val ride = assignedRide(pickupInMinutes = 10)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          alerts <- Ref.make(Set.empty[(RideId, PersonId)])
          _      <- runTick(List(ride), eta = Some(20), events, alerts)
          ev     <- events.get
        yield assertTrue(
          ev.size == 1,
          ev.head match
            case WebSocketEvent.EtaAtRisk(rid, _, _, e, until, slack, cid) =>
              // Pickup ~10 min out, ETA 20 → slack is negative (driver late).
              rid == ride.id.value && e == 20 && slack < 0 && until <= 10 && cid == companyA.value
            case _                                                         => false
        )
      },
      test("does not publish when there is comfortable slack") {
        // Pickup in 60 min, ETA 10 min → slack = 50 → fine.
        val ride = assignedRide(pickupInMinutes = 60)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          alerts <- Ref.make(Set.empty[(RideId, PersonId)])
          _      <- runTick(List(ride), eta = Some(10), events, alerts)
          ev     <- events.get
        yield assertTrue(ev.isEmpty)
      },
      test("does not re-alert on a second tick (dedup)") {
        val ride = assignedRide(pickupInMinutes = 10)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          alerts <- Ref.make(Set.empty[(RideId, PersonId)])
          _      <- runTick(List(ride), eta = Some(20), events, alerts)
          _      <- runTick(List(ride), eta = Some(20), events, alerts)
          ev     <- events.get
        yield assertTrue(ev.size == 1)
      },
      test("does nothing when ETA cannot be computed (no driver location)") {
        val ride = assignedRide(pickupInMinutes = 5)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          alerts <- Ref.make(Set.empty[(RideId, PersonId)])
          _      <- runTick(List(ride), eta = None, events, alerts)
          ev     <- events.get
        yield assertTrue(ev.isEmpty)
      },
      test("at-risk event carries the ride's own companyId (tenant isolation)") {
        val rideB = assignedRide(pickupInMinutes = 10, company = companyB)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          alerts <- Ref.make(Set.empty[(RideId, PersonId)])
          _      <- runTick(List(rideB), eta = Some(30), events, alerts)
          ev     <- events.get
        yield assertTrue(
          ev.size == 1,
          ev.head.companyId == companyB.value
        )
      }
    )
