package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object RideDomainSpec extends ZIOSpecDefault {

  def spec =
    suite("RideDomain")(
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
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("Airport Terminal 1"),
            dropoffLocation = Location("City Center"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(ride.status == RideStatus.Requested)
        },
        test("bookingReferenceOrId returns the reference when allocated") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("Airport Terminal 1"),
            dropoffLocation = Location("City Center"),
            pickupDateTime = Instant.now().plusSeconds(3600),
            bookingReference = Some("R-2026-00123")
          )
          assertTrue(ride.bookingReferenceOrId == "R-2026-00123")
        },
        test("bookingReferenceOrId falls back to the ride UUID for legacy rides") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("Airport Terminal 1"),
            dropoffLocation = Location("City Center"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(ride.bookingReferenceOrId == "11111111-1111-1111-1111-111111111111")
        },
        test("should validate business rules") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            status = RideStatus.Requested,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
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
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
            status = RideStatus.Assigned,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )

          // Assigned: driver must confirm first — canBeStarted now requires Confirmed status
          assertTrue(
            !assignedRide.canBeAssigned &&
              !assignedRide.canBeStarted &&
              !assignedRide.canBeCompleted
          )
        },
        test("should handle in-progress status correctly") {
          val inProgressRide = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
            status = RideStatus.InProgress,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
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
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("Airport"),
            dropoffLocation = Location("Hotel"),
            scheduledTime = Some(Instant.now().plusSeconds(3600)),
            notes = Some("Terminal 2"),
            specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH123")))
          )

          assertTrue(
            request.clientId == PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")) &&
              request.specifics.isDefined &&
              request.notes.contains("Terminal 2")
          )
        }
      ),
      suite("RideError")(
        test("should create validation error") {
          val error = RideError.ValidationError("Invalid pickup location")
          assertTrue(error match {
            case RideError.ValidationError(message) => message == "Invalid pickup location"
            case _                                  => false
          })
        },
        test("should create ride not found error") {
          val error = RideError.RideNotFound(RideId(UUID.fromString("000003e7-0000-0000-0000-000000000999")))
          assertTrue(error match {
            case RideError.RideNotFound(id) => id == RideId(UUID.fromString("000003e7-0000-0000-0000-000000000999"))
            case _                          => false
          })
        }
      ),
      suite("Ride state matrix")(
        test(
          "Requested: canBeAssigned=true, canBeReassigned=false, canBeStarted=false, canBeCompleted=false, canBeCancelled=true, canBeEdited=true"
        ) {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            status = RideStatus.Requested,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(
            ride.canBeAssigned &&
              !ride.canBeReassigned &&
              !ride.canBeStarted &&
              !ride.canBeCompleted &&
              ride.canBeCancelled &&
              ride.canBeEdited
          )
        },
        test("Assigned with driver: canBeStarted=false (must confirm first), other predicates verified") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
            status = RideStatus.Assigned,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          // canBeStarted is false for Assigned: driver must go through Confirmed first
          assertTrue(
            !ride.canBeAssigned &&
              ride.canBeReassigned &&
              !ride.canBeStarted &&
              !ride.canBeCompleted &&
              ride.canBeCancelled &&
              ride.canBeEdited
          )
        },
        test("InProgress: canBeCancelled=true, canBeCompleted=true, canBeEdited=false") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
            status = RideStatus.InProgress,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(
            !ride.canBeAssigned &&
              !ride.canBeReassigned &&
              !ride.canBeStarted &&
              ride.canBeCompleted &&
              ride.canBeCancelled &&
              !ride.canBeEdited
          )
        },
        test("Completed: all false") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            driverId = Some(PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200"))),
            status = RideStatus.Completed,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(
            !ride.canBeAssigned &&
              !ride.canBeReassigned &&
              !ride.canBeStarted &&
              !ride.canBeCompleted &&
              !ride.canBeCancelled &&
              !ride.canBeEdited
          )
        },
        test("Cancelled: all false") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            status = RideStatus.Cancelled,
            pickupLocation = Location("Start"),
            dropoffLocation = Location("End"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(
            !ride.canBeAssigned &&
              !ride.canBeReassigned &&
              !ride.canBeStarted &&
              !ride.canBeCompleted &&
              !ride.canBeCancelled &&
              !ride.canBeEdited
          )
        },
        test("isAirportTransfer true when specifics is AirportTransfer") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("Airport"),
            dropoffLocation = Location("Hotel"),
            pickupDateTime = Instant.now().plusSeconds(3600),
            specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH123")))
          )
          assertTrue(ride.isAirportTransfer)
        },
        test("isAirportTransfer false when no specifics") {
          val ride = Ride(
            id = RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
            clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            creatorId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
            companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001")),
            pickupLocation = Location("A"),
            dropoffLocation = Location("B"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          assertTrue(!ride.isAirportTransfer)
        }
      )
    )
}
