package com.shevchyk.domain.service

import com.shevchyk.domain.model.*
import java.time.{LocalDateTime, LocalTime}

object RideDomainService:

  def calculatePrice(distance: Distance, tariff: Tariff, pickupTime: LocalDateTime, isAirportTransfer: Boolean): Price =
    val baseAmount       = tariff.basePrice.amount + (distance.kilometers * tariff.pricePerKm.amount)
    val airportSurcharge = if isAirportTransfer then tariff.airportSurcharge.amount else 0.0
    val nightSurcharge   = if isNightTime(pickupTime) then tariff.nightSurcharge.amount else 0.0

    Price(baseAmount + airportSurcharge + nightSurcharge, tariff.basePrice.currency)

  def assignBestDriver(availableDrivers: List[Driver], rideLocation: Location): Option[Driver] =
    availableDrivers
      .filter(_.isAvailableForRide)
      .sortBy(_.distanceFromLocation(rideLocation).kilometers)
      .headOption

  def validateRideRequest(
      clientId: PersonId,
      from: Location,
      to: Location,
      pickupDateTime: LocalDateTime
  ): Either[String, Unit] =
    for
      _ <- validatePickupTime(pickupDateTime)
      _ <- validateLocations(from, to)
    yield ()

  private def validatePickupTime(pickupDateTime: LocalDateTime): Either[String, Unit] =
    val now = LocalDateTime.now()
    if pickupDateTime.isBefore(now.minusMinutes(15)) then Left("Pickup time cannot be in the past")
    else if pickupDateTime.isAfter(now.plusMonths(6)) then Left("Cannot book rides more than 6 months in advance")
    else Right(())

  private def validateLocations(from: Location, to: Location): Either[String, Unit] =
    if from.address.trim.isEmpty then Left("From location cannot be empty")
    else if to.address.trim.isEmpty then Left("To location cannot be empty")
    else if from.address == to.address then Left("From and to locations cannot be the same")
    else Right(())

  private def isNightTime(dateTime: LocalDateTime): Boolean =
    val time = dateTime.toLocalTime
    time.isAfter(LocalTime.of(22, 0)) || time.isBefore(LocalTime.of(6, 0))

  def validateStatusTransition(currentStatus: RideStatus, newStatus: RideStatus): Either[String, Unit] =
    if currentStatus.canTransitionTo(newStatus) then Right(())
    else Left(s"Invalid status transition from $currentStatus to $newStatus")

  def isDriverSuitableForRide(driver: Driver, ride: Ride, maxDistance: Distance): Boolean =
    driver.isAvailableForRide &&
      driver.companyId == ride.companyId &&
      driver.distanceFromLocation(ride.from) < maxDistance

  def estimateRideDuration(distance: Distance): java.time.Duration =

    val averageSpeedKmh = if distance.kilometers > 20 then 60.0 else 40.0
    val hours           = distance.kilometers / averageSpeedKmh
    java.time.Duration.ofMinutes((hours * 60).round)

  def getRidePriority(ride: Ride): Int =
    val now              = LocalDateTime.now()
    val hoursUntilPickup = java.time.Duration.between(now, ride.pickupDateTime).toHours

    val basePriority =
      hoursUntilPickup match
        case h if h <= 1 => 1
        case h if h <= 2 => 2
        case h if h <= 4 => 3
        case _           => 4

    if ride.isAirportTransfer then basePriority - 1 else basePriority

  def canCancelRide(ride: Ride, userRole: PersonRole, userId: PersonId): Boolean =
    userRole match
      case PersonRole.client                            => ride.clientId == userId && ride.status != RideStatus.Completed
      case PersonRole.driver                            => ride.driverId.contains(userId) && ride.status == RideStatus.Assigned
      case PersonRole.secretary | PersonRole.dispatcher => ride.status != RideStatus.Completed
      case _                                            => false

  def filterRidesForUser(rides: List[Ride], user: Person): List[Ride] =
    user.role match
      case PersonRole.driver => rides.filter(_.driverId.contains(user.id))

      case PersonRole.client => rides.filter(_.clientId == user.id)

      case PersonRole.secretary | PersonRole.dispatcher =>
        user.companyId match
          case Some(companyId) => rides.filter(_.companyId == companyId)
          case None            => List.empty

      case _ => List.empty
