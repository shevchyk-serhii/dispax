package com.shevchyk.app

import com.shevchyk.core.application.EventHub
import com.shevchyk.ride.application.service.{FlightStatusProvider, FlightStatusRefresher}
import com.shevchyk.ride.domain.Ride
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.Instant

/**
 * Background flight-status monitor.
 *
 * Periodically scans upcoming airport-transfer rides (including still-unassigned `Requested` ones, so the dispatcher
 * sees the gate/terminal before assigning a driver), looks up each ride's flight via the [[FlightStatusProvider]], and
 * — when the live data differs from what is currently persisted — writes the new gate/terminal/status/time and emits a
 * `WebSocketEvent.FlightStatusUpdated` so dispatchers and the client see the change without a manual refresh.
 *
 * Mirrors [[PredictiveEtaMonitor]]: bounded-parallel `tick` on a fixed schedule, run as a daemon fiber. Deduplication
 * is by comparison — it publishes only when the freshly fetched values differ from the row already stored, so a stable
 * flight produces no repeat events (no separate alert table needed).
 */
object FlightStatusMonitor:

  // How far ahead to look for airport-transfer pickups worth tracking.
  private val LookAheadMinutes = 180L

  // How far BACK to keep tracking a still-active ride after its scheduled pickup has passed. A
  // delayed arrival (plane still in the air past the planned pickup) or an InProgress transfer
  // must not drop out of the window the moment `now` crosses `pickup_datetime` — that is exactly
  // when live gate/status/landing-time updates matter most. Bounded so a ride stuck in an active
  // status forever stops generating scrapes eventually. Package-private for the spec.
  private[app] val LookBackMinutes = 360L

  type Env = RideRepository & FlightStatusProvider & EventHub

  def start: ZIO[Env, Nothing, Unit] =
    // Bound concurrency so a busy window doesn't fire many simultaneous scrapes at the airport board.
    val safeTick = tick.withParallelism(4).catchAll(e => ZIO.logError(s"FlightStatusMonitor error: $e"))
    ZIO.logInfo("FlightStatusMonitor started") *>
      safeTick.repeat(Schedule.fixed(5.minutes)).forkDaemon.unit

  /**
   * A single monitoring pass. Exposed for deterministic tests.
   */
  private[app] def tick: ZIO[Env, Throwable, Unit] =
    for
      rideRepo    <- ZIO.service[RideRepository]
      provider    <- ZIO.service[FlightStatusProvider]
      eventHub    <- ZIO.service[EventHub]
      now          = Instant.now()
      windowFrom   = now.minusSeconds(LookBackMinutes * 60L)
      windowTo     = now.plusSeconds(LookAheadMinutes * 60L)
      // Includes still-unassigned (Requested) rides so a dispatcher sees the gate/terminal in
      // the pending list before assigning a driver — not only after assignment.
      rides       <- rideRepo.findActiveRidesInWindow(windowFrom, windowTo)
      airportRides = rides.filter(_.isAirportTransfer)
      _           <- ZIO.foreachParDiscard(airportRides)(ride => evaluate(ride, rideRepo, provider, eventHub))
    yield ()

  // The per-ride work — persist + broadcast on change — lives in the shared [[FlightStatusRefresher]]
  // (in the `ride` module) so the manual "refresh now" endpoint goes through the exact same path.
  private def evaluate(
      ride: Ride,
      rideRepo: RideRepository,
      provider: FlightStatusProvider,
      eventHub: EventHub
  ): ZIO[Any, Throwable, Unit] = FlightStatusRefresher.refresh(ride, rideRepo, provider, eventHub).unit
