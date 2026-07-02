package com.shevchyk.ride.validation

import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.*
import com.shevchyk.core.domain.*
import zio.*
import java.time.Instant
import java.util.UUID
import scala.util.Try

// Reject out-of-range coordinates (lat ∈ [-90,90], lon ∈ [-180,180]) and NaN/∞ so a
// malformed request can't poison ETA/proximity calculations downstream. Missing
// coordinates are allowed (geocoding may fill them in later). Shared by the DTO and
// domain location validators.
private def validateCoordinates(
    lat: Option[Double],
    lon: Option[Double],
    fieldName: String
): IO[RideError, Unit] =
  val latOk = lat.forall(v => !v.isNaN && !v.isInfinite && v >= -90.0 && v <= 90.0)
  val lonOk = lon.forall(v => !v.isNaN && !v.isInfinite && v >= -180.0 && v <= 180.0)
  ZIO
    .unless(latOk && lonOk)(
      ZIO.fail(RideError.ValidationError(s"$fieldName has invalid coordinates"))
    )
    .unit

// Free-form ride tags: bound the count and each tag's length, and reject blank-only tags, so a
// request can't store an unbounded or junk tag set. None (field omitted) is always valid. Shared by
// the create and update-details validators. Checked on the raw list — normalization only shrinks it.
private val MaxTags: Int      = 15
private val MaxTagLength: Int = 30

private def validateTags(tags: Option[List[String]]): IO[RideError, Unit] =
  tags match
    case None       => ZIO.unit
    case Some(list) =>
      val tooMany    = list.size > MaxTags
      val anyBlank   = list.exists(_.trim.isEmpty)
      val anyTooLong = list.exists(_.trim.length > MaxTagLength)
      if tooMany then ZIO.fail(RideError.ValidationError(s"At most $MaxTags tags are allowed"))
      else if anyBlank then ZIO.fail(RideError.ValidationError("Tags cannot be blank"))
      else if anyTooLong then ZIO.fail(RideError.ValidationError(s"Each tag must be at most $MaxTagLength characters"))
      else ZIO.unit

given createRideApiRequestValidator: Validator[CreateRideApiRequest] with
  type Error = RideError

  // Accumulating validation: every field problem is reported at once (better form
  // UX) instead of failing on the first one. The individual checks are unchanged;
  // `Validator.accumulate` runs them and gathers all failures, then we collapse the
  // collected messages into a single RideError.ValidationError to keep the
  // `Validator[A] { type Error = RideError }` contract.
  def validate(request: CreateRideApiRequest): IO[RideError, CreateRideApiRequest] = Validator
    .accumulate(request)(
      validateLocation(request.from, "Pickup location"),
      validateLocation(request.to, "Dropoff location"),
      validatePickupDateTime(request),
      // In provisional mode the client is created server-side, so clientId is empty/ignored here.
      if request.provisionalClient then ZIO.unit else validateClientId(request.clientId),
      validateAirportTransfer(request),
      validatePrice(request.price),
      validateTags(request.tags)
    )
    .mapError(errors => RideError.ValidationError(errors.toChunk.map(messageOf).mkString("; ")))

  private def messageOf(error: RideError): String =
    error match
      case RideError.ValidationError(message) => message
      case other                              => other.toString

  private def validateLocation(location: LocationDto, fieldName: String): IO[RideError, Unit] =
    for {
      _ <-
        ZIO
          .when(location.address.trim.isEmpty)(
            ZIO.fail(RideError.ValidationError(s"$fieldName cannot be empty"))
          )
      _ <- validateCoordinates(location.latitude, location.longitude, fieldName)
    } yield ()

  /**
   * Validates pickupDateTime:
   *   - For airport departure rides (isAirportTransfer=true, isArrival=false) pickupDateTime is optional: an absent
   *     value means "compute it from flightTime". When present, it must be a valid ISO-8601 instant and must not be in
   *     the past.
   *   - For all other ride types pickupDateTime is required and must be a valid ISO-8601 instant that is not in the
   *     past.
   */
  private def validatePickupDateTime(request: CreateRideApiRequest): IO[RideError, Unit] =
    val isDeparture = request.isAirportTransfer && !request.isArrival
    request.pickupDateTime match
      case None if isDeparture =>
        // Auto-compute path: no manual pickup time; PickupTimeService will compute it.
        // flightTime must be present — checked by validateAirportTransfer.
        ZIO.unit
      case None                =>
        // Non-departure rides must supply a pickup time.
        ZIO.fail(RideError.ValidationError("pickupDateTime is required"))
      case Some(dt)            =>
        ZIO
          .attempt(Instant.parse(dt))
          .orElseFail(RideError.ValidationError(s"Invalid datetime format: $dt. Expected ISO-8601 format"))
          .flatMap { instant =>
            ZIO
              .when(RidePolicy.isInThePast(instant))(
                ZIO.fail(RideError.ValidationError("Pickup time cannot be in the past"))
              )
              .unit
          }

  private def validateClientId(clientId: String): IO[RideError, Unit] =
    ZIO
      .attempt(UUID.fromString(clientId))
      .orElseFail(RideError.ValidationError(s"Invalid client ID format: $clientId"))
      .unit

  private def validateAirportTransfer(request: CreateRideApiRequest): IO[RideError, Unit] =
    for {
      // A flight number is NOT required: an airport transfer can be created before the flight is
      // known (it then gets no live gate/terminal/entry-time until the number is added). Only the
      // departure auto-compute path below still needs a flight time.
      // For departure rides without a manual pickup time, flightTime must be provided so the
      // backend can compute the pickup time automatically.
      _ <-
        ZIO
          .when(
            request.isAirportTransfer && !request.isArrival &&
              request.pickupDateTime.isEmpty && request.flightTime.isEmpty
          )(
            ZIO.fail(
              RideError.ValidationError(
                "flightTime is required for airport departure rides when pickupDateTime is not supplied"
              )
            )
          )
          .unit
      // Validate flightTime format when present.
      _ <-
        request.flightTime match
          case Some(ft) =>
            ZIO
              .attempt(Instant.parse(ft))
              .orElseFail(
                RideError.ValidationError(s"Invalid flightTime format: $ft. Expected ISO-8601 format")
              )
              .unit
          case None     => ZIO.unit
    } yield ()

  private def validatePrice(price: Option[Double]): IO[RideError, Unit] =
    ZIO
      .when(price.exists(_ <= 0))(
        ZIO.fail(RideError.ValidationError("Price must be greater than zero"))
      )
      .unit

given createRideRequestValidator: Validator[CreateRideRequest] with
  type Error = RideError

  def validate(request: CreateRideRequest): IO[RideError, CreateRideRequest] =
    for {
      _ <- validateDomainLocation(request.pickupLocation, "Pickup location")
      _ <- validateDomainLocation(request.dropoffLocation, "Dropoff location")
      _ <- validateScheduledTime(request.scheduledTime)
      _ <- validateDomainAirportTransfer(request)
    } yield request

  private def validateDomainLocation(location: Location, fieldName: String): IO[RideError, Unit] =
    for {
      _ <-
        ZIO
          .when(location.address.trim.isEmpty)(
            ZIO.fail(RideError.ValidationError(s"$fieldName cannot be empty"))
          )
      _ <- validateCoordinates(location.latitude, location.longitude, fieldName)
    } yield ()

  private def validateScheduledTime(time: Option[Instant]): IO[RideError, Unit] =
    ZIO
      .when(time.exists(RidePolicy.isInThePast(_)))(
        ZIO.fail(RideError.ValidationError("Scheduled time cannot be in the past"))
      )
      .unit

  private def validateDomainAirportTransfer(request: CreateRideRequest): IO[RideError, Unit] =
    request.specifics match {
      // Only the airport code is mandatory; the flight number is optional (may be unknown at creation).
      case Some(RideSpecifics.AirportTransfer(airportCode, _, _)) =>
        ZIO
          .when(airportCode.trim.isEmpty)(
            ZIO.fail(
              RideError.ValidationError("Airport code must not be empty for airport transfers")
            )
          )
          .unit
      case None                                                   => ZIO.unit
    }

given assignDriverRequestValidator: Validator[AssignDriverRequest] with
  type Error = RideError

  def validate(request: AssignDriverRequest): IO[RideError, AssignDriverRequest] =
    for {
      _ <- validateDriverId(request.driverId)
    } yield request

  private def validateDriverId(driverId: String): IO[RideError, Unit] =
    ZIO
      .attempt(UUID.fromString(driverId))
      .orElseFail(RideError.ValidationError(s"Invalid driver ID format: $driverId"))
      .unit

given cancelRideApiRequestValidator: Validator[CancelRideApiRequest] with
  type Error = RideError

  def validate(request: CancelRideApiRequest): IO[RideError, CancelRideApiRequest] =
    for {
      _ <- validateReason(request.reason)
      _ <- validateFee(request.fee)
    } yield request

  // The reason must be one of the known CancellationReason values. Role-specific allowance
  // (clients cannot state staff-only reasons) is enforced in RideService, which knows the caller's role.
  private def validateReason(reason: String): IO[RideError, Unit] =
    ZIO
      .fromOption(CancellationReason.fromString(reason))
      .orElseFail(RideError.ValidationError(s"Unknown cancellation reason: $reason"))
      .unit

  // A cancellation fee is a charge to the client, never a refund: a negative
  // value would credit the client instead of charging them. Zero is allowed
  // (free cancellation).
  private def validateFee(fee: Option[Double]): IO[RideError, Unit] =
    ZIO
      .when(fee.exists(f => f.isNaN || f < 0))(
        ZIO.fail(RideError.ValidationError("Cancellation fee cannot be negative"))
      )
      .unit

given rideStatusUpdateRequestValidator: Validator[RideStatusUpdateRequest] with
  type Error = RideError

  def validate(request: RideStatusUpdateRequest): IO[RideError, RideStatusUpdateRequest] =
    for {
      _ <- validateStatus(request.status)
    } yield request

  private def validateStatus(status: String): IO[RideError, Unit] =
    Try(RideStatus.valueOf(status)) match
      case scala.util.Success(_) => ZIO.unit
      case scala.util.Failure(_) =>
        ZIO.fail(
          RideError.ValidationError(
            s"Invalid ride status: $status. Valid values: ${RideStatus.values.mkString(", ")}"
          )
        )

given updateRideApiRequestValidator: Validator[UpdateRideApiRequest] with
  type Error = RideError

  def validate(request: UpdateRideApiRequest): IO[RideError, UpdateRideApiRequest] =
    for {
      _ <- request.clientId.map(validateClientIdString).getOrElse(ZIO.unit)
      _ <- request.pickupLocation.map(loc => validateNonEmpty(loc, "Pickup location")).getOrElse(ZIO.unit)
      _ <- request.destination.map(loc => validateNonEmpty(loc, "Destination")).getOrElse(ZIO.unit)
      _ <- request.pickupTime.map(validateDateTimeString).getOrElse(ZIO.unit)
      _ <- request.status.map(validateStatusString).getOrElse(ZIO.unit)
      _ <- request.passengerCount.map(validatePassengerCount).getOrElse(ZIO.unit)
    } yield request

  private def validateClientIdString(clientId: String): IO[RideError, Unit] =
    ZIO
      .attempt(UUID.fromString(clientId))
      .orElseFail(RideError.ValidationError(s"Invalid client ID format: $clientId"))
      .unit

  private def validateNonEmpty(value: String, fieldName: String): IO[RideError, Unit] =
    ZIO
      .when(value.trim.isEmpty)(
        ZIO.fail(RideError.ValidationError(s"$fieldName cannot be empty"))
      )
      .unit

  private def validateDateTimeString(dateTime: String): IO[RideError, Unit] =
    ZIO
      .attempt(Instant.parse(dateTime))
      .orElseFail(RideError.ValidationError(s"Invalid datetime format: $dateTime"))
      .unit

  private def validateStatusString(status: String): IO[RideError, Unit] =
    Try(RideStatus.valueOf(status)) match
      case scala.util.Success(_) => ZIO.unit
      case scala.util.Failure(_) => ZIO.fail(RideError.ValidationError(s"Invalid ride status: $status"))

  private def validatePassengerCount(count: Int): IO[RideError, Unit] =
    ZIO
      .when(count <= 0 || count > 8)(
        ZIO.fail(RideError.ValidationError("Passenger count must be between 1 and 8"))
      )
      .unit

given rejectRideRequestValidator: Validator[RejectRideRequest] with
  type Error = RideError

  def validate(request: RejectRideRequest): IO[RideError, RejectRideRequest] = ZIO
    .when(request.reason.trim.isEmpty)(
      ZIO.fail(RideError.ValidationError("Rejection reason must not be empty"))
    )
    .as(request)

given markCheckpointRequestValidator: Validator[MarkCheckpointRequest] with
  type Error = RideError

  private val validCheckpoints = Set("landed", "arrivals_hall", "terminal_exit")

  def validate(request: MarkCheckpointRequest): IO[RideError, MarkCheckpointRequest] = ZIO
    .when(!validCheckpoints.contains(request.checkpoint.toLowerCase))(
      ZIO.fail(
        RideError.ValidationError(
          s"Invalid checkpoint: '${request.checkpoint}'. Valid values: ${validCheckpoints.mkString(", ")}"
        )
      )
    )
    .as(request)

given updateRideDetailsApiRequestValidator: Validator[UpdateRideDetailsApiRequest] with
  type Error = RideError

  // Tags need bounding and a client reassignment must carry a well-formed UUID (toDomain parses it
  // with a silent-drop fallback, so a malformed id must be rejected here, not ignored there).
  def validate(request: UpdateRideDetailsApiRequest): IO[RideError, UpdateRideDetailsApiRequest] =
    for {
      _ <- validateTags(request.tags)
      _ <- request.clientId.map(validateClientIdFormat).getOrElse(ZIO.unit)
    } yield request

  private def validateClientIdFormat(clientId: String): IO[RideError, Unit] =
    ZIO
      .attempt(UUID.fromString(clientId.trim))
      .orElseFail(RideError.ValidationError(s"Invalid client ID format: $clientId"))
      .unit
