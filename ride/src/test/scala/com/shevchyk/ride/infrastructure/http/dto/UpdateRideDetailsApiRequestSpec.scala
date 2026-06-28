package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.ride.domain.*
import zio.test.*

object UpdateRideDetailsApiRequestSpec extends ZIOSpecDefault {

  def spec =
    suite("UpdateRideDetailsApiRequest.toDomain")(
      // Regression: the edit dialog sends only flightNumber (never isAirportTransfer), so gating
      // specifics on isAirportTransfer == Some(true) silently dropped flight-number updates.
      test("a flight number value becomes a Set specifics update") {
        val request = UpdateRideDetailsApiRequest(flightNumber = Some("LH123"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(
          domain.specifics match
            case FieldUpdate.Set(RideSpecifics.AirportTransfer(_, "LH123", _)) => true
            case _                                                             => false
        )
      },
      // Empty string = "clear" — distinct from absent. This is what lets a dispatcher wipe the
      // flight number; collapsing it into Unchanged would make clearing impossible.
      test("an empty flight number becomes a Clear specifics update") {
        val request = UpdateRideDetailsApiRequest(flightNumber = Some(""))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics == FieldUpdate.Clear)
      },
      // Absent = "leave unchanged" — must NOT collapse into Clear, or it would wipe the flight
      // number on any unrelated edit. Guards the previous flight-number fix.
      test("an absent flight number leaves specifics Unchanged") {
        val request = UpdateRideDetailsApiRequest(notes = Some("just a note"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics == FieldUpdate.Unchanged)
      }
    )
}
