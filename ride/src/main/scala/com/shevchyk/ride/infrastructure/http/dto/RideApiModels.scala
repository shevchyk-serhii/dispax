package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.core.domain.{Location, RideId, PersonId, CompanyId}
import com.shevchyk.ride.domain.{Ride, CreateRideRequest, RideSpecifics, RideStatus}
import zio.json.*
import java.time.Instant
import java.util.UUID

given JsonCodec[RideStatus] = JsonCodec.string.transform(
  str => RideStatus.valueOf(str),
  status => status.toString
)

case class LocationDto(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec

case class RideDto(
    id: String,
    clientId: String,
    creatorId: String,
    driverId: Option[String] = None,
    scheduleDayId: Option[String] = None,
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
    clientId: String,
    creatorId: String,
    scheduleDayId: Option[String] = None,
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
    clientId: Option[String] = None,
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
    driverId: String
) derives JsonCodec

case class ValidationErrorsResponse(
    errors: List[ValidationFieldError]
) derives JsonCodec

case class ValidationFieldError(
    field: String,
    message: String
) derives JsonCodec

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

  def fromDomain(ride: Ride): RideDto =
    val (flightNumber, isAirportTransfer) =
      ride.specifics match {
        case Some(RideSpecifics.AirportTransfer(_, flight)) => (Some(flight), true)
        case None                                           => (None, false)
      }

    RideDto(
      id = ride.id.value.toString,
      clientId = ride.clientId.value.toString,
      creatorId = ride.creatorId.value.toString,
      driverId = ride.driverId.map(_.value.toString),
      scheduleDayId = None,               // Not used in current domain model
      pickupDateTime = ride.scheduledTime.getOrElse(ride.requestTime).toString,
      from = LocationDto.fromDomain(ride.pickupLocation),
      to = LocationDto.fromDomain(ride.dropoffLocation),
      status = ride.status.toString,
      clientName = "Unknown Client",      // Would need to be fetched from PersonRepository
      flightNumber = flightNumber,
      flightTime = ride.scheduledTime.map(_.toString),
      isAirportTransfer = isAirportTransfer,
      isArrival = flightNumber.isDefined, // Simple heuristic
      gate = None,                        // Would need additional data
      terminal = None,                    // Would need additional data
      flightStatus = None,                // Would need flight service integration
      driverName = None,                  // Would need to be fetched from PersonRepository
      driverLocation = None,              // Would need driver location service
      price = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue)
    )

object CreateRideApiRequest:

  def toDomain(request: CreateRideApiRequest): CreateRideRequest =
    // Create AirportTransfer if either isAirportTransfer is true OR flightNumber is provided
    val specifics =
      if (request.isAirportTransfer || request.flightNumber.isDefined) {
        request.flightNumber.map { flight =>
          RideSpecifics.AirportTransfer(
            airportCode = extractAirportCode(request), // Could be extracted from location
            flightNumber = flight
          )
        }
      }
      else {
        None
      }

    CreateRideRequest(
      clientId = PersonId(UUID.fromString(request.clientId)),
      pickupLocation = LocationDto.toDomain(request.from),
      dropoffLocation = LocationDto.toDomain(request.to),
      scheduledTime = scala.util.Try(Instant.parse(request.pickupDateTime)).toOption,
      notes = None,
      specifics = specifics
    )

  private def extractAirportCode(request: CreateRideApiRequest): String =
    // Simple heuristic: try to extract from address
    // In real implementation, could use airport database or user input
    val address = request.from.address
    if (address.toLowerCase.contains("munich"))
      "MUC"
    else if (address.toLowerCase.contains("frankfurt"))
      "FRA"
    else if (address.toLowerCase.contains("berlin"))
      "BER"
    else
      "UNKNOWN"
