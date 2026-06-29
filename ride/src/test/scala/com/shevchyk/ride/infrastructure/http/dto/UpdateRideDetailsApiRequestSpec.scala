package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.ride.domain.*
import zio.test.*

object UpdateRideDetailsApiRequestSpec extends ZIOSpecDefault {

  def spec =
    suite("UpdateRideDetailsApiRequest.toDomain")(
      // ── isAirportTransfer is the authority for airportness (sent by the edit dialog) ──────────
      // Airportness is decoupled from the flight number: a ride can be an airport transfer with no
      // flight yet. The toggle decides whether specifics exist; the flight number only fills them.
      test("airport toggle on, with a flight number → Set carrying the flight") {
        val request = UpdateRideDetailsApiRequest(isAirportTransfer = Some(true), flightNumber = Some("LH123"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(
          domain.specifics match
            case FieldUpdate.Set(RideSpecifics.AirportTransfer(_, Some("LH123"), _)) => true
            case _                                                                   => false
        )
      },
      test("airport toggle on, no flight number → Set with flight None (airport without flight)") {
        val request = UpdateRideDetailsApiRequest(isAirportTransfer = Some(true), flightNumber = Some(""))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(
          domain.specifics match
            case FieldUpdate.Set(RideSpecifics.AirportTransfer(_, None, _)) => true
            case _                                                          => false
        )
      },
      test("airport toggle off → Clear (un-airport the ride)") {
        val request = UpdateRideDetailsApiRequest(isAirportTransfer = Some(false), flightNumber = Some("LH123"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics == FieldUpdate.Clear)
      },
      // ── Back-compat: callers that don't send the toggle fall back to flight-only semantics ────
      test("no toggle, a flight number value → Set") {
        val request = UpdateRideDetailsApiRequest(flightNumber = Some("LH123"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(
          domain.specifics match
            case FieldUpdate.Set(RideSpecifics.AirportTransfer(_, Some("LH123"), _)) => true
            case _                                                                   => false
        )
      },
      test("no toggle, an empty flight number → Clear") {
        val request = UpdateRideDetailsApiRequest(flightNumber = Some(""))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics == FieldUpdate.Clear)
      },
      // Absent toggle AND absent flight = "leave unchanged" — must NOT collapse into Clear, or any
      // unrelated edit would wipe the airport status.
      test("no toggle, an absent flight number → Unchanged") {
        val request = UpdateRideDetailsApiRequest(notes = Some("just a note"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics == FieldUpdate.Unchanged)
      }
    )
}
