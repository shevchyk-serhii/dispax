package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.service.RideDomainService
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*

case class DriverAssignmentService(
    rideRepo: RideRepository,
    driverRepo: DriverRepository
):

  def assignDriverToRide(rideId: RideId, requesterId: PersonId): IO[RideError, AssignmentResult] =
    for
      ride <- rideRepo
                .findById(rideId)
                .mapError(ErrorMapper.fromRepositoryError)
                .someOrFail(RideError.RideNotFound(rideId))

      _ <-
        ZIO.when(ride.driverId.isDefined)(
          ZIO.fail(RideError.RideAlreadyAssigned(rideId, ride.driverId.get))
        )

      driver       <- findBestDriver(ride)
      assignedRide <- ZIO.succeed(ride.assignDriver(driver.id))

      updatedRide <- rideRepo
                       .update(assignedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(ride.id))

      _ <- driverRepo
             .updateStatus(driver.id, DriverStatus.Busy)
             .mapError(ErrorMapper.fromRepositoryError)
    yield AssignmentResult(updatedRide, driver, Distance(10.0))

  def findAvailableDrivers(location: Location, maxRadius: Distance): IO[RideError, List[Driver]] = driverRepo
    .findAvailableNear(location, maxRadius)
    .mapError(ErrorMapper.fromRepositoryError)

  private def findBestDriver(ride: Ride): IO[RideError, Driver] =
    for
      drivers <- driverRepo
                   .findAvailableNear(ride.from, Distance(20.0))
                   .mapError(ErrorMapper.fromRepositoryError)

      driver <- ZIO
                  .fromOption(drivers.headOption)
                  .orElseFail(RideError.NoDriversAvailable(ride.from.address))
    yield driver

case class AssignmentResult(ride: Ride, assignedDriver: Driver, searchRadius: Distance)

object DriverAssignmentService:

  val layer: ZLayer[RideRepository & DriverRepository, Nothing, DriverAssignmentService] = ZLayer.fromFunction(
    DriverAssignmentService.apply
  )
