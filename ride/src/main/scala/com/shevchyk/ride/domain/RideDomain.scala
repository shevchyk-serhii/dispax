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

/**
 * Single source of truth for normalizing free-form ride tags so the dispatcher's tag filter never splits "Urgent" from
 * "urgent". Applied in BOTH the create and update DTO `toDomain` paths.
 *
 * Each tag is trimmed, internal whitespace is collapsed to single spaces, blanks are dropped, and the list is
 * de-duplicated case-insensitively while preserving the first-seen original casing and order.
 */
object TagNormalizer:

  def normalize(tags: List[String]): List[String] =
    val seen = scala.collection.mutable.LinkedHashMap.empty[String, String]
    tags.foreach { raw =>
      val cleaned = raw.trim.replaceAll("\\s+", " ")
      if cleaned.nonEmpty then
        val key = cleaned.toLowerCase
        if !seen.contains(key) then seen.update(key, cleaned)
    }
    seen.values.toList

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

  /**
   * Static fallback display name when the configurable airport config is unavailable.
   */
  def defaultDisplayName(c: AirportCheckpoint): String =
    c match
      case Landed       => "Landed"
      case ArrivalsHall => "Arrivals Hall"
      case TerminalExit => "Terminal Exit"

  given JsonCodec[AirportCheckpoint] = JsonCodec.string.transformOrFail(
    s => fromString(s).toRight(s"Unknown airport checkpoint: $s"),
    toDbString
  )

/**
 * Vehicle class offered at booking time. Drives fare estimation (seats/bags capacity and the price multiplier) and is
 * shown on the client booking screen. Stored as a plain string in the `vehicle_class` column; legacy rows are null and
 * default to [[Business]] when read.
 */
enum VehicleClass:
  case Business, Van

  /**
   * Passenger seats advertised for this class (shown on the booking tile).
   */
  def seats: Int =
    this match
      case Business => 3
      case Van      => 6

  /**
   * Luggage capacity advertised for this class.
   */
  def bags: Int =
    this match
      case Business => 2
      case Van      => 5

  /**
   * Fare multiplier relative to the company tariff base/per-km price.
   */
  def priceMultiplier: BigDecimal =
    this match
      case Business => BigDecimal(1.0)
      case Van      => BigDecimal(1.4)

object VehicleClass:

  val Default: VehicleClass = Business

  def fromString(s: String): Option[VehicleClass] =
    s.trim.toLowerCase match
      case "business" => Some(Business)
      case "van"      => Some(Van)
      case _          => None

  def toDbString(c: VehicleClass): String =
    c match
      case Business => "business"
      case Van      => "van"

  given JsonCodec[VehicleClass] = JsonCodec.string.transformOrFail(
    s => fromString(s).toRight(s"Unknown vehicle class: $s"),
    toDbString
  )

/**
 * Reason a ride was cancelled. Some reasons are role-specific: a client cancelling their own ride can only state a
 * client-side reason (they changed their mind, weather, or something else), whereas operational reasons such as the
 * client not showing up, the driver being unavailable, or a vehicle fault are reported by staff (driver/dispatcher/
 * secretary/admin). Stored as the canonical wire string in `cancellation_reason`.
 */
enum CancellationReason:
  case ClientNoShow, ClientRequest, DriverUnavailable, Weather, VehicleIssue, Other

object CancellationReason:

  def fromString(s: String): Option[CancellationReason] =
    s.trim.toLowerCase match
      case "client_no_show"     => Some(ClientNoShow)
      case "client_request"     => Some(ClientRequest)
      case "driver_unavailable" => Some(DriverUnavailable)
      case "weather"            => Some(Weather)
      case "vehicle_issue"      => Some(VehicleIssue)
      case "other"              => Some(Other)
      case _                    => None

  def toWire(r: CancellationReason): String =
    r match
      case ClientNoShow      => "client_no_show"
      case ClientRequest     => "client_request"
      case DriverUnavailable => "driver_unavailable"
      case Weather           => "weather"
      case VehicleIssue      => "vehicle_issue"
      case Other             => "other"

  /**
   * Reasons a client is allowed to state when cancelling their own ride. Operational reasons (no-show, driver
   * unavailable, vehicle issue) are staff-only; a client cancelling because they "didn't show up" is nonsensical.
   */
  private val clientAllowed: Set[CancellationReason] = Set(ClientRequest, Weather, Other)

  /**
   * Whether `role` may cancel a ride citing this reason. Staff (driver/dispatcher/secretary/admin/super-admin) may use
   * any reason; clients are restricted to [[clientAllowed]].
   */
  def allowedFor(reason: CancellationReason, role: PersonRole): Boolean =
    role match
      case PersonRole.Client => clientAllowed.contains(reason)
      case _                 => true

  given JsonCodec[CancellationReason] = JsonCodec.string.transformOrFail(
    s => fromString(s).toRight(s"Unknown cancellation reason: $s"),
    toWire
  )

enum RideStatus:
  case Requested, Assigned, Confirmed, InProgress, Completed, Cancelled, HandedOff

enum PaymentStatus:
  case Unpaid, Pending, Paid

enum PaymentMethod:
  case Cash, Card, Invoice, Bank, Receivable, Payment

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
      // None when the ride is a known airport transfer but the flight number is not yet known.
      // Without a flight number there is no live gate/terminal/entry-time lookup, by design.
      flightNumber: Option[String] = None,
      isArrival: Boolean = false
  ) extends RideSpecifics

  // Circe JSON codecs for PostgreSQL JSONB
  import io.circe.{Decoder, Encoder}
  import io.circe.generic.semiauto.*
  import io.circe.syntax.*

  // Custom decoder: tolerates a missing `isArrival` key (legacy rows) by defaulting to false, and
  // decodes `flightNumber` as optional (legacy rows always have a String; new airport-without-flight
  // rows may omit it or store null).
  implicit val airportTransferDecoder: Decoder[AirportTransfer] = Decoder.instance { c =>
    for {
      airportCode  <- c.downField("airportCode").as[String]
      flightNumber <- c.downField("flightNumber").as[Option[String]]
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
    airportCheckpoint: Option[AirportCheckpoint] = None,
    vehicleClass: VehicleClass = VehicleClass.Default,
    externalDriverId: Option[ExternalDriverId] = None,
    partnerCompanyId: Option[PartnerCompanyId] = None,
    confirmedAt: Option[java.time.Instant] = None,
    rejectionReason: Option[String] = None,
    rejectedBy: Option[PersonId] = None,
    rejectedAt: Option[java.time.Instant] = None,
    // Free-form operator labels (e.g. "Urgent", "Cash"). Normalized via TagNormalizer; empty by default.
    tags: List[String] = Nil
):

  def canBeAssigned: Boolean   = status == RideStatus.Requested
  def canBeReassigned: Boolean = (status == RideStatus.Assigned || status == RideStatus.Confirmed) && driverId.isDefined
  def canBeConfirmed: Boolean  = status == RideStatus.Assigned && driverId.isDefined
  def canBeRejected: Boolean   = (status == RideStatus.Assigned || status == RideStatus.Confirmed) && driverId.isDefined
  // Drivers must confirm before starting; dispatchers may override (Assigned -> InProgress) via updateRideStatus.
  def canBeStarted: Boolean    = status == RideStatus.Confirmed && driverId.isDefined
  def canBeCompleted: Boolean  = status == RideStatus.InProgress
  def canBeCancelled: Boolean  = status != RideStatus.Completed && status != RideStatus.Cancelled
  def canBeHandedOff: Boolean  = status == RideStatus.Requested

  def canBeEdited: Boolean =
    status == RideStatus.Requested || status == RideStatus.Assigned || status == RideStatus.Confirmed

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
    specialRequirements: Option[String] = None,
    vehicleClass: VehicleClass = VehicleClass.Default,
    // Operator-selected payment method chosen at ride creation. None leaves it unset.
    paymentMethod: Option[PaymentMethod] = None,
    // Client/operator-supplied fare estimate. Stored on the ride as estimatedPrice when present;
    // None leaves the ride unpriced (RideEstimateService is invoked separately, not here).
    estimatedPrice: Option[BigDecimal] = None,
    // pickupDateTime carries the operator-supplied pickup time (when Some) or "compute it" (when
    // None, for airport departure rides only). For all other ride types this field is always Some.
    pickupDateTime: Option[Instant] = None,
    // clientCompanyId is resolved from the client Person and used by PickupTimeService to apply
    // client-level airport timing overrides. May be None when the client has no company affiliation.
    clientCompanyId: Option[ClientCompanyId] = None,
    // Free-form operator labels. Already normalized by the DTO layer before reaching the mapper.
    tags: List[String] = Nil
)

final case class UpdateRideStatusRequest(
    status: RideStatus,
    notes: Option[String] = None
)

final case class CancelRideRequest(
    reason: String,
    fee: Option[BigDecimal] = None
)

final case class HandOffRequest(
    externalDriverId: ExternalDriverId,
    partnerCompanyId: PartnerCompanyId
)

/**
 * A three-valued update for a single field, so a partial update can tell "leave it as it is" apart from "remove the
 * value". A plain `Option` collapses these two (both are `None`), which is why an absent flight number and a cleared
 * flight number could not be distinguished before.
 */
enum FieldUpdate[+A]:
  case Unchanged
  case Clear
  case Set(value: A)

final case class UpdateRideDetailsRequest(
    pickupLocation: Option[Location] = None,
    dropoffLocation: Option[Location] = None,
    pickupDateTime: Option[Instant] = None,
    scheduledTime: Option[Instant] = None,
    notes: Option[String] = None,
    // Three-valued: Unchanged leaves the ride's specifics, Clear removes them (e.g. the flight number
    // was cleared so the ride is no longer an airport transfer), Set replaces (preserving direction in
    // the service when both old and new are airport transfers).
    specifics: FieldUpdate[RideSpecifics] = FieldUpdate.Unchanged,
    specialRequirements: Option[String] = None,
    // None = leave the ride's tags unchanged; Some(list) = replace with this (already normalized).
    tags: Option[List[String]] = None,
    // None = keep the ride's client; Some(id) = reassign the ride to that client. A ride always has
    // a client, so there is no Clear case. The service verifies company isolation for the new client.
    clientId: Option[PersonId] = None
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

  // Structured details of the conflicting ride so the client can render a
  // human-readable, localized dialog (route + client + the dispatcher's local
  // time) instead of showing a raw id. All optional: the manual-unavailability
  // branch raises ScheduleConflict with just a message.
  case ScheduleConflict(
      message: String,
      conflictingRideId: Option[RideId] = None,
      conflictingClientId: Option[PersonId] = None,
      conflictingFrom: Option[String] = None,
      conflictingTo: Option[String] = None,
      conflictingPickupAt: Option[Instant] = None
  )
  case DatabaseError(cause: Throwable)
  case ExternalServiceError(service: String, cause: Throwable)
  case BusinessRuleViolation(rule: String, message: String)
  case TariffNotFound(id: TariffId)
  case InvalidOperation(message: String)
  case ExternalDriverNotFound(id: ExternalDriverId)
  case PartnerCompanyNotFound(id: PartnerCompanyId)
  case RideAlreadyConfirmed(rideId: RideId)
  case RejectionReasonRequired(rideId: RideId)

  // A guest share token was not found, has expired, or the ride is outside its
  // tracking window. Deliberately information-free (no fields) so the API maps it
  // to 404 — a guest must not be able to tell "wrong token" from "expired" from
  // "ride gone", which would leak the existence of rides.
  case ShareTokenInvalid

object RideError
