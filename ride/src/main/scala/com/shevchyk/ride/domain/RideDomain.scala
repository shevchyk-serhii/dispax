package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant

enum RideStatus:
  case Requested, Assigned, InProgress, Completed, Cancelled

sealed trait RideSpecifics

object RideSpecifics:

  final case class AirportTransfer(
      airportCode: String,
      flightNumber: String
  ) extends RideSpecifics

  // Circe JSON codecs for PostgreSQL JSONB
  import io.circe.{Codec, Decoder, Encoder}
  import io.circe.generic.semiauto.*
  import io.circe.syntax.*

  implicit val airportTransferCodec: Codec[AirportTransfer] = deriveCodec[AirportTransfer]

  implicit val rideSpecificsEncoder: Encoder[RideSpecifics] = Encoder.instance { case at: AirportTransfer =>
    at.asJson.mapObject(_.add("type", "AirportTransfer".asJson))
  }

  implicit val rideSpecificsDecoder: Decoder[RideSpecifics] = Decoder.instance { cursor =>
    cursor.downField("type").as[String].flatMap {
      case "AirportTransfer" => cursor.as[AirportTransfer]
      case other             => Left(io.circe.DecodingFailure(s"Unknown RideSpecifics type: $other", cursor.history))
    }
  }

  import zio.json.*
  import zio.json.internal.Write

  given JsonEncoder[AirportTransfer] = DeriveJsonEncoder.gen[AirportTransfer]
  given JsonDecoder[AirportTransfer] = DeriveJsonDecoder.gen[AirportTransfer]

  given JsonEncoder[RideSpecifics] =
    (a: RideSpecifics, indent: Option[Int], out: Write) =>
      a match {
        case at: AirportTransfer => JsonEncoder[AirportTransfer].unsafeEncode(at, indent, out)
      }

  given JsonDecoder[RideSpecifics] = JsonDecoder[AirportTransfer].map(identity)

final case class Ride(
    id: RideId,
    clientId: PersonId,
    creatorId: PersonId,
    companyId: CompanyId,
    driverId: Option[PersonId] = None,
    status: RideStatus = RideStatus.Requested,
    pickupLocation: Location,
    dropoffLocation: Location,
    scheduledTime: Option[Instant] = None,
    requestTime: Instant = Instant.now(),
    startTime: Option[Instant] = None,
    endTime: Option[Instant] = None,
    tariffId: Option[TariffId] = None,
    estimatedPrice: Option[BigDecimal] = None,
    finalPrice: Option[BigDecimal] = None,
    notes: Option[String] = None,
    specifics: Option[RideSpecifics] = None,
    specialRequirements: Option[String] = None,
    paymentStatus: Option[String] = None,
    paymentMethod: Option[String] = None,
    paidAt: Option[Instant] = None,
    cancellationReason: Option[String] = None,
    cancellationFee: Option[BigDecimal] = None,
    cancelledBy: Option[PersonId] = None,
    isVipRide: Boolean = false,
    preferredDriverUsed: Boolean = false,
    poolId: Option[RidePoolId] = None
):

  def canBeAssigned: Boolean   = status == RideStatus.Requested
  def canBeReassigned: Boolean = status == RideStatus.Assigned && driverId.isDefined
  def canBeStarted: Boolean    = status == RideStatus.Assigned && driverId.isDefined
  def canBeCompleted: Boolean  = status == RideStatus.InProgress
  def canBeCancelled: Boolean  = status != RideStatus.Completed && status != RideStatus.Cancelled
  def canBeEdited: Boolean     = status == RideStatus.Requested || status == RideStatus.Assigned

  def isAirportTransfer: Boolean = specifics.exists(_.isInstanceOf[RideSpecifics.AirportTransfer])

final case class CreateRideRequest(
    clientId: PersonId,
    companyId: CompanyId,
    pickupLocation: Location,
    dropoffLocation: Location,
    scheduledTime: Option[Instant] = None,
    notes: Option[String] = None,
    specifics: Option[RideSpecifics] = None,
    specialRequirements: Option[String] = None
)

final case class UpdateRideStatusRequest(
    status: RideStatus,
    notes: Option[String] = None
)

final case class CancelRideRequest(
    reason: String,
    fee: Option[BigDecimal] = None
)

final case class UpdateRideDetailsRequest(
    pickupLocation: Option[Location] = None,
    dropoffLocation: Option[Location] = None,
    scheduledTime: Option[Instant] = None,
    notes: Option[String] = None,
    specifics: Option[RideSpecifics] = None,
    specialRequirements: Option[String] = None
)

enum RideError extends Throwable:
  case ValidationError(message: String)
  case RideNotFound(id: RideId)
  case PersonNotFound(id: PersonId)
  case DriverNotFound(id: PersonId)
  case NoDriversAvailable(location: Location)
  case UnauthorizedAccess(userId: PersonId, rideId: RideId)
  case InvalidStatusTransition(from: RideStatus, to: RideStatus)
  case RideAlreadyAssigned(rideId: RideId, driverId: PersonId)
  case DatabaseError(cause: Throwable)
  case ExternalServiceError(service: String, cause: Throwable)
  case BusinessRuleViolation(rule: String, message: String)
  case TariffNotFound(id: TariffId)

object RideError
