package com.shevchyk.app

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.WebSocketEvent
import com.shevchyk.ride.application.service.FlightStatusProvider
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus, FlightStatusRow, Ride, RideSpecifics}
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.{Instant, ZoneId}

/**
 * Background flight-status monitor.
 *
 * Periodically scans upcoming airport-transfer rides, looks up each ride's flight via the [[FlightStatusProvider]], and
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
  private val BerlinZone       = ZoneId.of("Europe/Berlin")

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
      windowTo     = now.plusSeconds(LookAheadMinutes * 60L)
      rides       <- rideRepo.findAssignedRidesInWindow(now, windowTo)
      airportRides = rides.filter(_.isAirportTransfer)
      _           <- ZIO.foreachParDiscard(airportRides)(ride => evaluate(ride, rideRepo, provider, eventHub))
    yield ()

  private def evaluate(
      ride: Ride,
      rideRepo: RideRepository,
      provider: FlightStatusProvider,
      eventHub: EventHub
  ): ZIO[Any, Throwable, Unit] =
    ride.specifics match
      case Some(RideSpecifics.AirportTransfer(_, flightNumber, isArrival)) =>
        val date = ride.scheduledTime.getOrElse(ride.pickupDateTime).atZone(BerlinZone).toLocalDate
        provider.lookup(flightNumber, date, isArrival).flatMap {
          case None       => ZIO.unit // not found / source down → nothing to update this tick
          case Some(info) =>
            val newRow = toRow(info)
            rideRepo.findFlightStatus(ride.id).flatMap { current =>
              // Publish + persist only when the live data actually differs from what's stored.
              if current.contains(newRow) then ZIO.unit
              else
                rideRepo.updateFlightStatus(
                  ride.id,
                  gate = newRow.gate,
                  terminal = newRow.terminal,
                  flightStatus = newRow.flightStatus,
                  flightTime = newRow.flightTime,
                  scheduledTime = newRow.scheduledTime
                ) *>
                  eventHub.publish(
                    WebSocketEvent.FlightStatusUpdated(
                      rideId = ride.id.value,
                      clientId = ride.clientId.value,
                      companyId = ride.companyId.value,
                      flightNumber = info.flightNumber,
                      status = FlightStatus.toWire(info.status),
                      gate = newRow.gate,
                      terminal = newRow.terminal,
                      estimatedTime = newRow.flightTime.map(_.toString)
                    )
                  ) *>
                  ZIO.logInfo(
                    s"Flight ${info.flightNumber} for ride ${ride.id.value}: status=${FlightStatus.toWire(info.status)}"
                  )
            }
        }
      case _                                                               => ZIO.unit

  /**
   * Project the provider's [[FlightInfo]] onto the persisted [[FlightStatusRow]] (board has no gate → None).
   */
  private def toRow(info: FlightInfo): FlightStatusRow = FlightStatusRow(
    gate = info.gate,
    terminal = info.terminal,
    flightStatus = Some(FlightStatus.toWire(info.status)),
    // flightTime is the latest known (estimated, else scheduled); scheduledTime keeps the on-time instant
    // separately so the card can show the delay = flightTime - scheduledTime.
    flightTime = info.estimatedTime.orElse(info.scheduledTime),
    scheduledTime = info.scheduledTime
  )
