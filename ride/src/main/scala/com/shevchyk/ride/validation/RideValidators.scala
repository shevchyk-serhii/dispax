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

  def validate(request: CreateRideApiRequest): IO[RideError, CreateRideApiRequest] =
    for {
      _ <- validateLocation(request.from, "Pickup location")
      _ <- validateLocation(request.to, "Dropoff location")
      _ <- validateDateTime(request.pickupDateTime)
      _ <- validateClientId(request.clientId)
      _ <- validateAirportTransfer(request)
      _ <- validatePrice(request.price)
    } yield request

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
      ZIO
        .when(instant.isBefore(Instant.now()))(
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
      .when(time.exists(_.isBefore(Instant.now())))(
        ZIO.fail(RideError.ValidationError("Scheduled time cannot be in the past"))
      )
      .unit

  private def validateDomainAirportTransfer(request: CreateRideRequest): IO[RideError, Unit] =
    ZIO
      .when(request.isAirportTransfer && request.airportCode.isEmpty)(
        ZIO.fail(RideError.ValidationError("Airport code is required for airport transfers"))
      )
      .unit

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
