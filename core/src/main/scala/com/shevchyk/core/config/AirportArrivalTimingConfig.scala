package com.shevchyk.core.config

import zio.*

/**
 * Global defaults for the airport-arrival terminal-entry timing calculation.
 *
 * For an arrival ride the driver wants to enter the (paid) terminal parking at the right moment: late enough to use the
 * free-parking window, early enough that the passenger does not wait. The recommended entry time is derived from the
 * flight arrival time plus a terminal-dependent "walk-out" buffer (time for the passenger to reach the curbside),
 * pulled back by the free-parking window so the driver stays within the free minutes.
 *
 * All values are read from environment variables so they can be tuned per environment without redeploying.
 *
 * Defaults (when env vars are absent):
 *   - AIRPORT_ARRIVAL_WALK_MINUTES=10 — a normal terminal (T1/T2): time from landing to curbside.
 *   - AIRPORT_ARRIVAL_SATELLITE_WALK_MINUTES=18 — a satellite/remote terminal (MUC "Terminal K" / the T2 satellite)
 *     where the passenger first takes an internal train to the main terminal, so the walk-out takes longer.
 *   - AIRPORT_FREE_PARKING_MINUTES=10 — length of the free terminal-parking window.
 *   - AIRPORT_SATELLITE_TERMINALS=K,T2K — terminal codes classified as satellite (larger walk buffer).
 *
 * The parking costs are illustrative figures kept solely so the existing `airport-timing` JSON contract (consumed by
 * the Flutter `AirportTiming` model) stays unchanged; `savings = earlyEntryParkingCost − optimalParkingCost`.
 */
final case class AirportArrivalTimingConfig(
    normalWalkMinutes: Int,
    satelliteWalkMinutes: Int,
    freeParkingMinutes: Int,
    satelliteTerminalCodes: Set[String],
    // Gate leading letters that mark a satellite pier (longer walk-out). At MUC the gate encodes the pier:
    // K/L are the T2 satellite, G/H/etc are the main terminal. Preferred over the terminal code when a gate is known.
    satelliteGateLetters: Set[String],
    optimalParkingCost: Double,
    earlyEntryParkingCost: Double
)

object AirportArrivalTimingConfig:

  private def envInt(name: String, default: Int): Int = sys.env.get(name).flatMap(_.toIntOption).getOrElse(default)

  private def envDouble(name: String, default: Double): Double = sys.env
    .get(name)
    .flatMap(_.toDoubleOption)
    .getOrElse(default)

  private def envTerminals(name: String, default: Set[String]): Set[String] = sys.env
    .get(name)
    .map(_.split(',').iterator.map(_.trim.toUpperCase).filter(_.nonEmpty).toSet)
    .filter(_.nonEmpty)
    .getOrElse(default)

  val liveLayer: ZLayer[Any, Nothing, AirportArrivalTimingConfig] = ZLayer.succeed(
    AirportArrivalTimingConfig(
      normalWalkMinutes = envInt("AIRPORT_ARRIVAL_WALK_MINUTES", 10),
      satelliteWalkMinutes = envInt("AIRPORT_ARRIVAL_SATELLITE_WALK_MINUTES", 18),
      freeParkingMinutes = envInt("AIRPORT_FREE_PARKING_MINUTES", 10),
      satelliteTerminalCodes = envTerminals("AIRPORT_SATELLITE_TERMINALS", Set("K", "T2K")),
      satelliteGateLetters = envTerminals("AIRPORT_SATELLITE_GATE_LETTERS", Set("K", "L")),
      optimalParkingCost = envDouble("AIRPORT_OPTIMAL_PARKING_COST", 0.0),
      earlyEntryParkingCost = envDouble("AIRPORT_EARLY_PARKING_COST", 28.0)
    )
  )
