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
      pickupDateTime: String = futureDateTime,
      clientId: String = validClientId,
      isAirportTransfer: Boolean = false,
      flightNumber: Option[String] = None,
      price: Option[Double] = None
  ) = CreateRideApiRequest(
    clientId = clientId,
    creatorId = validClientId,
    pickupDateTime = pickupDateTime,
    from = from,
    to = to,
    clientName = "Test Client",
    isAirportTransfer = isAirportTransfer,
    flightNumber = flightNumber,
    price = price
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
        val req = validCreateRequest(pickupDateTime = pastDateTime)
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("past"))
        }
      },
      test("rejects invalid datetime format") {
        val req = validCreateRequest(pickupDateTime = "2024-13-45 bad")
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
      test("rejects airport transfer without flight number") {
        val req = validCreateRequest(isAirportTransfer = true, flightNumber = None)
        summon[Validator[CreateRideApiRequest]].validate(req).flip.map { err =>
          assertTrue(err.asInstanceOf[RideError.ValidationError].message.contains("Flight number"))
        }
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

  def spec =
    suite("RideValidators")(
      suite_createRideApiRequest,
      suite_assignDriverRequest,
      suite_rideStatusUpdateRequest,
      suite_updateRideApiRequest
    )
}
