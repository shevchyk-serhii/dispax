package com.shevchyk.ride.infrastructure.http.dto

import java.time.Instant
import java.util.UUID

import zio.test.*

import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId}
import com.shevchyk.ride.domain.{FlightStatusRow, Ride, RideSpecifics, RideStatus}

/**
 * Pins that `RideDto.fromDomain` surfaces the live flight columns (gate/terminal/status/time) when a caller passes the
 * loaded `FlightStatusRow`, and leaves them empty when it does not. This is what lets the dispatcher "My Rides"
 * endpoint show real MUC flight data — `getRidesByDriversServer` loads the rows in bulk and passes them here.
 *
 * Mutation: drop the `gate = flight.flatMap(_.gate)` (etc.) mapping, or stop passing `flight` from the endpoint, and
 * the "surfaces" case goes red.
 */
object RideDtoFlightSpec extends ZIOSpecDefault:

  private def airportRide: Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = PersonId(UUID.randomUUID()),
    creatorId = PersonId(UUID.randomUUID()),
    companyId = CompanyId(UUID.randomUUID()),
    status = RideStatus.Assigned,
    pickupLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    dropoffLocation = Location("MUC Airport", Some(48.3537), Some(11.7860)),
    pickupDateTime = Instant.parse("2026-06-26T08:00:00Z"),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH123", isArrival = true))
  )

  def spec =
    suite("RideDto.fromDomain flight columns")(
      test("surfaces gate/terminal/status/time from the passed FlightStatusRow") {
        val t   = Instant.parse("2026-06-26T09:00:00Z")
        val row = FlightStatusRow(Some("G35"), Some("T2"), Some("landed"), Some(t))
        val dto = RideDto.fromDomain(airportRide, flight = Some(row))
        assertTrue(
          dto.flightNumber.contains("LH123"),
          dto.isAirportTransfer,
          dto.gate.contains("G35"),
          dto.terminal.contains("T2"),
          dto.flightStatus.contains("landed"),
          dto.flightTime.contains(t.toString)
        )
      },
      test("leaves flight columns empty when no FlightStatusRow is passed") {
        val dto = RideDto.fromDomain(airportRide)
        assertTrue(
          dto.isAirportTransfer,
          dto.gate.isEmpty,
          dto.terminal.isEmpty,
          dto.flightStatus.isEmpty
        )
      }
    )
