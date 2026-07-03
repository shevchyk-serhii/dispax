package com.shevchyk.ride.infrastructure.http.dto

import java.time.Instant
import java.util.UUID

import zio.test.*

import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId}
import com.shevchyk.ride.domain.{Ride, RideStatus}

/**
 * Pins that `RideDto.fromDomain` surfaces the ride's booking reference so clients can display the human-readable id,
 * and leaves it None for legacy rides that predate the column.
 *
 * Mutation: drop the `bookingReference = ride.bookingReference` mapping and the first case goes red.
 */
object RideDtoBookingReferenceSpec extends ZIOSpecDefault:

  private def ride(reference: Option[String]): Ride = Ride(
    id = RideId(UUID.randomUUID()),
    clientId = PersonId(UUID.randomUUID()),
    creatorId = PersonId(UUID.randomUUID()),
    companyId = CompanyId(UUID.randomUUID()),
    status = RideStatus.Requested,
    pickupLocation = Location("Marienplatz", Some(48.1374), Some(11.5755)),
    dropoffLocation = Location("MUC Airport", Some(48.3537), Some(11.7860)),
    pickupDateTime = Instant.parse("2026-07-03T08:00:00Z"),
    bookingReference = reference
  )

  def spec =
    suite("RideDto.fromDomain booking reference")(
      test("surfaces the booking reference when the ride has one") {
        val dto = RideDto.fromDomain(ride(Some("R-2026-00007")))
        assertTrue(dto.bookingReference.contains("R-2026-00007"))
      },
      test("leaves the booking reference empty for legacy rides") {
        val dto = RideDto.fromDomain(ride(None))
        assertTrue(dto.bookingReference.isEmpty)
      }
    )
