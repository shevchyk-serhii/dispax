package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.domain.{Location, CompanyId}
import com.shevchyk.ride.domain.{
  Ride,
  CreateRideRequest,
  RideSpecifics,
  RideStatus,
  PaymentStatus,
  PaymentMethod,
  TagNormalizer,
  UpdateRideDetailsRequest,
  VehicleClass
}
import zio.*
import zio.http.*
import zio.json.*
import java.time.Instant

given JsonCodec[RideStatus] = JsonCodec.string.transformOrFail(
  str => scala.util.Try(RideStatus.valueOf(str)).toEither.left.map(_ => s"Unknown RideStatus: $str"),
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
    // Whether the client has a profile photo, so a driver/dispatcher card can render their avatar.
    // Derived from the client Person already loaded for clientName; defaults false for backward compatibility.
    clientHasAvatar: Boolean = false,
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
    etaMinutes: Option[Int] = None,
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
    poolId: Option[String] = None,
    vehicleClass: String = "business",
    driverRating: Option[Double] = None,
    driverRatingCount: Option[Int] = None,
    // For airport departure rides: the backend-computed pickup time (same as pickupDateTime
    // for auto-computed rides). Included as a convenience field so the frontend can display
    // the computed value without re-parsing pickupDateTime.
    recommendedPickupDateTime: Option[String] = None,
    externalDriverId: Option[String] = None,
    partnerCompanyId: Option[String] = None,
    confirmed: Boolean = false,
    confirmedAt: Option[String] = None,
    rejectionReason: Option[String] = None,
    // Free-form operator tags attached to the ride.
    tags: List[String] = Nil
)

given JsonEncoder[RideDto] = DeriveJsonEncoder.gen[RideDto]
given JsonDecoder[RideDto] = DeriveJsonDecoder.gen[RideDto]

case class CreateRideApiRequest(
    clientId: String,
    creatorId: String,
    scheduleDayId: Option[String] = None,
    // pickupDateTime is optional for airport departure rides: an absent value signals
    // "compute it automatically from flightTime". For all other ride types it is required.
    // A present value is always respected verbatim (manual override wins).
    pickupDateTime: Option[String] = None,
    from: LocationDto,
    to: LocationDto,
    status: String = "requested",
    clientName: String,
    flightNumber: Option[String] = None,
    // flightTime carries the flight departure date-time (ISO-8601 UTC) for departure rides.
    // Required when isAirportTransfer=true && isArrival=false && pickupDateTime is absent.
    flightTime: Option[String] = None,
    isAirportTransfer: Boolean = false,
    isArrival: Boolean = false,
    gate: Option[String] = None,
    terminal: Option[String] = None,
    price: Option[Double] = None,
    notes: Option[String] = None,
    specialRequirements: Option[String] = None,
    driverId: Option[String] = None,
    vehicleClass: Option[String] = None,
    // Operator-selected payment method (wire enum name, e.g. "Invoice"). Absent leaves it unset.
    paymentMethod: Option[String] = None,
    // Free-form operator tags. Normalized server-side before persistence.
    tags: Option[List[String]] = None
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
    specialRequirements: Option[String] = None,
    // None = leave tags unchanged; Some(list) = replace. Normalized server-side in toDomain.
    tags: Option[List[String]] = None
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
      specialRequirements = request.specialRequirements,
      // Preserve None (= unchanged); normalize when present so the tag filter never splits casing.
      tags = request.tags.map(TagNormalizer.normalize)
    )

case class UpdateClientLocationRequest(
    latitude: Double,
    longitude: Double
) derives JsonCodec

case class AssignDriverRequest(
    driverId: String,
    // When true, a dispatcher knowingly (re)assigns a driver despite a schedule conflict.
    // Honoured by both the assign and reassign endpoints; defaulted for backward compatibility.
    overrideScheduleConflict: Boolean = false
) derives JsonCodec

case class SendChatMessageRequest(
    message: String
) derives JsonCodec

case class MarkPaymentRequest(
    paymentStatus: PaymentStatus,
    paymentMethod: Option[PaymentMethod] = None
) derives JsonCodec

case class SetRidePriceRequest(
    price: Double
) derives JsonCodec

case class CancelRideApiRequest(
    reason: String,
    fee: Option[Double] = None
) derives JsonCodec

case class HandOffRideApiRequest(
    externalDriverId: String,
    partnerCompanyId: String
) derives JsonCodec

case class PartnerCompanyDto(
    id: String,
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None,
    taxiCompanyId: String,
    createdAt: String,
    updatedAt: String
) derives JsonCodec

case class CreatePartnerCompanyApiRequest(
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None
) derives JsonCodec

case class ExternalDriverDto(
    id: String,
    name: String,
    phone: Option[String] = None,
    partnerCompanyId: Option[String] = None,
    taxiCompanyId: String,
    createdAt: String,
    updatedAt: String
) derives JsonCodec

case class CreateExternalDriverApiRequest(
    name: String,
    phone: Option[String] = None,
    partnerCompanyId: Option[String] = None
) derives JsonCodec

case class RejectRideRequest(
    reason: String
) derives JsonCodec

case class ValidationErrorsResponse(
    errors: List[ValidationFieldError]
) derives JsonCodec

case class ValidationFieldError(
    field: String,
    message: String
) derives JsonCodec

// -- Estimate DTOs ------------------------------------------------------------

case class EstimateRideRequest(
    from: LocationDto,
    to: LocationDto,
    vehicleClass: String = "business",
    isAirportTransfer: Boolean = false,
    // Optional ISO-8601 pickup time; when present and within night hours
    // (22:00–06:00 Europe/Berlin) the night surcharge is applied.
    pickupDateTime: Option[String] = None
) derives JsonCodec

case class EstimateRideResponse(
    distanceKm: Double,
    durationMinutes: Int,
    estimatedPrice: Double,
    currency: String
) derives JsonCodec

// -- Airport checkpoint DTOs ---------------------------------------------------

case class MarkCheckpointRequest(
    checkpoint: String // "landed" | "arrivals_hall" | "terminal_exit"
) derives JsonCodec

case class CheckpointStateResponse(
    checkpoint: Option[String],
    checkpointName: Option[String]
) derives JsonCodec

// -- Tapir schemas (alongside the zio-json codecs above) so these DTOs can be
//    used directly as Tapir request/response bodies and appear in the OpenAPI doc.
given sttp.tapir.Schema[PaymentStatus]                  = sttp.tapir.Schema.string
given sttp.tapir.Schema[PaymentMethod]                  = sttp.tapir.Schema.string
given sttp.tapir.Schema[RideDto]                        = sttp.tapir.Schema.derived[RideDto]
given sttp.tapir.Schema[CreateRideApiRequest]           = sttp.tapir.Schema.derived[CreateRideApiRequest]
given sttp.tapir.Schema[RideStatusUpdateRequest]        = sttp.tapir.Schema.derived[RideStatusUpdateRequest]
given sttp.tapir.Schema[AssignDriverRequest]            = sttp.tapir.Schema.derived[AssignDriverRequest]
given sttp.tapir.Schema[MarkPaymentRequest]             = sttp.tapir.Schema.derived[MarkPaymentRequest]
given sttp.tapir.Schema[CancelRideApiRequest]           = sttp.tapir.Schema.derived[CancelRideApiRequest]
given sttp.tapir.Schema[UpdateRideDetailsApiRequest]    = sttp.tapir.Schema.derived[UpdateRideDetailsApiRequest]
given sttp.tapir.Schema[HandOffRideApiRequest]          = sttp.tapir.Schema.derived[HandOffRideApiRequest]
given sttp.tapir.Schema[PartnerCompanyDto]              = sttp.tapir.Schema.derived[PartnerCompanyDto]
given sttp.tapir.Schema[CreatePartnerCompanyApiRequest] = sttp.tapir.Schema.derived[CreatePartnerCompanyApiRequest]
given sttp.tapir.Schema[ExternalDriverDto]              = sttp.tapir.Schema.derived[ExternalDriverDto]
given sttp.tapir.Schema[CreateExternalDriverApiRequest] = sttp.tapir.Schema.derived[CreateExternalDriverApiRequest]
given sttp.tapir.Schema[UpdateClientLocationRequest]    = sttp.tapir.Schema.derived[UpdateClientLocationRequest]
given sttp.tapir.Schema[SendChatMessageRequest]         = sttp.tapir.Schema.derived[SendChatMessageRequest]
given sttp.tapir.Schema[MarkCheckpointRequest]          = sttp.tapir.Schema.derived[MarkCheckpointRequest]
given sttp.tapir.Schema[CheckpointStateResponse]        = sttp.tapir.Schema.derived[CheckpointStateResponse]
given sttp.tapir.Schema[SetRidePriceRequest]            = sttp.tapir.Schema.derived[SetRidePriceRequest]
given sttp.tapir.Schema[EstimateRideRequest]            = sttp.tapir.Schema.derived[EstimateRideRequest]
given sttp.tapir.Schema[EstimateRideResponse]           = sttp.tapir.Schema.derived[EstimateRideResponse]
given sttp.tapir.Schema[RejectRideRequest]              = sttp.tapir.Schema.derived[RejectRideRequest]

object LocationDto:

  given sttp.tapir.Schema[LocationDto] = sttp.tapir.Schema.derived[LocationDto]

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
      clientHasAvatar: Boolean = false,
      driverName: Option[String] = None,
      etaMinutes: Option[Int] = None,
      driverRating: Option[Double] = None,
      driverRatingCount: Option[Int] = None
  ): RideDto =
    val (flightNumber, isAirportTransfer, isArrival) =
      ride.specifics match {
        case Some(RideSpecifics.AirportTransfer(_, flight, arr)) => (Some(flight), true, arr)
        case None                                                => (None, false, false)
      }

    // For airport departure rides, surface the computed pickup time as a convenience field.
    val recommendedPickupTime =
      if (isAirportTransfer && !isArrival)
        Some(ride.pickupDateTime.toString)
      else
        None

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
        (ride.status == RideStatus.Assigned || ride.status == RideStatus.Confirmed ||
          ride.status == RideStatus.InProgress)

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
      clientHasAvatar = clientHasAvatar,
      flightNumber = flightNumber,
      flightTime = ride.scheduledTime.map(_.toString),
      isAirportTransfer = isAirportTransfer,
      isArrival = isArrival,
      gate = None,
      terminal = None,
      flightStatus = None,
      driverName = driverName,
      driverLocation = driverLoc,
      driverApproaching = approaching,
      driverDistanceMeters = distanceMeters,
      etaMinutes = etaMinutes,
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
      poolId = ride.poolId.map(_.value.toString),
      vehicleClass = VehicleClass.toDbString(ride.vehicleClass),
      driverRating = driverRating,
      driverRatingCount = driverRatingCount,
      recommendedPickupDateTime = recommendedPickupTime,
      externalDriverId = ride.externalDriverId.map(_.value.toString),
      partnerCompanyId = ride.partnerCompanyId.map(_.value.toString),
      confirmed = ride.status == RideStatus.Confirmed,
      confirmedAt = ride.confirmedAt.map(_.toString),
      rejectionReason = ride.rejectionReason,
      tags = ride.tags
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

  private def parseInstantOpt(s: String): Option[Instant] =
    scala.util
      .Try(Instant.parse(s))
      .orElse(scala.util.Try(java.time.LocalDateTime.parse(s).toInstant(java.time.ZoneOffset.UTC)))
      .toOption

  def toDomain(request: CreateRideApiRequest, companyId: CompanyId): IO[Response, CreateRideRequest] =
    // Create AirportTransfer specifics when the ride is flagged as an airport transfer
    // or when a flight number is supplied.
    val specifics =
      if (request.isAirportTransfer || request.flightNumber.isDefined) {
        request.flightNumber.map { flight =>
          RideSpecifics.AirportTransfer(
            airportCode = extractAirportCode(request),
            flightNumber = flight,
            isArrival = request.isArrival
          )
        }
      }
      else {
        None
      }

    val parsedVehicleClass = request.vehicleClass.flatMap(VehicleClass.fromString).getOrElse(VehicleClass.Default)

    // paymentMethod: parse the wire enum name (e.g. "Invoice"); unknown/absent values stay None.
    val parsedPaymentMethod: Option[PaymentMethod] = request.paymentMethod.flatMap(s =>
      scala.util.Try(PaymentMethod.valueOf(s)).toOption
    )

    // pickupDateTime: parse the operator-supplied value when present; pass None otherwise.
    // A None signals "compute automatically" for airport departure rides.
    val parsedPickupDateTime: Option[Instant] = request.pickupDateTime.flatMap(parseInstantOpt)

    // scheduledTime: for airport transfers this carries the flight time (departure or arrival).
    // For regular rides it mirrors the pickup time.
    val parsedScheduledTime: Option[Instant] = request.flightTime.flatMap(parseInstantOpt)

    UuidParser.parsePersonId(request.clientId).map { clientId =>
      CreateRideRequest(
        clientId = clientId,
        companyId = companyId,
        pickupLocation = LocationDto.toDomain(request.from),
        dropoffLocation = LocationDto.toDomain(request.to),
        scheduledTime = parsedScheduledTime,
        notes = request.notes,
        specifics = specifics,
        specialRequirements = request.specialRequirements,
        vehicleClass = parsedVehicleClass,
        paymentMethod = parsedPaymentMethod,
        // Convert the wire Double price into the domain BigDecimal estimate (None stays None).
        estimatedPrice = request.price.map(BigDecimal(_)),
        pickupDateTime = parsedPickupDateTime,
        // Normalize free-form tags once, here, so the rest of the stack sees canonical values.
        tags = TagNormalizer.normalize(request.tags.getOrElse(Nil))
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
