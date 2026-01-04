package com.shevchyk.ride.helpers

import com.shevchyk.core.domain.{PersonId, CompanyId, Location, RideId, Person, PersonRole}
import com.shevchyk.ride.domain.{Ride, RideStatus, CreateRideRequest}
import java.time.Instant
import java.util.UUID

object TestData {

  def testUserId: UUID = UUID.fromString("00000000-0000-0000-0000-000000000001")
  def testCompanyId: UUID = UUID.fromString("00000000-0000-0000-0000-000000000010")
  def testDriverId: UUID = UUID.fromString("00000000-0000-0000-0000-000000000002")

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
      isAirportTransfer: Boolean = false,
      flightNumber: Option[String] = None
  ): CreateRideRequest = CreateRideRequest(
    clientId = PersonId(testUserId),
    pickupLocation = Location(pickupAddress),
    dropoffLocation = Location(dropoffAddress),
    scheduledTime = scheduledTime,
    isAirportTransfer = isAirportTransfer,
    flightNumber = flightNumber,
    notes = Some("Test ride")
  )

  def createRide(
      id: RideId = RideId.generate(),
      clientId: PersonId = PersonId(testUserId),
      status: RideStatus = RideStatus.Requested,
      pickupLocation: Location = Location("Munich Airport"),
      dropoffLocation: Location = Location("Berlin Central Station")
  ): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = clientId,
    driverId = None,
    status = status,
    pickupLocation = pickupLocation,
    dropoffLocation = dropoffLocation,
    scheduledTime = Some(Instant.now().plusSeconds(3600)),
    requestTime = Instant.now(),
    startTime = None,
    endTime = None,
    tariffId = None,
    estimatedPrice = Some(BigDecimal(50.0)),
    finalPrice = None,
    notes = Some("Test ride"),
    airportCode = None,
    flightNumber = None,
    isAirportTransfer = false
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

  val invalidCreateRideJson: String =
    """{
      "pickupLocation": {"address": ""},
      "dropoffLocation": {"address": ""}
    }"""
}
