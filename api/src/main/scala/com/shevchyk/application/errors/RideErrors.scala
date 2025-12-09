package com.shevchyk.application.errors

import com.shevchyk.domain.repository.*
import com.shevchyk.domain.model.*


enum RideError extends Exception:
  case ValidationError(msg: String)
  case NoDriversAvailable(location: String)
  case RideNotFound(id: RideId)
  case PersonNotFound(id: PersonId)
  case DriverNotFound(id: PersonId)
  case UnauthorizedAccess(userId: PersonId, rideId: RideId)
  case InvalidStatusTransition(from: RideStatus, to: RideStatus)
  case RideAlreadyAssigned(rideId: RideId, driverId: PersonId)
  case TariffNotFound(companyId: CompanyId)
  case DatabaseError(cause: RepositoryError)
  case ExternalServiceError(service: String, cause: Throwable)
  case BusinessRuleViolation(rule: String, msg: String)

  def message: String =
    this match
      case ValidationError(msg)                  => s"Validation error: $msg"
      case NoDriversAvailable(location)          => s"No available drivers near location: $location"
      case RideNotFound(id)                      => s"Ride not found: $id"
      case PersonNotFound(id)                    => s"Person not found: $id"
      case DriverNotFound(id)                    => s"Driver not found: $id"
      case UnauthorizedAccess(userId, rideId)    => s"User $userId not authorized to access ride $rideId"
      case InvalidStatusTransition(from, to)     => s"Cannot transition ride status from $from to $to"
      case RideAlreadyAssigned(rideId, driverId) => s"Ride $rideId is already assigned to driver $driverId"
      case TariffNotFound(companyId)             => s"No tariff found for company: $companyId"
      case DatabaseError(cause)                  => s"Database error: ${cause.message}"
      case ExternalServiceError(service, cause)  => s"$service error: ${cause.getMessage}"
      case BusinessRuleViolation(rule, message)  => s"Business rule violation '$rule': $message"


object ErrorMapper:
  def fromRepositoryError(error: RepositoryError): RideError = RideError.DatabaseError(error)

  def fromNotificationError(service: String)(error: NotificationError): RideError = RideError.ExternalServiceError(
    service,
    Exception(error.message)
  )

  def fromLocationError(error: LocationError): RideError = RideError.ExternalServiceError(
    "LocationService",
    Exception(error.message)
  )

  def fromFlightError(error: FlightError): RideError = RideError.ExternalServiceError(
    "FlightService",
    Exception(error.message)
  )
