package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.FlightStatusProvider
import com.shevchyk.ride.infrastructure.http.FlightDto
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.LocalDate

/**
 * Tapir description and server logic for the MUC flights board.
 *
 * `GET /api/flights/arrivals?date=YYYY-MM-DD&isArrival=true` returns the whole Munich board for the given date
 * (default: today) and direction (`isArrival` defaults to `true`, so existing arrivals-only callers keep working). The
 * data comes from the already-wired [[FlightStatusProvider.list]] (real MUC scrape in prod, in-memory double in tests);
 * a malformed `date` is a 400, an unexpected failure a 500.
 *
 * `GET /api/flights/lookup?flightNumber=…&date=YYYY-MM-DD&isArrival=true` returns a single flight WITH its gate (the
 * board view has no gate — it lives on each flight's detail page). It is a thin wrapper over
 * [[FlightStatusProvider.lookup]], which already enriches the row with the gate from the detail page. `null` when the
 * flight is not found.
 *
 * Both endpoints are open to all internal roles (DRIVER / SECRETARY / DISPATCHER / ADMIN) — flight-number
 * autosuggestion in the ride form must work for everyone who creates rides. CLIENT is deliberately excluded: exposing
 * the full airport board to external users is a separate product decision; the app degrades to a plain input without
 * suggestions for them.
 */
object FlightApi:

  private val flightsTag = "Flights"

  type FlightEnv = FlightStatusProvider & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Endpoint description ------------------------------------------------

  val arrivalsBoardEndpoint = secureEndpoint.get
    .in("api" / "flights" / "arrivals")
    .in(query[Option[String]]("date"))
    .in(query[Option[Boolean]]("isArrival"))
    .out(jsonBody[List[FlightDto]])
    .tag(flightsTag)
    .summary("MUC flights board (arrivals/departures)")

  val flightLookupEndpoint = secureEndpoint.get
    .in("api" / "flights" / "lookup")
    .in(query[String]("flightNumber"))
    .in(query[Option[String]]("date"))
    .in(query[Option[Boolean]]("isArrival"))
    .out(jsonBody[Option[FlightDto]])
    .tag(flightsTag)
    .summary("MUC single-flight lookup (with gate)")

  val endpoints = List(arrivalsBoardEndpoint, flightLookupEndpoint)

  // -- Server logic --------------------------------------------------------

  private val arrivalsBoardServer: ZServerEndpoint[FlightEnv, Any] = arrivalsBoardEndpoint.serverLogic {
    user => (dateOpt, isArrivalOpt) =>
      for {
        _        <- checkRole(user, "DRIVER", "SECRETARY", "DISPATCHER", "ADMIN")
        date     <- ZIO
                      .attempt(dateOpt.map(LocalDate.parse).getOrElse(LocalDate.now()))
                      .orElseFail((StatusCode.BadRequest, ApiError("Invalid date format, expected YYYY-MM-DD")))
        provider <- ZIO.service[FlightStatusProvider]
        flights  <- provider.list(date, isArrival = isArrivalOpt.getOrElse(true)).mapError(_ => internalError)
      } yield flights.map(FlightDto.fromDomain)
  }

  private val flightLookupServer: ZServerEndpoint[FlightEnv, Any] = flightLookupEndpoint.serverLogic {
    user => (flightNumber, dateOpt, isArrivalOpt) =>
      for {
        _        <- checkRole(user, "DRIVER", "SECRETARY", "DISPATCHER", "ADMIN")
        date     <- ZIO
                      .attempt(dateOpt.map(LocalDate.parse).getOrElse(LocalDate.now()))
                      .orElseFail((StatusCode.BadRequest, ApiError("Invalid date format, expected YYYY-MM-DD")))
        provider <- ZIO.service[FlightStatusProvider]
        flight   <- provider
                      .lookup(flightNumber, date, isArrival = isArrivalOpt.getOrElse(true))
                      .mapError(_ => internalError)
      } yield flight.map(FlightDto.fromDomain)
  }

  val serverEndpoints: List[ZServerEndpoint[FlightEnv, Any]] = List(arrivalsBoardServer, flightLookupServer)
