package com.shevchyk.ride.application.service

import com.shevchyk.ride.domain.FlightInfo
import zio.*
import java.time.LocalDate

/**
 * In-memory [[FlightStatusProvider]] test double. Seeded flights are keyed by (normalized flight number, isArrival);
 * `lookup` ignores the date (tests seed per case). Backed by `Ref.Synchronized` so `seed` is safe across fibers.
 */
final class InMemoryFlightStatusProvider(store: Ref.Synchronized[Map[(String, Boolean), FlightInfo]])
    extends FlightStatusProvider:

  override def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]] =
    val key = (MucFlightParser.normalizeFlightNumber(flightNumber), isArrival)
    store.get.map(_.get(key))

  /**
   * Seed (or overwrite) the flight returned for its (number, direction).
   */
  def seed(info: FlightInfo): UIO[Unit] =
    val key = (MucFlightParser.normalizeFlightNumber(info.flightNumber), info.isArrival)
    store.update(_.updated(key, info))

object InMemoryFlightStatusProvider:

  def make: UIO[InMemoryFlightStatusProvider] = Ref.Synchronized
    .make(Map.empty[(String, Boolean), FlightInfo])
    .map(new InMemoryFlightStatusProvider(_))

  /**
   * A fresh, empty provider as a layer for wiring into test environments.
   */
  val layer: ZLayer[Any, Nothing, FlightStatusProvider] = ZLayer(make)
