package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.Instant

enum RideStatus derives JsonCodec:
  case Requested, Assigned, InProgress, Completed, Cancelled

final case class Ride(
    id: RideId,
    clientId: PersonId,
    creatorId: PersonId,
    driverId: Option[PersonId] = None,
    companyId: CompanyId,
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
    airportCode: Option[String] = None,
    flightNumber: Option[String] = None,
    isAirportTransfer: Boolean = false
) derives JsonCodec:

  def canBeAssigned: Boolean  = status == RideStatus.Requested
  def canBeStarted: Boolean   = status == RideStatus.Assigned && driverId.isDefined
  def canBeCompleted: Boolean = status == RideStatus.InProgress

final case class CreateRideRequest(
    clientId: PersonId,
    companyId: CompanyId,
    pickupLocation: Location,
    dropoffLocation: Location,
    scheduledTime: Option[Instant] = None,
    notes: Option[String] = None,
    airportCode: Option[String] = None,
    flightNumber: Option[String] = None,
    isAirportTransfer: Boolean = false
) derives JsonCodec

final case class UpdateRideStatusRequest(
    status: RideStatus,
    notes: Option[String] = None
) derives JsonCodec

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

object RideError:
  given JsonEncoder[RideError] = JsonEncoder[String].contramap(_.toString)
