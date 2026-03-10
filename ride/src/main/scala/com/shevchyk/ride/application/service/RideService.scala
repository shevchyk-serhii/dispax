package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.repository.PersonRepository
import zio.*
import java.time.Instant
import monocle.syntax.all.*

trait RideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]
  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def completeRide(rideId: RideId): IO[RideError, Ride]
  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]
  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride]
  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]
  def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]]

class RideServiceImpl(
    rideRepository: RideRepository,
    personRepository: PersonRepository
) extends RideService:

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepository
    .findById(rideId)
    .mapDatabaseError
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for {
      ride          <- ZIO.succeed(RideMapper.fromRequest(request))
      persistedRide <- rideRepository.create(ride).mapDatabaseError
    } yield persistedRide

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] = rideRepository
    .findByClientId(userId)
    .orElse(rideRepository.findByDriverId(userId))
    .mapError(ex => RideError.DatabaseError(ex))

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <- ZIO.fail(RideError.DriverNotFound(driverId)).when(!ride.canBeStarted).unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      _         <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.InProgress)
                      .focus(_.driverId)
                      .replace(Some(driverId))
                      .focus(_.startTime)
                      .replace(Some(Instant.now()))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def completeRide(rideId: RideId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed))
          .when(!ride.canBeCompleted)
          .unit

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Completed)
                      .focus(_.endTime)
                      .replace(Some(Instant.now()))

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

    } yield persistedRide

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.status == RideStatus.Completed)
          .unit

      updatedRide = ride.focus(_.status).replace(RideStatus.Cancelled)

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

    } yield persistedRide

  def updateRideStatus(rideId: RideId, request: UpdateRideStatusRequest): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      updatedRide = ride
                      .focus(_.status)
                      .replace(request.status)
                      .focus(_.notes)
                      .replace(request.notes.orElse(ride.notes))

      persistedRide <-
        rideRepository
          .update(updatedRide)
          .mapDatabaseError

    } yield persistedRide

  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      _ <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned))
          .when(!ride.canBeAssigned)
          .unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      _ <-
        ZIO
          .fail(RideError.BusinessRuleViolation("driver_role", "Person is not a driver"))
          .when(driver.role != PersonRole.Driver)
          .unit

      _ <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Assigned)
                      .focus(_.driverId)
                      .replace(Some(driverId))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]] =
    rideRepository.findByStatus(status).mapDatabaseError

  def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]] =
    rideRepository.findByDriverId(driverId).mapDatabaseError

object RideService:

  val layer: ZLayer[RideRepository & PersonRepository, Nothing, RideService] = ZLayer.fromFunction(
    RideServiceImpl.apply
  )
