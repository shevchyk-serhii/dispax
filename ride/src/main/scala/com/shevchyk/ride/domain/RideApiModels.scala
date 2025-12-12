package com.shevchyk.ride.domain

import zio.json.*
import java.time.Instant

// Frontend-compatible DTOs

case class RideDto(
    id: Long,
    clientId: Long,
    driverId: Option[Long] = None,
    status: String,
    pickupLocation: String,
    destination: String,
    pickupTime: String,
    passengerCount: Option[Int] = None,
    flightNumber: Option[String] = None,
    specialRequirements: Option[String] = None,
    createdAt: Option[String] = None,
    updatedAt: Option[String] = None
) derives JsonCodec

case class CreateRideApiRequest(
    clientId: Long,
    pickupLocation: String,
    destination: String,
    pickupTime: String,
    status: String = "REQUESTED",
    passengerCount: Option[Int] = None,
    flightNumber: Option[String] = None,
    specialRequirements: Option[String] = None
) derives JsonCodec

case class UpdateRideApiRequest(
    clientId: Option[Long] = None,
    pickupLocation: Option[String] = None,
    destination: Option[String] = None,
    pickupTime: Option[String] = None,
    status: Option[String] = None,
    passengerCount: Option[Int] = None,
    flightNumber: Option[String] = None,
    specialRequirements: Option[String] = None
) derives JsonCodec

case class RideStatusUpdateRequest(
    status: String
) derives JsonCodec

case class RideStatusUpdateResponse(
    success: Boolean,
    status: String
) derives JsonCodec

case class AssignDriverRequest(
    driverId: Long
) derives JsonCodec

case class ValidationErrorsResponse(
    errors: List[ValidationFieldError]
) derives JsonCodec

case class ValidationFieldError(
    field: String,
    message: String
) derives JsonCodec

// Conversion helpers
object RideDto:

  def fromDomain(ride: Ride): RideDto = RideDto(
    id = ride.id.value,
    clientId = ride.clientId.value,
    driverId = ride.driverId.map(_.value),
    status = ride.status.toString.toUpperCase,
    pickupLocation = ride.pickupLocation.display,
    destination = ride.dropoffLocation.display,
    pickupTime = ride.scheduledTime.getOrElse(ride.requestTime).toString,
    passengerCount = Some(1), // Default for now
    flightNumber = ride.flightNumber,
    specialRequirements = ride.notes,
    createdAt = Some(ride.requestTime.toString),
    updatedAt = None
  )
