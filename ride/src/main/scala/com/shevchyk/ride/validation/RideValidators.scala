package com.shevchyk.ride.validation

import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.*
import com.shevchyk.core.domain.*
import zio.*
import java.time.Instant
import java.util.UUID
import scala.util.Try

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
      validateDateTime(request.pickupDateTime),
      validateClientId(request.clientId),
      validateAirportTransfer(request),
      validatePrice(request.price)
    )
    .mapError(errors => RideError.ValidationError(errors.toChunk.map(messageOf).mkString("; ")))

  private def messageOf(error: RideError): String =
    error match
      case RideError.ValidationError(message) => message
      case other                              => other.toString

  private def validateLocation(location: LocationDto, fieldName: String): IO[RideError, Unit] =
    ZIO
      .when(location.address.trim.isEmpty)(
        ZIO.fail(RideError.ValidationError(s"$fieldName cannot be empty"))
      )
      .unit

  private def validateDateTime(dateTime: String): IO[RideError, Unit] = ZIO
    .attempt(Instant.parse(dateTime))
    .orElseFail(RideError.ValidationError(s"Invalid datetime format: $dateTime. Expected ISO-8601 format"))
    .flatMap { instant =>
      // Allow a small clock-skew tolerance (RidePolicy) so a client whose clock
      // runs a few minutes fast isn't rejected. Must match RideService.
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
    ZIO
      .when(request.isAirportTransfer && request.flightNumber.isEmpty)(
        ZIO.fail(RideError.ValidationError("Flight number is required for airport transfers"))
      )
      .unit

  private def validatePrice(price: Option[Double]): IO[RideError, Unit] =
    ZIO
      .when(price.exists(_ < 0))(
        ZIO.fail(RideError.ValidationError("Price cannot be negative"))
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
    ZIO
      .when(location.address.trim.isEmpty)(
        ZIO.fail(RideError.ValidationError(s"$fieldName cannot be empty"))
      )
      .unit

  private def validateScheduledTime(time: Option[Instant]): IO[RideError, Unit] =
    ZIO
      .when(time.exists(RidePolicy.isInThePast(_)))(
        ZIO.fail(RideError.ValidationError("Scheduled time cannot be in the past"))
      )
      .unit

  private def validateDomainAirportTransfer(request: CreateRideRequest): IO[RideError, Unit] =
    request.specifics match {
      case Some(RideSpecifics.AirportTransfer(airportCode, flightNumber, _)) =>
        ZIO
          .when(airportCode.trim.isEmpty || flightNumber.trim.isEmpty)(
            ZIO.fail(
              RideError.ValidationError("Airport code and flight number must not be empty for airport transfers")
            )
          )
          .unit
      case None                                                              => ZIO.unit
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
