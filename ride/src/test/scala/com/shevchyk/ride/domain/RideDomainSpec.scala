package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object RideDomainSpec extends ZIOSpecDefault {

  def spec = suite("RideDomain")(
    suite("RideStatus")(
      test("should have correct status progression") {
        assertTrue(
          RideStatus.Requested.ordinal < RideStatus.Assigned.ordinal &&
          RideStatus.Assigned.ordinal < RideStatus.InProgress.ordinal &&
          RideStatus.InProgress.ordinal < RideStatus.Completed.ordinal
        )
      }
    ),

    suite("Ride")(
      test("should create ride with default status") {
        val ride = Ride(
          id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          companyId = CompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          pickupLocation = Location("Airport Terminal 1"),
          dropoffLocation = Location("City Center")
        )
        assertTrue(ride.status == RideStatus.Requested)
      },

      test("should validate business rules") {
        val ride = Ride(
          id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          companyId = CompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          status = RideStatus.Requested,
          pickupLocation = Location("Start"),
          dropoffLocation = Location("End")
        )

        assertTrue(
          ride.canBeAssigned &&
          !ride.canBeStarted &&
          !ride.canBeCompleted
        )
      },

      test("should handle assigned status correctly") {
        val assignedRide = Ride(
          id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
          companyId = CompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          status = RideStatus.Assigned,
          pickupLocation = Location("Start"),
          dropoffLocation = Location("End")
        )

        assertTrue(
          !assignedRide.canBeAssigned &&
          assignedRide.canBeStarted &&
          !assignedRide.canBeCompleted
        )
      },

      test("should handle in-progress status correctly") {
        val inProgressRide = Ride(
          id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
          companyId = CompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
          status = RideStatus.InProgress,
          pickupLocation = Location("Start"),
          dropoffLocation = Location("End")
        )

        assertTrue(
          !inProgressRide.canBeAssigned &&
          !inProgressRide.canBeStarted &&
          inProgressRide.canBeCompleted
        )
      }
    ),

    suite("CreateRideRequest")(
      test("should create valid request") {
        val request = CreateRideRequest(
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          pickupLocation = Location("Airport"),
          dropoffLocation = Location("Hotel"),
          scheduledTime = Some(Instant.now().plusSeconds(3600)),
          notes = Some("Terminal 2"),
          isAirportTransfer = true
        )

        assertTrue(
          request.clientId == PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")) &&
          request.isAirportTransfer &&
          request.notes.contains("Terminal 2")
        )
      }
    ),

    suite("RideError")(
      test("should create validation error") {
        val error = RideError.ValidationError("Invalid pickup location")
        assertTrue(error match {
          case RideError.ValidationError(message) => message == "Invalid pickup location"
          case _ => false
        })
      },

      test("should create ride not found error") {
        val error = RideError.RideNotFound(RideId(UUID.fromString("000003e7-0000-0000-0000-000000000999")))
        assertTrue(error match {
          case RideError.RideNotFound(id) => id == RideId(UUID.fromString("000003e7-0000-0000-0000-000000000999"))
          case _ => false
        })
      }
    )
  )
}