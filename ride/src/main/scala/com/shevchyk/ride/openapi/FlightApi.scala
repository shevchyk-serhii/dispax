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
 * Tapir description and server logic for the dispatcher arrivals board.
 *
 * `GET /api/flights/arrivals?date=YYYY-MM-DD` returns the whole Munich arrivals board for the given date (default:
 * today), restricted to DISPATCHER / ADMIN. The data comes from the already-wired [[FlightStatusProvider.list]] (real
 * MUC scrape in prod, in-memory double in tests); a malformed `date` is a 400, an unexpected failure a 500.
 */
object FlightApi:

  private val flightsTag = "Flights"

  type FlightEnv = FlightStatusProvider & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Endpoint description ------------------------------------------------

  val arrivalsBoardEndpoint = secureEndpoint.get
    .in("api" / "flights" / "arrivals")
    .in(query[Option[String]]("date"))
    .out(jsonBody[List[FlightDto]])
    .tag(flightsTag)
    .summary("MUC arrivals board")

  val endpoints = List(arrivalsBoardEndpoint)

  // -- Server logic --------------------------------------------------------

  private val arrivalsBoardServer: ZServerEndpoint[FlightEnv, Any] = arrivalsBoardEndpoint.serverLogic {
    user => dateOpt =>
      for {
        _        <- checkRole(user, "DISPATCHER", "ADMIN")
        date     <- ZIO
                      .attempt(dateOpt.map(LocalDate.parse).getOrElse(LocalDate.now()))
                      .orElseFail((StatusCode.BadRequest, ApiError("Invalid date format, expected YYYY-MM-DD")))
        provider <- ZIO.service[FlightStatusProvider]
        flights  <- provider.list(date, isArrival = true).mapError(_ => internalError)
      } yield flights.map(FlightDto.fromDomain)
  }

  val serverEndpoints: List[ZServerEndpoint[FlightEnv, Any]] = List(arrivalsBoardServer)
