package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.FlightStatusProvider
import com.shevchyk.ride.domain.{FlightInfo, FlightStatus}

import java.time.LocalDate
import com.shevchyk.ride.openapi.FlightApi
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

/**
 * Endpoint-level HTTP tests for the dispatcher arrivals board (`GET /api/flights/arrivals`).
 *
 * Routes are exercised via ZioHttpInterpreter against an in-memory [[FlightStatusProvider]] double — no network I/O.
 * The board is seeded with two arrivals and one departure; the endpoint must return only the arrivals and must reject a
 * non-dispatcher role with 403.
 */
object FlightApiSpec extends ZIOSpecDefault:

  private val companyId: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))

  private val dispatcher: Person = Person(
    id = PersonId(UUID.fromString("0000AADD-0000-0000-0000-000000000001")),
    name = "Dispatcher",
    email = "dispatch@acme.de",
    role = PersonRole.Dispatcher,
    companyId = Some(companyId)
  )

  private val client: Person = Person(
    id = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001")),
    name = "Client",
    email = "client@acme.de",
    role = PersonRole.Client,
    companyId = Some(companyId)
  )

  // -- JWT --------------------------------------------------------------------

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private def generateToken(person: Person): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(person)
  )

  // -- Seeded flight provider -------------------------------------------------

  private val arrival1: FlightInfo = FlightInfo(
    flightNumber = "LH123",
    isArrival = true,
    status = FlightStatus.Landed,
    terminal = Some("T2"),
    airline = Some("Lufthansa"),
    otherAirport = Some("FRA")
  )

  private val arrival2: FlightInfo = FlightInfo(
    flightNumber = "BA456",
    isArrival = true,
    status = FlightStatus.Delayed,
    terminal = Some("T1"),
    airline = Some("British Airways"),
    otherAirport = Some("LHR")
  )

  private val departure1: FlightInfo = FlightInfo(
    flightNumber = "LH999",
    isArrival = false,
    status = FlightStatus.Boarding,
    terminal = Some("T2"),
    otherAirport = Some("JFK")
  )

  // Inline in-memory FlightStatusProvider double — the ride-module InMemoryFlightStatusProvider lives in that
  // module's test sources, which are not on the api test classpath (only core test->test is exposed).
  private val seededFlights: List[FlightInfo] = List(arrival1, arrival2, departure1)

  private val seededProviderLayer: ZLayer[Any, Nothing, FlightStatusProvider] = ZLayer.succeed(
    new FlightStatusProvider:
      def lookup(flightNumber: String, date: LocalDate, isArrival: Boolean): Task[Option[FlightInfo]] = ZIO.succeed(
        seededFlights.find(f => f.flightNumber == flightNumber && f.isArrival == isArrival)
      )
      def list(date: LocalDate, isArrival: Boolean): Task[List[FlightInfo]]                           = ZIO.succeed(
        seededFlights.filter(_.isArrival == isArrival)
      )
  )

  // -- Route runner -----------------------------------------------------------

  private val routes: Routes[FlightApi.FlightEnv, Response] = ZioHttpInterpreter().toHttp(FlightApi.serverEndpoints)

  private def run(req: Request): ZIO[FlightApi.FlightEnv, Nothing, Response] = routes
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val testLayers: ZLayer[Any, Throwable, FlightApi.FlightEnv] = testJwtService ++ seededProviderLayer

  // -- Tests ------------------------------------------------------------------

  def spec = suite("FlightApi — arrivals board")(
    test("dispatcher GET /api/flights/arrivals → 200 with both arrivals, no departure") {
      for {
        token   <- generateToken(dispatcher)
        req      = Request
                     .get(URL.decode("/api/flights/arrivals?date=2026-06-27").toOption.get)
                     .addHeader(Header.Authorization.Bearer(token))
        resp    <- run(req)
        bodyStr <- resp.body.asString
      } yield assertTrue(
        resp.status == Status.Ok,
        bodyStr.contains("LH123"),
        bodyStr.contains("BA456"),
        !bodyStr.contains("LH999")
      )
    },
    test("dispatcher GET without date defaults to today → 200 with arrivals") {
      for {
        token   <- generateToken(dispatcher)
        req      = Request
                     .get(URL.decode("/api/flights/arrivals").toOption.get)
                     .addHeader(Header.Authorization.Bearer(token))
        resp    <- run(req)
        bodyStr <- resp.body.asString
      } yield assertTrue(
        resp.status == Status.Ok,
        bodyStr.contains("LH123"),
        bodyStr.contains("BA456")
      )
    },
    test("client (non-dispatcher) → 403") {
      for {
        token <- generateToken(client)
        req    = Request
                   .get(URL.decode("/api/flights/arrivals").toOption.get)
                   .addHeader(Header.Authorization.Bearer(token))
        resp  <- run(req)
      } yield assertTrue(resp.status == Status.Forbidden)
    },
    test("without authentication → 401") {
      val req = Request.get(URL.decode("/api/flights/arrivals").toOption.get)
      run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
    },
    test("invalid date format → 400") {
      for {
        token <- generateToken(dispatcher)
        req    = Request
                   .get(URL.decode("/api/flights/arrivals?date=not-a-date").toOption.get)
                   .addHeader(Header.Authorization.Bearer(token))
        resp  <- run(req)
      } yield assertTrue(resp.status == Status.BadRequest)
    }
  ).provide(testLayers)
