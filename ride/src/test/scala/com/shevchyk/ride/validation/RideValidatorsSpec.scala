package com.shevchyk.ride.validation

import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.*
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

object RideValidatorsSpec extends ZIOSpecDefault {

  val validClientId  = UUID.randomUUID().toString
  val validDriverId  = UUID.randomUUID().toString
  val futureDateTime = Instant.now().plusSeconds(3600).toString
  val pastDateTime   = Instant.now().minusSeconds(3600).toString

  def validLocation(address: String = "Marienplatz 1, Munich") = LocationDto(address = address)

  def validCreateRequest(
      from: LocationDto = validLocation(),
      to: LocationDto = validLocation("Airport MUC"),
      pickupDateTime: Option[String] = Some(futureDateTime),
      clientId: String = validClientId,
      isAirportTransfer: Boolean = false,
      flightNumber: Option[String] = None,
      price: Option[Double] = None,
      tags: Option[List[String]] = None,
      provisionalClient: Boolean = false
  ) = CreateRideApiRequest(
    clientId = clientId,
    creatorId = validClientId,
    pickupDateTime = pickupDateTime,
    from = from,
    to = to,
    clientName = "Test Client",
    isAirportTransfer = isAirportTransfer,
    flightNumber = flightNumber,
    price = price,
    tags = tags,
    provisionalClient = provisionalClient
  )

  def suite_createRideApiRequest =
    suite("CreateRideApiRequest validator")(
      test("accepts valid request") {
        val req = validCreateRequest()
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects empty pickup address") {
        val req = validCreateRequest(from = LocationDto(address = ""))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError]) &&
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Pickup location"))
        }
      },
      test("rejects whitespace-only pickup address") {
        val req = validCreateRequest(from = LocationDto(address = "   "))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("rejects empty dropoff address") {
        val req = validCreateRequest(to = LocationDto(address = ""))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Dropoff location"))
        }
      },
      test("rejects past datetime") {
        val req = validCreateRequest(pickupDateTime = Some(pastDateTime))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("past"))
        }
      },
      test("rejects invalid datetime format") {
        val req = validCreateRequest(pickupDateTime = Some("2024-13-45 bad"))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid datetime"))
        }
      },
      test("rejects invalid client UUID") {
        val req = validCreateRequest(clientId = "not-a-uuid")
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid client ID"))
        }
      },
      // Provisional ("from-chat") mode: the client is created server-side, so an empty clientId must NOT
      // be rejected. Mutation: drop the `if provisionalClient then ZIO.unit` branch → this goes red.
      test("accepts a provisional request with an empty clientId") {
        val req = validCreateRequest(clientId = "", provisionalClient = true)
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("still rejects an empty clientId when NOT provisional") {
        val req = validCreateRequest(clientId = "", provisionalClient = false)
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid client ID"))
        }
      },
      test("accepts an airport transfer without a flight number (flight may be unknown at creation)") {
        val req = validCreateRequest(isAirportTransfer = true, flightNumber = None)
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts airport transfer with flight number") {
        val req = validCreateRequest(isAirportTransfer = true, flightNumber = Some("LH123"))
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects negative price") {
        val req = validCreateRequest(price = Some(-5.0))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("greater than zero"))
        }
      },
      test("rejects zero price") {
        val req = validCreateRequest(price = Some(0.0))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("greater than zero"))
        }
      },
      test("accepts None price") {
        val req = validCreateRequest(price = None)
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts valid coordinates") {
        val req = validCreateRequest(from =
          LocationDto(address = "A", latitude = Some(48.137), longitude = Some(11.575))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects out-of-range latitude") {
        val req = validCreateRequest(from = LocationDto(address = "A", latitude = Some(999.0), longitude = Some(11.5)))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("invalid coordinates"))
        }
      },
      test("rejects out-of-range longitude") {
        val req = validCreateRequest(to = LocationDto(address = "B", latitude = Some(48.1), longitude = Some(-181.0)))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("invalid coordinates"))
        }
      },
      test("rejects NaN coordinates") {
        val req = validCreateRequest(from =
          LocationDto(address = "A", latitude = Some(Double.NaN), longitude = Some(11.5))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("accepts a valid tag list") {
        val req = validCreateRequest(tags = Some(List("Urgent", "Cash")))
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects more than 15 tags") {
        val req = validCreateRequest(tags = Some((1 to 16).map(i => s"tag$i").toList))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("At most 15 tags"))
        }
      },
      test("rejects a tag longer than 30 chars") {
        val req = validCreateRequest(tags = Some(List("x" * 31)))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("at most 30 characters"))
        }
      },
      test("rejects a blank-only tag") {
        val req = validCreateRequest(tags = Some(List("   ")))
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Tags cannot be blank"))
        }
      }
    )

  def suite_updateRideDetailsApiRequest =
    suite("UpdateRideDetailsApiRequest validator")(
      test("accepts None tags (unchanged)") {
        val req = UpdateRideDetailsApiRequest()
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts a valid tag list") {
        val req = UpdateRideDetailsApiRequest(tags = Some(List("Urgent")))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects more than 15 tags") {
        val req = UpdateRideDetailsApiRequest(tags = Some((1 to 16).map(i => s"tag$i").toList))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("At most 15 tags"))
        }
      },
      test("rejects a blank-only tag") {
        val req = UpdateRideDetailsApiRequest(tags = Some(List("  ")))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Tags cannot be blank"))
        }
      },
      test("accepts an absent clientId (no reassignment)") {
        val req = UpdateRideDetailsApiRequest(notes = Some("just a note"))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts a valid client UUID") {
        val req = UpdateRideDetailsApiRequest(clientId = Some("00000064-0000-0000-0000-000000000100"))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts a client UUID with surrounding whitespace (trimmed)") {
        val req = UpdateRideDetailsApiRequest(clientId = Some("  00000064-0000-0000-0000-000000000100  "))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects a malformed client UUID") {
        val req = UpdateRideDetailsApiRequest(clientId = Some("not-a-uuid"))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid client ID"))
        }
      },
      test("rejects an empty clientId string") {
        val req = UpdateRideDetailsApiRequest(clientId = Some(""))
        summon[Validator[UpdateRideDetailsApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      }
    )

  def suite_assignDriverRequest =
    suite("AssignDriverRequest validator")(
      test("accepts valid driver UUID") {
        val req = AssignDriverRequest(driverId = validDriverId)
        summon[Validator[AssignDriverRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects invalid driver UUID") {
        val req = AssignDriverRequest(driverId = "bad-uuid")
        summon[Validator[AssignDriverRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid driver ID"))
        }
      },
      test("rejects empty string as driver ID") {
        val req = AssignDriverRequest(driverId = "")
        summon[Validator[AssignDriverRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      }
    )

  def suite_rideStatusUpdateRequest =
    suite("RideStatusUpdateRequest validator")(
      test("accepts Requested") {
        val req = RideStatusUpdateRequest(status = "Requested")
        summon[Validator[RideStatusUpdateRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts Assigned") {
        val req = RideStatusUpdateRequest(status = "Assigned")
        summon[Validator[RideStatusUpdateRequest]].validate(req).map(r => assertTrue(r.status == "Assigned"))
      },
      test("accepts InProgress") {
        val req = RideStatusUpdateRequest(status = "InProgress")
        summon[Validator[RideStatusUpdateRequest]].validate(req).map(r => assertTrue(r.status == "InProgress"))
      },
      test("accepts Completed") {
        val req = RideStatusUpdateRequest(status = "Completed")
        summon[Validator[RideStatusUpdateRequest]].validate(req).map(r => assertTrue(r.status == "Completed"))
      },
      test("accepts Cancelled") {
        val req = RideStatusUpdateRequest(status = "Cancelled")
        summon[Validator[RideStatusUpdateRequest]].validate(req).map(r => assertTrue(r.status == "Cancelled"))
      },
      test("rejects unknown status") {
        val req = RideStatusUpdateRequest(status = "Flying")
        summon[Validator[RideStatusUpdateRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Invalid ride status"))
        }
      },
      test("rejects lowercase status") {
        val req = RideStatusUpdateRequest(status = "completed")
        summon[Validator[RideStatusUpdateRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      }
    )

  def suite_updateRideApiRequest =
    suite("UpdateRideApiRequest validator")(
      test("accepts empty update (all None)") {
        val req = UpdateRideApiRequest()
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts valid client UUID") {
        val req = UpdateRideApiRequest(clientId = Some(validClientId))
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects invalid client UUID") {
        val req = UpdateRideApiRequest(clientId = Some("not-a-uuid"))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("rejects empty pickup location") {
        val req = UpdateRideApiRequest(pickupLocation = Some(""))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Pickup location"))
        }
      },
      test("rejects whitespace destination") {
        val req = UpdateRideApiRequest(destination = Some("  "))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Destination"))
        }
      },
      test("rejects invalid pickup time format") {
        val req = UpdateRideApiRequest(pickupTime = Some("not-a-date"))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("accepts valid ISO pickup time") {
        val req = UpdateRideApiRequest(pickupTime = Some(futureDateTime))
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects invalid status") {
        val req = UpdateRideApiRequest(status = Some("INVALID"))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("accepts valid status") {
        val req = UpdateRideApiRequest(status = Some("Completed"))
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects passenger count of 0") {
        val req = UpdateRideApiRequest(passengerCount = Some(0))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("between 1 and 8"))
        }
      },
      test("rejects passenger count of 9") {
        val req = UpdateRideApiRequest(passengerCount = Some(9))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("between 1 and 8"))
        }
      },
      test("accepts passenger count of 1") {
        val req = UpdateRideApiRequest(passengerCount = Some(1))
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts passenger count of 8") {
        val req = UpdateRideApiRequest(passengerCount = Some(8))
        summon[Validator[UpdateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects negative passenger count") {
        val req = UpdateRideApiRequest(passengerCount = Some(-1))
        summon[Validator[UpdateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      }
    )

  def suite_cancelRideApiRequest =
    suite("CancelRideApiRequest validator")(
      test("accepts None fee") {
        val req = CancelRideApiRequest(reason = "client_request")
        summon[Validator[CancelRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts zero fee (free cancellation)") {
        val req = CancelRideApiRequest(reason = "client_request", fee = Some(0.0))
        summon[Validator[CancelRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("accepts positive fee") {
        val req = CancelRideApiRequest(reason = "client_no_show", fee = Some(25.0))
        summon[Validator[CancelRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("rejects negative fee") {
        val req = CancelRideApiRequest(reason = "client_no_show", fee = Some(-100.0))
        summon[Validator[CancelRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("negative"))
        }
      },
      // [MEDIUM] fee guard `fee.exists(f => f.isNaN || f < 0)`: removing isNaN allows NaN to slip through.
      // NaN is neither < 0 nor >= 0, so the `f < 0` branch alone would not catch it.
      test("rejects NaN fee (isNaN guard is distinct from negative guard)") {
        val req = CancelRideApiRequest(reason = "client_no_show", fee = Some(Double.NaN))
        summon[Validator[CancelRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      // [HIGH] unknown reason is rejected: CancellationReason.fromString returns None for free-text values.
      test("rejects unknown cancellation reason") {
        val req = CancelRideApiRequest(reason = "No show")
        summon[Validator[CancelRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Unknown cancellation reason"))
        }
      }
    )

  // [LOW] coordinate boundary tests: inclusive limits (±90 lat, ±180 lon) must be valid;
  // values just beyond the boundary must be rejected.  These close the <= vs < mutation gap.
  def suite_coordinateBoundaries =
    suite("Coordinate boundary values")(
      test("latitude 90.0 is valid (inclusive upper bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "North Pole", latitude = Some(90.0), longitude = Some(0.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("latitude -90.0 is valid (inclusive lower bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "South Pole", latitude = Some(-90.0), longitude = Some(0.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("longitude 180.0 is valid (inclusive upper bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Date line", latitude = Some(0.0), longitude = Some(180.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("longitude -180.0 is valid (inclusive lower bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Date line W", latitude = Some(0.0), longitude = Some(-180.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).map(r => assertTrue(r == req))
      },
      test("latitude 90.001 is invalid (just above upper bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Over North", latitude = Some(90.001), longitude = Some(0.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("latitude -90.001 is invalid (just below lower bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Over South", latitude = Some(-90.001), longitude = Some(0.0))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("longitude 180.001 is invalid (just above upper bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Over Date", latitude = Some(0.0), longitude = Some(180.001))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      },
      test("longitude -180.001 is invalid (just below lower bound)") {
        val req = validCreateRequest(from =
          LocationDto(address = "Over Date W", latitude = Some(0.0), longitude = Some(-180.001))
        )
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.isInstanceOf[RideError.ValidationError])
        }
      }
    )

  def suite_createRideApiRequestMapping =
    suite("CreateRideApiRequest.toDomain")(
      test("carries the supplied price into estimatedPrice (Double → BigDecimal)") {
        val req = validCreateRequest(price = Some(42.5))
        CreateRideApiRequest
          .toDomain(req, com.shevchyk.core.domain.CompanyId.generate())
          .map(domain => assertTrue(domain.estimatedPrice.contains(BigDecimal(42.5))))
      },
      test("leaves estimatedPrice None when no price is supplied") {
        val req = validCreateRequest(price = None)
        CreateRideApiRequest
          .toDomain(req, com.shevchyk.core.domain.CompanyId.generate())
          .map(domain => assertTrue(domain.estimatedPrice.isEmpty))
      },
      test("normalizes tags (trim, collapse, case-insensitive de-dup)") {
        val req = validCreateRequest(tags = Some(List("  Urgent ", "urgent", "Cash   Only")))
        CreateRideApiRequest
          .toDomain(req, com.shevchyk.core.domain.CompanyId.generate())
          .map(domain => assertTrue(domain.tags == List("Urgent", "Cash Only")))
      },
      test("absent tags become an empty list") {
        val req = validCreateRequest(tags = None)
        CreateRideApiRequest
          .toDomain(req, com.shevchyk.core.domain.CompanyId.generate())
          .map(domain => assertTrue(domain.tags == Nil))
      }
    )

  def suite_updateRideDetailsApiRequestMapping =
    suite("UpdateRideDetailsApiRequest.toDomain")(
      test("normalizes tags when present") {
        val req    = UpdateRideDetailsApiRequest(tags = Some(List("  VIP ", "vip")))
        val domain = UpdateRideDetailsApiRequest.toDomain(req)
        assertTrue(domain.tags.contains(List("VIP")))
      },
      test("preserves None tags as unchanged") {
        val req    = UpdateRideDetailsApiRequest(tags = None)
        val domain = UpdateRideDetailsApiRequest.toDomain(req)
        assertTrue(domain.tags.isEmpty)
      }
    )

  def spec =
    suite("RideValidators")(
      suite_createRideApiRequest,
      suite_createRideApiRequestMapping,
      suite_updateRideDetailsApiRequest,
      suite_updateRideDetailsApiRequestMapping,
      suite_assignDriverRequest,
      suite_rideStatusUpdateRequest,
      suite_updateRideApiRequest,
      suite_cancelRideApiRequest,
      suite_coordinateBoundaries
    )
}
