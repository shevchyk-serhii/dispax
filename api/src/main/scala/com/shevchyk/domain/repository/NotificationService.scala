package com.shevchyk.domain.repository

import com.shevchyk.domain.model.*
import zio.*

trait NotificationService:
  def notifyDriver(driverId: PersonId, message: String, rideId: Option[RideId] = None): IO[NotificationError, Unit]
  def notifyClient(clientId: PersonId, message: String, rideId: Option[RideId] = None): IO[NotificationError, Unit]
  def notifyCompany(companyId: CompanyId, message: String, rideId: Option[RideId] = None): IO[NotificationError, Unit]
  def sendSMSNotification(phoneNumber: String, message: String): IO[NotificationError, Unit]
  def sendEmailNotification(email: String, subject: String, message: String): IO[NotificationError, Unit]

trait LocationService:
  def calculateRoute(from: Location, to: Location): IO[LocationError, RouteInfo]
  def getEstimatedDistance(from: Location, to: Location): IO[LocationError, Distance]
  def geocodeAddress(address: String): IO[LocationError, Location]
  def reverseGeocode(latitude: Double, longitude: Double): IO[LocationError, String]

trait FlightInfoService:
  def getFlightInfo(flightNumber: String, date: java.time.LocalDate): IO[FlightError, Option[FlightInfo]]

  def getAirportArrivals(
      airportCode: String,
      from: java.time.LocalDateTime,
      to: java.time.LocalDateTime
  ): IO[FlightError, List[FlightInfo]]

  def getAirportDepartures(
      airportCode: String,
      from: java.time.LocalDateTime,
      to: java.time.LocalDateTime
  ): IO[FlightError, List[FlightInfo]]

case class RouteInfo(
    distance: Distance,
    estimatedDuration: java.time.Duration,
    waypoints: List[Location] = List.empty
) derives zio.json.JsonCodec

enum NotificationError extends Exception:
  case ServiceUnavailable(service: String)
  case InvalidRecipient(recipient: String)
  case MessageTooLong(maxLength: Int)
  case RateLimitExceeded
  case AuthenticationError
  case NetworkError(cause: Throwable)

  def message: String =
    this match
      case ServiceUnavailable(service) => s"Notification service unavailable: $service"
      case InvalidRecipient(recipient) => s"Invalid recipient: $recipient"
      case MessageTooLong(maxLength)   => s"Message too long, max length: $maxLength"
      case RateLimitExceeded           => "Rate limit exceeded for notifications"
      case AuthenticationError         => "Authentication failed with notification service"
      case NetworkError(cause)         => s"Network error: ${cause.getMessage}"

enum LocationError extends Exception:
  case ServiceUnavailable
  case InvalidAddress(address: String)
  case RouteNotFound(from: String, to: String)
  case GeocodeError(msg: String)
  case NetworkError(cause: Throwable)

  def message: String =
    this match
      case ServiceUnavailable      => "Location service unavailable"
      case InvalidAddress(address) => s"Invalid address: $address"
      case RouteNotFound(from, to) => s"Route not found from $from to $to"
      case GeocodeError(message)   => s"Geocoding error: $message"
      case NetworkError(cause)     => s"Network error: ${cause.getMessage}"

enum FlightError extends Exception:
  case ServiceUnavailable
  case FlightNotFound(flightNumber: String)
  case InvalidFlightNumber(flightNumber: String)
  case ApiRateLimitExceeded
  case NetworkError(cause: Throwable)

  def message: String =
    this match
      case ServiceUnavailable                => "Flight information service unavailable"
      case FlightNotFound(flightNumber)      => s"Flight not found: $flightNumber"
      case InvalidFlightNumber(flightNumber) => s"Invalid flight number: $flightNumber"
      case ApiRateLimitExceeded              => "Flight API rate limit exceeded"
      case NetworkError(cause)               => s"Network error: ${cause.getMessage}"
