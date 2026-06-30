package com.shevchyk.ride.application.service

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.WebSocketEvent
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus, FlightStatusRow, Ride, RideSpecifics}
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.ZoneId

/**
 * Refreshes ONE ride's flight status against the live board: look the flight up via the [[FlightStatusProvider]],
 * persist the gate/terminal/status/time columns, and publish a `WebSocketEvent.FlightStatusUpdated` when the data
 * actually changed.
 *
 * Shared by the background [[com.shevchyk.app.FlightStatusMonitor]] (its per-ride step) and the manual "refresh now"
 * endpoint, so both go through the exact same persist-and-broadcast path. Lives in the `ride` module (not `api`) so the
 * route layer can call it without the `ride`→`api` dependency cycle.
 */
object FlightStatusRefresher:

  private val BerlinZone = ZoneId.of("Europe/Berlin")

  /**
   * The outcome of a refresh, kept distinct so the caller can message the user precisely. Collapsing these into a bare
   * `Option` hides the difference the UI needs most: "the flight isn't on the board yet" (NotFound) vs "checked,
   * nothing changed" (Unchanged) — both otherwise look like "no update".
   */
  enum RefreshResult:
    case Updated(row: FlightStatusRow) // live data found and differed → persisted + event published
    case Unchanged                     // live data found but identical to what was stored (deduped)
    case NotFound // flight not on the board / source down, or the ride carries no usable flight number

  /**
   * Refresh [ride]'s flight status. Never fails for "flight not found" — that is a normal [[RefreshResult.NotFound]],
   * not an error; only genuine repository/provider failures surface.
   */
  def refresh(
      ride: Ride,
      rideRepo: RideRepository,
      provider: FlightStatusProvider,
      eventHub: EventHub
  ): ZIO[Any, Throwable, RefreshResult] =
    ride.specifics match
      // Only look up when a flight number is known — an airport transfer may have none yet.
      case Some(RideSpecifics.AirportTransfer(_, Some(flightNumber), isArrival)) if flightNumber.trim.nonEmpty =>
        val date = ride.scheduledTime.getOrElse(ride.pickupDateTime).atZone(BerlinZone).toLocalDate
        provider.lookup(flightNumber, date, isArrival).flatMap {
          case None       => ZIO.succeed(RefreshResult.NotFound) // not found / source down
          case Some(info) =>
            val newRow = toRow(info)
            rideRepo.findFlightStatus(ride.id).flatMap { current =>
              // Publish + persist only when the live data actually differs from what's stored.
              if current.contains(newRow) then ZIO.succeed(RefreshResult.Unchanged)
              else
                rideRepo.updateFlightStatus(
                  ride.id,
                  gate = newRow.gate,
                  terminal = newRow.terminal,
                  flightStatus = newRow.flightStatus,
                  flightTime = newRow.flightTime,
                  scheduledTime = newRow.scheduledTime,
                  departureTime = newRow.departureTime
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
                      estimatedTime = newRow.flightTime.map(_.toString),
                      departureTime = newRow.departureTime.map(_.toString)
                    )
                  ) *>
                  ZIO.logInfo(
                    s"Flight ${info.flightNumber} for ride ${ride.id.value}: status=${FlightStatus.toWire(info.status)}"
                  ) *>
                  ZIO.succeed(RefreshResult.Updated(newRow))
            }
        }
      case _                                                                                                   => ZIO.succeed(RefreshResult.NotFound)

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
    scheduledTime = info.scheduledTime,
    // Origin take-off (arrivals only), so the card can animate the en-route progress toward landing.
    departureTime = info.departureTime
  )
