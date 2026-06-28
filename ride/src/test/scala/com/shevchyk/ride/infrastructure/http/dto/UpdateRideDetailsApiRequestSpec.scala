package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.ride.domain.*
import zio.test.*

object UpdateRideDetailsApiRequestSpec extends ZIOSpecDefault {

  def spec =
    suite("UpdateRideDetailsApiRequest.toDomain")(
      // Regression: the edit dialog sends only flightNumber (never isAirportTransfer), so gating
      // specifics on isAirportTransfer == Some(true) silently dropped flight-number updates.
      test("builds AirportTransfer specifics from a flight number even without isAirportTransfer") {
        val request = UpdateRideDetailsApiRequest(flightNumber = Some("LH123"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(
          domain.specifics.exists {
            case RideSpecifics.AirportTransfer(_, flight, _) => flight == "LH123"
            case _                                           => false
          }
        )
      },
      test("leaves specifics None when no flight number is supplied") {
        val request = UpdateRideDetailsApiRequest(notes = Some("just a note"))
        val domain  = UpdateRideDetailsApiRequest.toDomain(request)
        assertTrue(domain.specifics.isEmpty)
      }
    )
}
