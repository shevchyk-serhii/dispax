package com.shevchyk.domain.model

import java.time.LocalDateTime
import zio.json.*

opaque type RideId = Long

object RideId:
  def apply(value: Long): RideId         = value
  def generate(): RideId                 = scala.util.Random.nextLong().abs
  extension (id: RideId) def value: Long = id

  given JsonCodec[RideId] = JsonCodec.long.transform(RideId.apply, _.value)

opaque type PersonId = Int

object PersonId:
  def apply(value: Int): PersonId         = value
  extension (id: PersonId) def value: Int = id

  given JsonCodec[PersonId] = JsonCodec.int.transform(PersonId.apply, _.value)

opaque type CompanyId = Int

object CompanyId:
  def apply(value: Int): CompanyId         = value
  extension (id: CompanyId) def value: Int = id

  given JsonCodec[CompanyId] = JsonCodec.int.transform(CompanyId.apply, _.value)

case class Location(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec:

  def distanceTo(other: Location): Double =
    (latitude, longitude, other.latitude, other.longitude) match
      case (Some(lat1), Some(lon1), Some(lat2), Some(lon2)) =>
        val R    = 6371
        val dLat = math.toRadians(lat2 - lat1)
        val dLon = math.toRadians(lon2 - lon1)
        val a    =
          math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(math.toRadians(lat1)) * math.cos(math.toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2)
        val c    = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        R * c
      case _                                                => Double.MaxValue

case class Distance(kilometers: Double) derives JsonCodec:
  def +(other: Distance): Distance = Distance(kilometers + other.kilometers)
  def <(other: Distance): Boolean  = kilometers < other.kilometers

case class Price(amount: Double, currency: String = "EUR") derives JsonCodec:

  def +(other: Price): Price =
    require(currency == other.currency, s"Cannot add different currencies: $currency and ${other.currency}")
    Price(amount + other.amount, currency)

case class FlightInfo(
    flightNumber: String,
    flightTime: LocalDateTime,
    gate: Option[String] = None,
    terminal: Option[String] = None,
    status: String = "On Time",
    isArrival: Boolean
) derives JsonCodec

enum RideStatus derives JsonCodec:
  case Requested, Assigned, InProgress, Completed, Cancelled

  def canTransitionTo(newStatus: RideStatus): Boolean =
    (this, newStatus) match
      case (Requested, Assigned | Cancelled)   => true
      case (Assigned, InProgress | Cancelled)  => true
      case (InProgress, Completed | Cancelled) => true
      case (Completed | Cancelled, _)          => false
      case (status, same) if status == same    => true
      case _                                   => false

enum PersonRole derives JsonCodec:
  case driver, client, secretary, dispatcher

enum DriverStatus derives JsonCodec:
  case Available, Busy, Offline

case class Ride(
    id: RideId,
    clientId: PersonId,
    creatorId: PersonId,
    driverId: Option[PersonId] = None,
    companyId: CompanyId,
    pickupDateTime: LocalDateTime,
    from: Location,
    to: Location,
    status: RideStatus = RideStatus.Requested,
    flightInfo: Option[FlightInfo] = None,
    price: Option[Price] = None,
    estimatedDistance: Option[Distance] = None
) derives JsonCodec:

  def isAirportTransfer: Boolean =
    from.address.toLowerCase.contains("airport") || to.address.toLowerCase.contains("airport")

  def assignDriver(driverId: PersonId): Ride = copy(driverId = Some(driverId), status = RideStatus.Assigned)

  def startRide(): Either[String, Ride] =
    if status == RideStatus.Assigned then Right(copy(status = RideStatus.InProgress))
    else Left(s"Cannot start ride in status: $status")

  def completeRide(): Either[String, Ride] =
    if status == RideStatus.InProgress then Right(copy(status = RideStatus.Completed))
    else Left(s"Cannot complete ride in status: $status")

  def cancel(): Either[String, Ride] =
    if status != RideStatus.Completed then Right(copy(status = RideStatus.Cancelled))
    else Left("Cannot cancel completed ride")

case class Driver(
    id: PersonId,
    name: String,
    currentLocation: Location,
    status: DriverStatus = DriverStatus.Available,
    companyId: CompanyId
) derives JsonCodec:

  def isAvailableForRide: Boolean = status == DriverStatus.Available

  def distanceFromLocation(location: Location): Distance = Distance(currentLocation.distanceTo(location))

case class Person(
    id: PersonId,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    passwordHash: Option[String] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives JsonCodec

case class Tariff(
    basePrice: Price,
    pricePerKm: Price,
    airportSurcharge: Price = Price(0),
    nightSurcharge: Price = Price(0)
) derives JsonCodec
