package com.shevchyk.ride.helpers

import com.shevchyk.core.domain.{PersonId, CompanyId, Location, RideId, Person, PersonRole}
import com.shevchyk.ride.domain.{Ride, RideSpecifics, RideStatus, CreateRideRequest}
import java.time.Instant
import java.util.UUID

object TestData {

  def testUserId: UUID    = UUID.fromString("00000000-0000-0000-0000-000000000001")
  def testCompanyId: UUID = UUID.fromString("00000000-0000-0000-0000-000000000010")
  def testDriverId: UUID  = UUID.fromString("00000000-0000-0000-0000-000000000002")

  def createTestClient(
      id: PersonId = PersonId(testUserId),
      companyId: CompanyId = CompanyId(testCompanyId)
  ): Person = Person(
    id = id,
    name = "Test Client",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(companyId),
    phone = Some("+1234567890")
  )

  def createRideRequest(
      pickupAddress: String = "Munich Airport",
      dropoffAddress: String = "Berlin Central Station",
      scheduledTime: Option[Instant] = None,
      specifics: Option[RideSpecifics] = None
  ): CreateRideRequest = CreateRideRequest(
    clientId = PersonId(testUserId),
    companyId = CompanyId(testCompanyId),
    pickupLocation = Location(pickupAddress),
    dropoffLocation = Location(dropoffAddress),
    scheduledTime = scheduledTime,
    specifics = specifics,
    notes = Some("Test ride")
  )

  def createAirportRideRequest(
      airportCode: String = "MUC",
      flightNumber: String = "LH123"
  ): CreateRideRequest = createRideRequest(
    specifics = Some(RideSpecifics.AirportTransfer(airportCode, flightNumber))
  )

  def createRide(
      id: RideId = RideId.generate(),
      clientId: PersonId = PersonId(testUserId),
      companyId: CompanyId = CompanyId(testCompanyId),
      status: RideStatus = RideStatus.Requested,
      pickupLocation: Location = Location("Munich Airport"),
      dropoffLocation: Location = Location("Berlin Central Station"),
      specifics: Option[RideSpecifics] = None
  ): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = None,
    status = status,
    pickupLocation = pickupLocation,
    dropoffLocation = dropoffLocation,
    pickupDateTime = Instant.now().plusSeconds(3600),
    scheduledTime = None,
    requestTime = Instant.now(),
    estimatedPrice = Some(BigDecimal(50.0)),
    notes = Some("Test ride"),
    specifics = specifics
  )

  def createAirportRide(
      airportCode: String = "MUC",
      flightNumber: String = "LH123"
  ): Ride = createRide(
    specifics = Some(RideSpecifics.AirportTransfer(airportCode, flightNumber))
  )

  def validCreateRideJson: String = {
    val futureTime = java.time.Instant.now().plusSeconds(3600).toString
    s"""{
      "clientId": "00000000-0000-0000-0000-000000000001",
      "creatorId": "00000000-0000-0000-0000-000000000001",
      "pickupDateTime": "$futureTime",
      "from": {"address": "Munich Airport"},
      "to": {"address": "Berlin Central Station"},
      "clientName": "Test User",
      "isAirportTransfer": false
    }"""
  }

  val invalidCreateRideJson: String = """{
      "pickupLocation": {"address": ""},
      "dropoffLocation": {"address": ""}
    }"""
}
