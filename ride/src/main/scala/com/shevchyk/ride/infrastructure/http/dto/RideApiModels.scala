package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.domain.{Location, RideId, PersonId, CompanyId, RidePoolId}
import com.shevchyk.ride.domain.{
  Ride,
  CreateRideRequest,
  RideSpecifics,
  RideStatus,
  PaymentStatus,
  PaymentMethod,
  UpdateRideDetailsRequest
}
import zio.*
import zio.http.*
import zio.json.*
import java.time.Instant
import java.util.UUID

given JsonCodec[RideStatus] = JsonCodec.string.transform(
  str => RideStatus.valueOf(str),
  status => status.toString
)

given JsonCodec[PaymentStatus] = JsonCodec.string.transform(
  str => PaymentStatus.valueOf(str),
  status => status.toString
)

given JsonCodec[PaymentMethod] = JsonCodec.string.transform(
  str => PaymentMethod.valueOf(str),
  method => method.toString
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
    driverApproaching: Boolean = false,
    driverDistanceMeters: Option[Int] = None,
    price: Option[Double] = None,
    notes: Option[String] = None,
    specialRequirements: Option[String] = None,
    paymentStatus: Option[String] = None,
    paymentMethod: Option[String] = None,
    paidAt: Option[String] = None,
    cancellationReason: Option[String] = None,
    cancellationFee: Option[Double] = None,
    cancelledBy: Option[String] = None,
    isVipRide: Boolean = false,
    preferredDriverUsed: Boolean = false,
    poolId: Option[String] = None
)

given JsonEncoder[RideDto] = DeriveJsonEncoder.gen[RideDto]
given JsonDecoder[RideDto] = DeriveJsonDecoder.gen[RideDto]

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
    price: Option[Double] = None,
    notes: Option[String] = None,
    specialRequirements: Option[String] = None,
    driverId: Option[String] = None
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

case class UpdateRideDetailsApiRequest(
    from: Option[LocationDto] = None,
    to: Option[LocationDto] = None,
    pickupDateTime: Option[String] = None,
    notes: Option[String] = None,
    flightNumber: Option[String] = None,
    isAirportTransfer: Option[Boolean] = None,
    specialRequirements: Option[String] = None
) derives JsonCodec

object UpdateRideDetailsApiRequest:

  private def parseInstant(dt: String): Option[Instant] =
    scala.util
      .Try(Instant.parse(dt))
      .orElse(scala.util.Try(java.time.LocalDateTime.parse(dt).toInstant(java.time.ZoneOffset.UTC)))
      .toOption

  def toDomain(request: UpdateRideDetailsApiRequest): UpdateRideDetailsRequest =
    import com.shevchyk.ride.domain.{UpdateRideDetailsRequest, RideSpecifics}
    val specifics =
      for {
        isAirport <- request.isAirportTransfer if isAirport
        flight    <- request.flightNumber
      } yield RideSpecifics.AirportTransfer(airportCode = "UNKNOWN", flightNumber = flight)

    UpdateRideDetailsRequest(
      pickupLocation = request.from.map(LocationDto.toDomain),
      dropoffLocation = request.to.map(LocationDto.toDomain),
      pickupDateTime = request.pickupDateTime.flatMap(parseInstant),
      notes = request.notes,
      specifics = specifics,
      specialRequirements = request.specialRequirements
    )

case class UpdateClientLocationRequest(
    latitude: Double,
    longitude: Double
) derives JsonCodec

case class AssignDriverRequest(
    driverId: String
) derives JsonCodec

case class SendChatMessageRequest(
    message: String
) derives JsonCodec

case class MarkPaymentRequest(
    paymentStatus: PaymentStatus,
    paymentMethod: Option[PaymentMethod] = None
) derives JsonCodec

case class CancelRideApiRequest(
    reason: String,
    fee: Option[Double] = None
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

  private val APPROACHING_THRESHOLD_METERS = 500

  def fromDomain(
      ride: Ride,
      driverLat: Option[Double] = None,
      driverLng: Option[Double] = None,
      clientName: Option[String] = None,
      driverName: Option[String] = None
  ): RideDto =
    val (flightNumber, isAirportTransfer) =
      ride.specifics match {
        case Some(RideSpecifics.AirportTransfer(_, flight)) => (Some(flight), true)
        case None                                           => (None, false)
      }

    val driverLoc =
      for {
        lat <- driverLat
        lng <- driverLng
      } yield LocationDto(address = "", latitude = Some(lat), longitude = Some(lng))

    val distanceMeters =
      for {
        dLat    <- driverLat
        dLng    <- driverLng
        pickLat <- ride.pickupLocation.latitude
        pickLng <- ride.pickupLocation.longitude
      } yield distanceMetersHaversine(dLat, dLng, pickLat, pickLng)

    val approaching =
      distanceMeters.exists(_ <= APPROACHING_THRESHOLD_METERS) &&
        (ride.status == RideStatus.Assigned || ride.status == RideStatus.InProgress)

    RideDto(
      id = ride.id.value.toString,
      clientId = ride.clientId.value.toString,
      creatorId = ride.creatorId.value.toString,
      driverId = ride.driverId.map(_.value.toString),
      scheduleDayId = None,
      pickupDateTime = ride.pickupDateTime.toString,
      from = LocationDto.fromDomain(ride.pickupLocation),
      to = LocationDto.fromDomain(ride.dropoffLocation),
      status = ride.status.toString,
      clientName = clientName.getOrElse("Unknown Client"),
      flightNumber = flightNumber,
      flightTime = ride.scheduledTime.map(_.toString),
      isAirportTransfer = isAirportTransfer,
      isArrival = flightNumber.isDefined,
      gate = None,
      terminal = None,
      flightStatus = None,
      driverName = driverName,
      driverLocation = driverLoc,
      driverApproaching = approaching,
      driverDistanceMeters = distanceMeters,
      price = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue),
      notes = ride.notes,
      specialRequirements = ride.specialRequirements,
      paymentStatus = Some(ride.paymentStatus.toString),
      paymentMethod = ride.paymentMethod.map(_.toString),
      paidAt = ride.paidAt.map(_.toString),
      cancellationReason = ride.cancellationReason,
      cancellationFee = ride.cancellationFee.map(_.doubleValue),
      cancelledBy = ride.cancelledBy.map(_.value.toString),
      isVipRide = ride.isVipRide,
      preferredDriverUsed = ride.preferredDriverUsed,
      poolId = ride.poolId.map(_.value.toString)
    )

  private def distanceMetersHaversine(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Int =
    val R    = 6371000.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (R * c).toInt

object CreateRideApiRequest:

  def toDomain(request: CreateRideApiRequest, companyId: CompanyId): IO[Response, CreateRideRequest] =
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

    UuidParser.parsePersonId(request.clientId).map { clientId =>
      CreateRideRequest(
        clientId = clientId,
        companyId = companyId,
        pickupLocation = LocationDto.toDomain(request.from),
        dropoffLocation = LocationDto.toDomain(request.to),
        scheduledTime = scala.util.Try(Instant.parse(request.pickupDateTime)).toOption,
        notes = request.notes,
        specifics = specifics,
        specialRequirements = request.specialRequirements
      )
    }

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
