package com.shevchyk.app.openapi

import java.time.LocalDate

import zio.{Task, ZIO, ZLayer}

import com.shevchyk.ride.application.service.FlightStatusProvider
import com.shevchyk.ride.domain.FlightInfo

/**
 * An empty [[FlightStatusProvider]] for route specs that build the full `RideApi.RideEnv` (now including
 * `FlightStatusProvider`) but never exercise a flight lookup. Returns no flight / an empty board, so it is safe to wire
 * in without affecting the behaviour under test. `ride`'s own `InMemoryFlightStatusProvider` is not on the api test
 * classpath, hence this duplicate.
 */
object StubFlightStatusProvider:

  val layer: ZLayer[Any, Nothing, FlightStatusProvider] = ZLayer.succeed(new FlightStatusProvider:
    def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]] = ZIO.none
    def list(date: LocalDate, isArrival: Boolean): Task[List[FlightInfo]]                           = ZIO.succeed(Nil)
  )
