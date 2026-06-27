package com.shevchyk.app

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.FlightStatusProvider
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{RideRepository, TimeBucket}
import zio.*
import zio.test.*

import java.time.{Instant, LocalDate}
import java.util.UUID

object FlightStatusMonitorSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.randomUUID())
  private val driver   = PersonId(UUID.randomUUID())
  private val client   = PersonId(UUID.randomUUID())

  // An assigned airport-transfer ride picking up `pickupInMinutes` from now.
  private def airportRide(
      flightNumber: String,
      isArrival: Boolean,
      pickupInMinutes: Long = 60,
      company: CompanyId = companyA
  ): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = company,
    driverId = Some(driver),
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz, München"),
    dropoffLocation = Location("Munich Airport"),
    pickupDateTime = Instant.now().plusSeconds(pickupInMinutes * 60L),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", flightNumber, isArrival))
  )

  // RideRepository stub: serves the window query and a mutable per-ride flight-status store so dedup is exercised.
  private def rideRepoStub(rides: List[Ride], store: Ref[Map[RideId, FlightStatusRow]]): RideRepository =
    new RideRepository:
      private def nope(m: String): Nothing = throw new NotImplementedError(s"unexpected RideRepository.$m")

      def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = ZIO.succeed(rides)

      def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]] = store.get.map(m =>
        Some(m.getOrElse(rideId, FlightStatusRow()))
      )

      def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]] = store.get.map(m =>
        rideIds.flatMap(id => m.get(id).map(id -> _)).toMap
      )

      def updateFlightStatus(
          rideId: RideId,
          gate: Option[String],
          terminal: Option[String],
          flightStatus: Option[String],
          flightTime: Option[Instant],
          scheduledTime: Option[Instant]
      ): Task[Boolean] = store
        .update(
          _.updated(rideId, FlightStatusRow(gate, terminal, flightStatus, flightTime, scheduledTime))
        )
        .as(true)

      def create(ride: Ride): Task[Ride]                                                                = nope("create")
      def findById(id: RideId): Task[Option[Ride]]                                                      = nope("findById")
      def findByStatus(status: RideStatus): Task[List[Ride]]                                            = nope("findByStatus")
      def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]            = nope(
        "findByStatusAndCompany"
      )
      def findAll(): Task[List[Ride]]                                                                   = nope("findAll")
      def findByClientId(clientId: PersonId): Task[List[Ride]]                                          = nope("findByClientId")
      def findByDriverId(driverId: PersonId): Task[List[Ride]]                                          = nope("findByDriverId")
      def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]          = nope(
        "findByDriverIdAndCompany"
      )
      def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]          = nope(
        "findByClientIdAndCompany"
      )
      def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                       = nope("findByCompanyId")
      def findByCompanyIdPaginated(c: CompanyId, offset: Int, limit: Int): Task[List[Ride]]             = nope(
        "findByCompanyIdPaginated"
      )
      def findByDriverIdPaginated(d: PersonId, offset: Int, limit: Int): Task[List[Ride]]               = nope(
        "findByDriverIdPaginated"
      )
      def findByDriverIdAndCompanyPaginated(
          d: PersonId,
          c: CompanyId,
          offset: Int,
          limit: Int
      ): Task[List[Ride]] = nope("findByDriverIdAndCompanyPaginated")
      def update(ride: Ride): Task[Ride]                                                                = nope("update")
      def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                  = nope("updateIfStatus")
      def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]      = nope(
        "markPaidIfCompleted"
      )
      def delete(id: RideId, companyId: CompanyId): Task[Unit]                                          = nope("delete")
      def countByCompanyGroupedByStatus(c: CompanyId): Task[Map[String, Int]]                           = nope(
        "countByCompanyGroupedByStatus"
      )
      def sumRevenueByCompany(c: CompanyId): Task[BigDecimal]                                           = nope("sumRevenueByCompany")
      def sumTodayRevenueByCompany(c: CompanyId): Task[BigDecimal]                                      = nope(
        "sumTodayRevenueByCompany"
      )
      def avgAssignmentMinutesByCompany(c: CompanyId): Task[Double]                                     = nope(
        "avgAssignmentMinutesByCompany"
      )
      def countDailyStatsByCompany(c: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]        = nope(
        "countDailyStatsByCompany"
      )
      def earningsByDriver(d: PersonId, c: CompanyId, from: Instant, to: Instant): Task[DriverEarnings] = nope(
        "earningsByDriver"
      )
      def earningsBucketsByDriver(
          d: PersonId,
          c: CompanyId,
          from: Instant,
          to: Instant,
          bucket: TimeBucket
      ): Task[List[(Instant, BigDecimal)]] = nope("earningsBucketsByDriver")
      def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]]                    = nope(
        "findRidesNeedingConfirmation"
      )
      def clearReminders(rideId: RideId): Task[Unit]                                                    = nope("clearReminders")
      def countAllRidesByStatus(): Task[Map[String, Int]]                                               = nope(
        "countAllRidesByStatus"
      )
      def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                   = nope("sumAllRevenue")
      def countRidesByCompany(from: Instant, to: Instant): Task[Map[UUID, Int]]                         = nope(
        "countRidesByCompany"
      )
      def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[UUID, BigDecimal]]          = nope(
        "sumRevenueByCompanyPlatform"
      )
      def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean]                = nope("updateCheckpoint")

  // FlightStatusProvider stub returning a fixed FlightInfo (or None).
  private def providerStub(result: Option[FlightInfo]): FlightStatusProvider =
    new FlightStatusProvider:
      def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]] = ZIO.succeed(
        result
      )
      def list(date: LocalDate, isArrival: Boolean): Task[List[FlightInfo]]                           = ZIO.succeed(Nil)

  private def eventHubStub(ref: Ref[List[WebSocketEvent]]): EventHub =
    new EventHub:
      def publish(event: WebSocketEvent): UIO[Boolean]            = ref.update(_ :+ event).as(true)
      def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] =
        throw new NotImplementedError("unexpected EventHub.subscribe")

  private def runTick(
      rides: List[Ride],
      info: Option[FlightInfo],
      events: Ref[List[WebSocketEvent]],
      store: Ref[Map[RideId, FlightStatusRow]]
  ): Task[Unit] = FlightStatusMonitor.tick.provide(
    ZLayer.succeed(rideRepoStub(rides, store)),
    ZLayer.succeed(providerStub(info)),
    ZLayer.succeed(eventHubStub(events))
  )

  private val sampleInfo = FlightInfo(
    flightNumber = "LH123",
    isArrival = true,
    status = FlightStatus.Landed,
    scheduledTime = Some(Instant.parse("2026-06-26T08:00:00Z")),
    estimatedTime = Some(Instant.parse("2026-06-26T08:20:00Z")),
    terminal = Some("T2"),
    gate = Some("H14")
  )

  def spec =
    suite("FlightStatusMonitor.tick")(
      test("persists flight status and publishes FlightStatusUpdated on first sighting") {
        val ride = airportRide("LH123", isArrival = true)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          store  <- Ref.make(Map.empty[RideId, FlightStatusRow])
          _      <- runTick(List(ride), Some(sampleInfo), events, store)
          ev     <- events.get
          saved  <- store.get
        yield assertTrue(
          ev.size == 1,
          ev.head match
            case WebSocketEvent.FlightStatusUpdated(rid, cid, comp, num, status, gate, term, _) =>
              rid == ride.id.value && cid == client.value && comp == companyA.value &&
              num == "LH123" && status == "landed" && term.contains("T2") && gate.contains("H14")
            case _                                                                              => false,
          saved
            .get(ride.id)
            .exists(r => r.flightStatus.contains("landed") && r.terminal.contains("T2") && r.gate.contains("H14")),
          // estimated time wins over scheduled
          saved.get(ride.id).exists(_.flightTime.contains(Instant.parse("2026-06-26T08:20:00Z")))
        )
      },
      test("does not re-publish on a second tick with unchanged data (dedup)") {
        val ride = airportRide("LH123", isArrival = true)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          store  <- Ref.make(Map.empty[RideId, FlightStatusRow])
          _      <- runTick(List(ride), Some(sampleInfo), events, store)
          _      <- runTick(List(ride), Some(sampleInfo), events, store)
          ev     <- events.get
        yield assertTrue(ev.size == 1)
      },
      test("publishes again when the flight data changes") {
        val ride    = airportRide("LH123", isArrival = true)
        val delayed = sampleInfo.copy(status = FlightStatus.Delayed, terminal = Some("T1"))
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          store  <- Ref.make(Map.empty[RideId, FlightStatusRow])
          _      <- runTick(List(ride), Some(sampleInfo), events, store)
          _      <- runTick(List(ride), Some(delayed), events, store)
          ev     <- events.get
        yield assertTrue(
          ev.size == 2,
          ev.last match
            case WebSocketEvent.FlightStatusUpdated(_, _, _, _, status, _, term, _) =>
              status == "delayed" && term.contains("T1")
            case _                                                                  => false
        )
      },
      test("ignores non-airport rides") {
        val plain = airportRide("LH123", isArrival = true).copy(specifics = None)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          store  <- Ref.make(Map.empty[RideId, FlightStatusRow])
          _      <- runTick(List(plain), Some(sampleInfo), events, store)
          ev     <- events.get
        yield assertTrue(ev.isEmpty)
      },
      test("does nothing when the provider returns no flight") {
        val ride = airportRide("XX000", isArrival = false)
        for
          events <- Ref.make(List.empty[WebSocketEvent])
          store  <- Ref.make(Map.empty[RideId, FlightStatusRow])
          _      <- runTick(List(ride), None, events, store)
          ev     <- events.get
          saved  <- store.get
        yield assertTrue(ev.isEmpty, saved.isEmpty)
      }
    )
