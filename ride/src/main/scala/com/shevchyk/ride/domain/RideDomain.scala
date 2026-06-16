package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant
import zio.json.*

/**
 * Shared ride scheduling policy, so the DTO validators and RideService agree.
 */
object RidePolicy:
  /**
   * Clock-skew tolerance for pickup/scheduled times: a time up to this many seconds in the past is still accepted
   * (clients' clocks may run fast).
   */
  val ClockSkewToleranceSeconds: Long = 300L

  /**
   * True if `time` is before now minus the clock-skew tolerance.
   */
  def isInThePast(time: Instant, now: Instant = Instant.now()): Boolean = time.isBefore(
    now.minusSeconds(ClockSkewToleranceSeconds)
  )

enum AirportCheckpoint:
  case Landed, ArrivalsHall, TerminalExit

  def isAfter(other: AirportCheckpoint): Boolean = ordinal > other.ordinal

object AirportCheckpoint:

  def fromString(s: String): Option[AirportCheckpoint] =
    s.toLowerCase match
      case "landed"        => Some(Landed)
      case "arrivals_hall" => Some(ArrivalsHall)
      case "terminal_exit" => Some(TerminalExit)
      case _               => None

  def toDbString(c: AirportCheckpoint): String =
    c match
      case Landed       => "landed"
      case ArrivalsHall => "arrivals_hall"
      case TerminalExit => "terminal_exit"

  given JsonCodec[AirportCheckpoint] = JsonCodec.string.transformOrFail(
    s => fromString(s).toRight(s"Unknown airport checkpoint: $s"),
    toDbString
  )

enum RideStatus:
  case Requested, Assigned, InProgress, Completed, Cancelled

enum PaymentStatus:
  case Unpaid, Pending, Paid

enum PaymentMethod:
  case Cash, Card, Invoice, Bank, Receivable

sealed trait RideSpecifics

object RideSpecifics:

  /**
   * Specifics for airport transfer rides.
   *
   * `isArrival` encodes the direction of the flight: true = arrival (passenger disembarking), false = departure. Stored
   * in the `specifics` JSONB column so it survives round-trips without a separate SQL column. Legacy rows lacking the
   * field decode with Circe's default-param handling: Circe's `deriveDecoder` does NOT honour Scala default parameters,
   * so we use a custom decoder that falls back to `false` for the missing key.
   */
  final case class AirportTransfer(
      airportCode: String,
      flightNumber: String,
      isArrival: Boolean = false
  ) extends RideSpecifics

  // Circe JSON codecs for PostgreSQL JSONB
  import io.circe.{Codec, Decoder, Encoder}
  import io.circe.generic.semiauto.*
  import io.circe.syntax.*

  // Custom decoder: tolerates missing `isArrival` key (legacy rows) by defaulting to false.
  implicit val airportTransferDecoder: Decoder[AirportTransfer] = Decoder.instance { c =>
    for {
      airportCode  <- c.downField("airportCode").as[String]
      flightNumber <- c.downField("flightNumber").as[String]
      isArrival    <- c.downField("isArrival").as[Option[Boolean]]
    } yield AirportTransfer(airportCode, flightNumber, isArrival.getOrElse(false))
  }

  implicit val airportTransferEncoder: Encoder[AirportTransfer] = deriveEncoder[AirportTransfer]

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
    pickupDateTime: Instant,
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
    paymentStatus: PaymentStatus = PaymentStatus.Unpaid,
    paymentMethod: Option[PaymentMethod] = None,
    paidAt: Option[Instant] = None,
    cancellationReason: Option[String] = None,
    cancellationFee: Option[BigDecimal] = None,
    cancelledBy: Option[PersonId] = None,
    isVipRide: Boolean = false,
    preferredDriverUsed: Boolean = false,
    poolId: Option[RidePoolId] = None,
    scheduleDayId: Option[java.util.UUID] = None,
    invoiceId: Option[java.util.UUID] = None,
    flightIsArrival: Option[Boolean] = None,
    airportCheckpoint: Option[AirportCheckpoint] = None
):

  def canBeAssigned: Boolean   = status == RideStatus.Requested
  def canBeReassigned: Boolean = status == RideStatus.Assigned && driverId.isDefined
  def canBeStarted: Boolean    = status == RideStatus.Assigned && driverId.isDefined
  def canBeCompleted: Boolean  = status == RideStatus.InProgress
  def canBeCancelled: Boolean  = status != RideStatus.Completed && status != RideStatus.Cancelled
  def canBeEdited: Boolean     = status == RideStatus.Requested || status == RideStatus.Assigned

  def isAirportTransfer: Boolean = specifics.exists(_.isInstanceOf[RideSpecifics.AirportTransfer])

  /**
   * True when the ride is an arrival airport transfer (direction encoded in the AirportTransfer specifics).
   */
  def isArrivalAirportTransfer: Boolean =
    specifics.collectFirst { case at: RideSpecifics.AirportTransfer if at.isArrival => at }.isDefined

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
    pickupDateTime: Option[Instant] = None,
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
  case InvalidOperation(message: String)

object RideError
