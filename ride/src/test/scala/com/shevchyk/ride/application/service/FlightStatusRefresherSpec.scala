package com.shevchyk.ride.application.service

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.FlightStatusRefresher.RefreshResult
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for the shared single-ride flight refresher. Covers the three outcomes the UI relies on — Updated (board
 * had newer data → persisted + event), Unchanged (deduped), NotFound (flight not on the board / no flight number) —
 * plus that an event is published only on Updated.
 */
object FlightStatusRefresherSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.randomUUID())
  private val client   = PersonId(UUID.randomUUID())

  private def airportRide(flightNumber: Option[String], isArrival: Boolean = true): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = client,
    creatorId = client,
    companyId = companyA,
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz, München"),
    dropoffLocation = Location("Munich Airport"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", flightNumber, isArrival))
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

  // EventHub double recording every published event.
  private def recordingHub(ref: Ref[List[WebSocketEvent]]): EventHub =
    new EventHub:
      def publish(event: WebSocketEvent): UIO[Boolean]            = ref.update(_ :+ event).as(true)
      def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] =
        throw new NotImplementedError("unexpected EventHub.subscribe")

  def spec =
    suite("FlightStatusRefresher.refresh")(
      test("Updated: persists the new row and publishes FlightStatusUpdated") {
        val ride = airportRide(Some("LH123"))
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make
          _        <- provider.seed(sampleInfo)
          events   <- Ref.make(List.empty[WebSocketEvent])
          result   <- FlightStatusRefresher.refresh(created, repo, provider, recordingHub(events))
          stored   <- repo.findFlightStatus(created.id)
          ev       <- events.get
        yield assertTrue(
          result match { case RefreshResult.Updated(_) => true; case _ => false },
          stored.exists(r => r.flightStatus.contains("landed") && r.gate.contains("H14") && r.terminal.contains("T2")),
          // estimated time wins over scheduled
          stored.exists(_.flightTime.contains(Instant.parse("2026-06-26T08:20:00Z"))),
          ev.size == 1
        )
      },
      test("Unchanged: a second refresh with identical data dedups — no new event") {
        val ride = airportRide(Some("LH123"))
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make
          _        <- provider.seed(sampleInfo)
          events   <- Ref.make(List.empty[WebSocketEvent])
          hub       = recordingHub(events)
          _        <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          second   <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          ev       <- events.get
        yield assertTrue(
          second == RefreshResult.Unchanged,
          ev.size == 1 // only the first (Updated) published
        )
      },
      // Regression: the dedup used to compare the RAW scrape row against the stored one, while the
      // repository COALESCEs gate/terminal/scheduled/departure. A tick whose detail scrape dropped the
      // gate (None) then differed from the stored row FOREVER — re-persisting and re-publishing an
      // identical visible state every 5 minutes (WS event storm, false "Updated" on manual refresh).
      test("Unchanged: a scrape that drops the gate/terminal but changes nothing else dedups") {
        val ride     = airportRide(Some("LH123"))
        val gateless = sampleInfo.copy(gate = None, terminal = None)
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make
          _        <- provider.seed(sampleInfo)
          events   <- Ref.make(List.empty[WebSocketEvent])
          hub       = recordingHub(events)
          _        <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          _        <- provider.seed(gateless) // detail page failed this tick — same status/times, no gate
          second   <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          stored   <- repo.findFlightStatus(created.id)
          ev       <- events.get
        yield assertTrue(
          second == RefreshResult.Unchanged,
          ev.size == 1, // only the first (Updated) published
          stored.exists(_.gate.contains("H14")) // the stored gate survived the gateless tick
        )
      },
      test("Updated: a real status change with a gateless scrape publishes the STORED gate (effective row)") {
        val ride           = airportRide(Some("LH123"))
        val landedGateless = sampleInfo.copy(status = FlightStatus.Landed, gate = None, terminal = None)
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make
          _        <- provider.seed(sampleInfo.copy(status = FlightStatus.EnRoute))
          events   <- Ref.make(List.empty[WebSocketEvent])
          hub       = recordingHub(events)
          _        <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          _        <- provider.seed(landedGateless) // landed, but the gate detail failed this tick
          second   <- FlightStatusRefresher.refresh(created, repo, provider, hub)
          ev       <- events.get
        yield assertTrue(
          second match { case RefreshResult.Updated(row) => row.gate.contains("H14"); case _ => false },
          ev.size == 2,
          ev.lastOption.exists {
            case e: WebSocketEvent.FlightStatusUpdated => e.status == "landed" && e.gate.contains("H14")
            case _                                     => false
          }
        )
      },
      test("NotFound: flight not on the board → no event, status untouched (the DE1811 case)") {
        val ride = airportRide(Some("DE1811"))
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make // nothing seeded → lookup returns None
          events   <- Ref.make(List.empty[WebSocketEvent])
          result   <- FlightStatusRefresher.refresh(created, repo, provider, recordingHub(events))
          stored   <- repo.findFlightStatus(created.id)
          ev       <- events.get
        yield assertTrue(
          result == RefreshResult.NotFound,
          ev.isEmpty,
          // nothing was written — the flight columns stay empty
          stored.forall(!_.nonEmpty)
        )
      },
      test("NotFound: an airport ride with no flight number is skipped") {
        val ride = airportRide(None)
        for
          repo     <- ZIO.succeed(new InMemoryRideRepository)
          created  <- repo.create(ride)
          provider <- InMemoryFlightStatusProvider.make
          _        <- provider.seed(sampleInfo)
          events   <- Ref.make(List.empty[WebSocketEvent])
          result   <- FlightStatusRefresher.refresh(created, repo, provider, recordingHub(events))
          ev       <- events.get
        yield assertTrue(result == RefreshResult.NotFound, ev.isEmpty)
      }
    )
