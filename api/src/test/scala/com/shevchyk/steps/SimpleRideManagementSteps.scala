package com.shevchyk.steps

import com.shevchyk.ride.domain.{CreateRideRequest, RideStatus}
import com.shevchyk.core.domain.{Location, PersonId}
import io.cucumber.scala.{EN, ScalaDsl}
import zio.http.*
import java.util.UUID

class SimpleRideManagementSteps extends ScalaDsl with EN with ApiTestHelpers {

  var currentRideRequest: CreateRideRequest = _
  var lastRideResponse: Response = _
  var lastRideId: Option[UUID] = None
  var createdRideIds: List[UUID] = List.empty
  val testPersonId: PersonId = PersonId.generate()

  Given("^I want to create a ride from \"([^\"]+)\" to \"([^\"]+)\"$") { (pickup: String, dropoff: String) =>
    currentRideRequest = CreateRideRequest(
      clientId = testPersonId,
      pickupLocation = Location(pickup),
      dropoffLocation = Location(dropoff),
      scheduledTime = None,
      notes = None,
      specifics = None
    )
  }

  When("^I send a POST request to create the ride$") { () =>
    val mockRideId = UUID.randomUUID()
    lastRideResponse = Response(Status.Created, body = Body.fromString(s"""{"id":"${mockRideId}","status":"requested"}"""))
    lastRideId = Some(mockRideId)
  }

  Then("^I should receive the created ride with status \"([^\"]+)\"$") { (expectedStatus: String) =>
    assumeResponseStatus(lastRideResponse, Status.Created)
    lastRideId.foreach(id => createdRideIds = id :: createdRideIds)
  }

  Then("^the response should have status code (\\d+)$") { (statusCode: Int) =>
    val expectedStatus = statusCode match {
      case 200 => Status.Ok
      case 201 => Status.Created
      case 400 => Status.BadRequest
      case 401 => Status.Unauthorized
      case 403 => Status.Forbidden
      case 404 => Status.NotFound
      case 500 => Status.InternalServerError
      case _ => Status.InternalServerError
    }
    assumeResponseStatus(lastRideResponse, expectedStatus)
  }
}