package com.shevchyk.ride.domain

import com.shevchyk.core.domain.Location
import zio.json.*
import java.time.Instant

// Frontend-compatible DTOs

case class LocationDto(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec

case class RideDto(
    id: Long,
    clientId: Long,
    creatorId: Long,
    driverId: Option[Long] = None,
    companyId: Long,
    scheduleDayId: Option[Long] = None,
    pickupDateTime: String,
    from: LocationDto,
    to: LocationDto,
    status: String,
    clientName: String,
    flightNumber: Option[String] = None,
    flightTime: Option[String] = None,
    isAirportTransfer: Boolean = false,
    isArrival: Boolean = false,
    gate: Option[String] = None,
    terminal: Option[String] = None,
    flightStatus: Option[String] = None,
    driverName: Option[String] = None,
    driverLocation: Option[LocationDto] = None,
    price: Option[Double] = None
) derives JsonCodec

case class CreateRideApiRequest(
    clientId: Long,
    creatorId: Long,
    companyId: Long,
    scheduleDayId: Option[Long] = None,
    pickupDateTime: String,
    from: LocationDto,
    to: LocationDto,
    status: String = "requested",
    clientName: String,
    flightNumber: Option[String] = None,
    flightTime: Option[String] = None,
    isAirportTransfer: Boolean = false,
    isArrival: Boolean = false,
    gate: Option[String] = None,
    terminal: Option[String] = None,
    price: Option[Double] = None
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
object LocationDto:

  def fromDomain(location: Location): LocationDto = LocationDto(
    address = location.address,
    latitude = location.latitude,
    longitude = location.longitude
  )

  def toDomain(dto: LocationDto): Location = Location(
    address = dto.address,
    latitude = dto.latitude,
    longitude = dto.longitude
  )

object RideDto:

  def fromDomain(ride: Ride): RideDto = RideDto(
    id = ride.id.value,
    clientId = ride.clientId.value,
    creatorId = ride.creatorId.value,
    driverId = ride.driverId.map(_.value),
    companyId = ride.companyId.value,
    scheduleDayId = None,                   // Not used in current domain model
    pickupDateTime = ride.scheduledTime.getOrElse(ride.requestTime).toString,
    from = LocationDto.fromDomain(ride.pickupLocation),
    to = LocationDto.fromDomain(ride.dropoffLocation),
    status = ride.status.toString,
    clientName = "Unknown Client",          // Would need to be fetched from PersonRepository
    flightNumber = ride.flightNumber,
    flightTime = ride.scheduledTime.map(_.toString),
    isAirportTransfer = ride.isAirportTransfer,
    isArrival = ride.airportCode.isDefined, // Simple heuristic
    gate = None,                            // Would need additional data
    terminal = None,                        // Would need additional data
    flightStatus = None,                    // Would need flight service integration
    driverName = None,                      // Would need to be fetched from PersonRepository
    driverLocation = None,                  // Would need driver location service
    price = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue)
  )

object CreateRideApiRequest:

  def toDomain(request: CreateRideApiRequest): CreateRideRequest = CreateRideRequest(
    clientId = com.shevchyk.core.domain.PersonId(request.clientId),
    pickupLocation = LocationDto.toDomain(request.from),
    dropoffLocation = LocationDto.toDomain(request.to),
    scheduledTime = scala.util.Try(Instant.parse(request.pickupDateTime)).toOption,
    notes = None,
    airportCode = None, // Could be extracted from location or flight number
    flightNumber = request.flightNumber,
    isAirportTransfer = request.isAirportTransfer
  )
